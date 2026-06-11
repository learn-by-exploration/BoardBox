import 'package:flutter/material.dart';

import 'package:common_games/games/karuro/karuro_model.dart';
import 'package:common_games/games/karuro/karuro_puzzle.dart';

/// Pure presentation: renders a Karuro grid given the current
/// [KaruroModel] state. The widget does not own the model — callers pass
/// one in, and mutations flow back via the callback parameters.
///
/// Cell layout follows the classic Kakuro split for clue cells: a diagonal
/// line carries the "down" clue (above the line) and the "across" clue
/// (below). Numeric clues render the `sum`; word clues render a short
/// text label. Fillable cells display the current character.
class KaruroBoard extends StatelessWidget {
  const KaruroBoard({
    super.key,
    required this.model,
    required this.selectedIndex,
    required this.onCellSelected,
    this.invalidIndexes = const <int>{},
    this.onLongPressCell,
  });

  final KaruroModel model;
  final int? selectedIndex;
  final ValueChanged<int> onCellSelected;
  final Set<int> invalidIndexes;

  /// Invoked on a long-press of a fillable cell. Use this to surface the
  /// input palette.
  final ValueChanged<int>? onLongPressCell;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final puzzle = model.puzzle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline, width: 2),
              ),
              padding: const EdgeInsets.all(2),
              child: Column(
                children: List.generate(puzzle.rows, (row) {
                  return Expanded(
                    child: Row(
                      children: List.generate(puzzle.cols, (col) {
                        final cell = puzzle.cells[row][col];
                        final index = row * puzzle.cols + col;
                        if (cell is KaruroBlockCell) {
                          return Expanded(
                            child: _BlockCell(
                              row: row,
                              col: col,
                              puzzle: puzzle,
                            ),
                          );
                        }
                        return Expanded(
                          child: _EntryCell(
                            row: row,
                            col: col,
                            index: index,
                            value: model.valueAt(row, col),
                            isSelected: index == selectedIndex,
                            isInvalid: invalidIndexes.contains(index),
                            isComplete: model.state is KaruroWon,
                            onTap: () => onCellSelected(index),
                            onLongPress: onLongPressCell == null
                                ? null
                                : () => onLongPressCell!(index),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A block cell. Carries up to two clue annotations (one down, one
/// across) at its top-left and bottom-right corners. The diagonal split
/// is a visual cue from classic Kakuro.
class _BlockCell extends StatelessWidget {
  const _BlockCell({
    required this.row,
    required this.col,
    required this.puzzle,
  });

  final int row;
  final int col;
  final KaruroPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Find any entry whose start cell is exactly this block. The block
    // may carry a "down" clue (entry that starts at (row, col) and
    // extends down) and/or a "right" clue (entry that extends right).
    KaruroEntry? downEntry;
    KaruroEntry? rightEntry;
    for (final e in puzzle.entries) {
      if (e.startRow == row && e.startCol == col) {
        if (e.direction == KaruroDirection.down) {
          downEntry = e;
        } else {
          rightEntry = e;
        }
      }
    }

    final semantic = _clueSemanticsLabel(downEntry, rightEntry);

    return Semantics(
      container: true,
      label: semantic,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        ),
        child: Stack(
          children: [
            if (downEntry != null) _ClueBadge(entry: downEntry, axis: 'down'),
            if (rightEntry != null)
              _ClueBadge(entry: rightEntry, axis: 'across'),
          ],
        ),
      ),
    );
  }

  /// Build a screen-reader description for the block cell, e.g.
  /// "Clue 8, across, three cells" or
  /// "Word clue: Feline pet, four cells".
  String _clueSemanticsLabel(KaruroEntry? down, KaruroEntry? right) {
    final parts = <String>[];
    for (final entry in [down, right]) {
      if (entry == null) continue;
      final axis = entry.direction == KaruroDirection.across
          ? 'across'
          : 'down';
      final kind = switch (entry) {
        KaruroNumberEntry(:final sum) => 'Clue $sum',
        KaruroWordEntry(:final clue) => 'Word clue: $clue',
      };
      final cells = entry.length;
      parts.add('$kind, $axis, $cells cells');
    }
    if (parts.isEmpty) {
      return 'Block cell at row ${row + 1}, column ${col + 1}';
    }
    return parts.join('; ');
  }
}

/// Tiny corner badge that displays a clue's "label" (sum for numeric
/// entries, the clue text for word entries).
class _ClueBadge extends StatelessWidget {
  const _ClueBadge({required this.entry, required this.axis});

  final KaruroEntry entry;
  final String axis;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = switch (entry) {
      KaruroNumberEntry(:final sum) => '$sum',
      KaruroWordEntry(:final clue) => clue,
    };
    final alignment = axis == 'down'
        ? Alignment.topLeft
        : Alignment.bottomRight;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Text(
          text,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: axis == 'down' ? TextAlign.left : TextAlign.right,
        ),
      ),
    );
  }
}

/// A fillable entry cell. Shows the current value (or empty), the entry
/// number at the top-left (when the cell is the start of a run), and
/// state-driven background colors.
class _EntryCell extends StatelessWidget {
  const _EntryCell({
    required this.row,
    required this.col,
    required this.index,
    required this.value,
    required this.isSelected,
    required this.isInvalid,
    required this.isComplete,
    required this.onTap,
    required this.onLongPress,
  });

  final int row;
  final int col;
  final int index;
  final String? value;
  final bool isSelected;
  final bool isInvalid;
  final bool isComplete;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // The cell is a clue if it is the start cell of any run.
    String? clueNumber;
    String? clueText;
    for (final e in modelFor(context).puzzle.entries) {
      if (e.startRow == row && e.startCol == col) {
        clueNumber = e.number.toString();
        if (e is KaruroWordEntry) {
          clueText = e.clue;
        }
      }
    }

    Color background;
    if (isInvalid) {
      background = colorScheme.errorContainer;
    } else if (isSelected) {
      background = colorScheme.primaryContainer;
    } else if (value != null) {
      background = colorScheme.surfaceContainerHigh;
    } else {
      background = colorScheme.surface;
    }

    return Semantics(
      container: true,
      label: _semanticsLabel(clueNumber: clueNumber),
      button: true,
      enabled: !isComplete,
      onTap: isComplete ? null : onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: isComplete ? null : onTap,
        onLongPress: isComplete ? null : onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
          ),
          child: Stack(
            children: [
              if (clueNumber != null)
                Positioned(
                  top: 1,
                  left: 2,
                  child: Text(
                    clueNumber,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
              if (clueText != null)
                Positioned(
                  bottom: 1,
                  right: 2,
                  child: Text(
                    clueText,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 7,
                      fontStyle: FontStyle.italic,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Center(
                child: Text(
                  value ?? '',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a Semantics-friendly label like
  /// "Row 1 column 1, value 1, number cell, clue 1".
  String _semanticsLabel({String? clueNumber}) {
    final parts = <String>['Row ${row + 1} column ${col + 1}'];
    if (value != null) {
      parts.add('value $value');
    } else {
      parts.add('empty');
    }
    if (clueNumber != null) {
      parts.add('clue $clueNumber');
    }
    return parts.join(', ');
  }

  /// Walk up the widget tree to find the enclosing [KaruroBoard]. We
  /// can't grab the model via a constructor parameter because the
  /// per-cell sub-widgets are private to this file; the [BuildContext]
  /// ancestor lookup is the standard Flutter pattern for this case.
  KaruroModel modelFor(BuildContext context) {
    final board = context.findAncestorWidgetOfExactType<KaruroBoard>();
    if (board == null) {
      throw StateError('_EntryCell must be a descendant of KaruroBoard');
    }
    return board.model;
  }
}
