import 'package:flutter/material.dart';

import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/services/haptic_service.dart';

/// Renders a Minesweeper play area. Pure presentation: it owns the
/// [MinesweeperModel] and calls `reveal` / `toggleFlag` on user
/// gestures. The screen wires the AppBar + status bar + dialogs.
///
/// Gesture model: **tap to reveal** (calls `model.reveal(r, c)`),
/// **long-press to flag** (calls `model.toggleFlag(r, c)`). Tap on an
/// already-revealed or flagged cell is a no-op. Long-press on a
/// revealed cell is a no-op.
///
/// State-driven rendering: when the model flips to [MinesweeperLost],
/// every mine is shown (the triggered mine in red, the others in
/// muted gray) and gestures are disabled. When the model flips to
/// [MinesweeperWon], every cell is revealed; correct flags are tinted
/// green and incorrect flags are tinted red. This is a pure function
/// of `model.state` — no animation, no extra state.
class MinesweeperBoard extends StatefulWidget {
  const MinesweeperBoard({super.key, required this.model, this.onModelChanged});

  /// The model to render. The board mutates it on tap.
  final MinesweeperModel model;

  /// Called after any user-driven mutation (reveal, flag). Useful
  /// for the screen to know when to save or update status bar state.
  final ValueChanged<MinesweeperModel>? onModelChanged;

  @override
  State<MinesweeperBoard> createState() => _MinesweeperBoardState();
}

class _MinesweeperBoardState extends State<MinesweeperBoard> {
  void _mutate(void Function() fn) {
    setState(fn);
    widget.onModelChanged?.call(widget.model);
  }

  void _onTapCell(int row, int col) {
    if (widget.model.state is! MinesweeperPlaying) return;
    final cell = widget.model.cellAt(row, col);
    if (cell.flagged || cell.revealed) return;
    final stateBefore = widget.model.state;
    _mutate(() => widget.model.reveal(row, col));
    if (widget.model.state != stateBefore) {
      HapticService.onGameOver();
    } else {
      HapticService.onMove();
    }
  }

  void _onLongPressCell(int row, int col) {
    if (widget.model.state is! MinesweeperPlaying) return;
    final cell = widget.model.cellAt(row, col);
    if (cell.revealed) {
      // Long-pressing a revealed cell is a no-op, but the user gets a
      // buzz so they know the gesture was recognized.
      HapticService.onError();
      return;
    }
    _mutate(() => widget.model.toggleFlag(row, col));
    HapticService.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.model.cols / widget.model.rows,
              child: _MinesweeperGrid(
                model: widget.model,
                onTapCell: _onTapCell,
                onLongPressCell: _onLongPressCell,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The 2D grid of cells. Renders a `GridView` of square cells sized
/// from the available width. Each cell is a [_Cell] that owns its
/// own gesture detector and color logic.
class _MinesweeperGrid extends StatelessWidget {
  const _MinesweeperGrid({
    required this.model,
    required this.onTapCell,
    required this.onLongPressCell,
  });

  final MinesweeperModel model;
  final void Function(int row, int col) onTapCell;
  final void Function(int row, int col) onLongPressCell;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: model.rows * model.cols,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: model.cols,
      ),
      itemBuilder: (context, index) {
        final r = index ~/ model.cols;
        final c = index % model.cols;
        return _Cell(
          model: model,
          row: r,
          col: c,
          onTap: () => onTapCell(r, c),
          onLongPress: () => onLongPressCell(r, c),
        );
      },
    );
  }
}

/// A single cell. Visual state is derived from the model:
/// - hidden + unflagged → surfaceContainerHighest
/// - hidden + flagged → primaryContainer (with flag icon)
/// - revealed + safe (count == 0) → surface (blank)
/// - revealed + safe (count > 0) → surface with the count
/// - revealed + mine (lost state) → errorContainer / surfaceVariant
class _Cell extends StatelessWidget {
  const _Cell({
    required this.model,
    required this.row,
    required this.col,
    required this.onTap,
    required this.onLongPress,
  });

  final MinesweeperModel model;
  final int row;
  final int col;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cell = model.cellAt(row, col);
    final colorScheme = Theme.of(context).colorScheme;

    final isLost = model.state is MinesweeperLost;
    final isWon = model.state is MinesweeperWon;

    Color background;
    Widget? child;
    BoxBorder? border;

    if (cell.revealed) {
      if (cell.isMine) {
        final lost = model.state as MinesweeperLost;
        final triggered = lost.triggeredAt;
        final isTriggered =
            triggered != null && triggered.$1 == row && triggered.$2 == col;
        background = isTriggered
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHigh;
        child = Text(
          '*',
          style: TextStyle(
            color: isTriggered
                ? colorScheme.onErrorContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            height: 1,
          ),
        );
      } else {
        background = colorScheme.surface;
        final n = model.adjacentMinesAt(row, col);
        if (n > 0) {
          child = Text(
            '$n',
            style: TextStyle(
              color: _countColor(n, colorScheme),
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1,
            ),
          );
        }
      }
    } else {
      background = colorScheme.surfaceContainerHighest;
      if (cell.flagged) {
        if (isWon) {
          // Win reveal: green for correct flags, red for wrong.
          background = cell.isMine
              ? Colors.green.withValues(alpha: 0.3)
              : colorScheme.errorContainer;
          child = Icon(
            Icons.flag_rounded,
            color: cell.isMine ? Colors.green.shade900 : colorScheme.error,
            size: 18,
          );
        } else {
          background = colorScheme.primaryContainer;
          child = Icon(
            Icons.flag_rounded,
            color: colorScheme.onPrimaryContainer,
            size: 18,
          );
        }
      } else if (isLost) {
        // Loss reveal: show the mines that weren't flagged.
        if (cell.isMine) {
          background = colorScheme.surfaceContainerHigh;
          child = Text(
            '*',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1,
            ),
          );
        }
      }
    }

    border = Border.all(
      color: revealed(cell, model)
          ? colorScheme.outlineVariant
          : colorScheme.outline,
      width: revealed(cell, model) ? 0.5 : 1,
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(color: background, border: border),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

bool revealed(MinesweeperCell cell, MinesweeperModel model) {
  if (cell.revealed) return true;
  if (model.state is MinesweeperLost && cell.isMine) return true;
  if (model.state is MinesweeperWon) return true;
  return false;
}

/// Standard Minesweeper number colors. 1=blue, 2=green, 3=red, 4=purple,
/// 5=maroon, 6=turquoise, 7=black, 8=gray. Mirrors the look every player
/// recognizes from the desktop game.
Color _countColor(int n, ColorScheme scheme) {
  return switch (n) {
    1 => Colors.blue.shade700,
    2 => Colors.green.shade800,
    3 => Colors.red.shade700,
    4 => Colors.purple.shade700,
    5 => Colors.brown.shade700,
    6 => Colors.teal.shade700,
    7 => Colors.black87,
    _ => Colors.blueGrey.shade700,
  };
}
