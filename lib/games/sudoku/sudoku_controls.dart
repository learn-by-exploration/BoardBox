import 'package:flutter/material.dart';

import 'package:common_games/services/haptic_service.dart';
import 'package:common_games/services/settings_service.dart';

/// A 1–9 number pad with erase, notes toggle, and undo. The board screen
/// wires these to model mutations.
class SudokuControls extends StatelessWidget {
  const SudokuControls({
    super.key,
    required this.canEdit,
    required this.notesMode,
    required this.canUndo,
    required this.onNumber,
    required this.onErase,
    required this.onToggleNotes,
    required this.onUndo,
  });

  final bool canEdit;
  final bool notesMode;
  final bool canUndo;
  final ValueChanged<int> onNumber;
  final VoidCallback onErase;
  final VoidCallback onToggleNotes;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const spacing = 8.0;
    const cols = 5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final cellSize = ((available - spacing * (cols - 1)) / cols).clamp(
          48.0,
          72.0,
        );

        Widget number(int n) => _PadButton(
          key: ValueKey('sudoku_pad_$n'),
          semanticsLabel: 'Place $n',
          width: cellSize,
          height: cellSize,
          onPressed: canEdit ? () => _fireHaptic(() => onNumber(n)) : null,
          child: Text(
            '$n',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        );

        Widget eraseButton() => _PadButton(
          key: const ValueKey('sudoku_pad_erase'),
          semanticsLabel: 'Erase cell',
          width: cellSize,
          height: cellSize,
          onPressed: canEdit ? () => _fireHaptic(onErase) : null,
          child: Icon(
            Icons.backspace_outlined,
            color: colorScheme.onSurface,
            size: 22,
          ),
        );

        Widget undoButton() => _PadButton(
          key: const ValueKey('sudoku_pad_undo'),
          semanticsLabel: 'Undo last action',
          width: cellSize,
          height: cellSize,
          onPressed: canUndo ? () => _fireHaptic(onUndo) : null,
          child: Icon(
            Icons.undo_rounded,
            color: colorScheme.onSurface,
            size: 22,
          ),
        );

        return Column(
          children: [
            Row(
              children: [
                number(1),
                const SizedBox(width: spacing),
                number(2),
                const SizedBox(width: spacing),
                number(3),
                const SizedBox(width: spacing),
                number(4),
                const SizedBox(width: spacing),
                number(5),
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              children: [
                number(6),
                const SizedBox(width: spacing),
                number(7),
                const SizedBox(width: spacing),
                number(8),
                const SizedBox(width: spacing),
                number(9),
                const SizedBox(width: spacing),
                eraseButton(),
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    toggled: notesMode,
                    button: true,
                    enabled: canEdit,
                    label: 'Notes mode, ${notesMode ? 'on' : 'off'}',
                    onTap: canEdit
                        ? () {
                            HapticService.onMove();
                            onToggleNotes();
                          }
                        : null,
                    child: ExcludeSemantics(
                      child: OutlinedButton.icon(
                        onPressed: canEdit
                            ? () {
                                HapticService.onMove();
                                onToggleNotes();
                              }
                            : null,
                        icon: const Icon(Icons.edit_note),
                        label: Text(notesMode ? 'Notes: On' : 'Notes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: notesMode
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          side: BorderSide(
                            color: notesMode
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: spacing),
                undoButton(),
              ],
            ),
          ],
        );
      },
    );
  }

  void _fireHaptic(VoidCallback action) {
    if (SettingsService.instance.hapticsEnabled) {
      HapticService.onMove();
    }
    action();
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    required this.semanticsLabel,
    this.onPressed,
  });

  final double width;
  final double height;
  final Widget child;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
