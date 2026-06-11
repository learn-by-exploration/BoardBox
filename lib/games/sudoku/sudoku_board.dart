import 'package:flutter/material.dart';

import 'package:common_games/games/sudoku/sudoku_model.dart';

/// Pure presentation: renders a 9×9 Sudoku grid given the current
/// [SudokuModel] state. The widget does not own the model — callers pass
/// one in, and mutations flow back via the callback parameters.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    super.key,
    required this.model,
    required this.selectedIndex,
    required this.notesMode,
    required this.onCellSelected,
    this.invalidIndexes = const <int>{},
    this.highlightedIndexes = const <int>{},
  });

  final SudokuModel model;
  final int? selectedIndex;
  final bool notesMode;
  final ValueChanged<int> onCellSelected;
  final Set<int> invalidIndexes;
  final Set<int> highlightedIndexes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              child: _buildGrid(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    return Column(
      children: List.generate(9, (row) {
        return Expanded(
          child: Row(
            children: List.generate(9, (col) {
              final index = row * 9 + col;
              return Expanded(
                child: _SudokuCell(
                  index: index,
                  value: model.values[index],
                  notes: model.notes[index],
                  isFixed: model.puzzle.isGiven(index),
                  isSelected: index == selectedIndex,
                  isInvalid: invalidIndexes.contains(index),
                  isHighlighted: highlightedIndexes.contains(index),
                  isComplete: model.state is SudokuCompleted,
                  notesMode: notesMode,
                  boxBorderRight: col == 2 || col == 5,
                  boxBorderBottom: row == 2 || row == 5,
                  onTap: () => onCellSelected(index),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _SudokuCell extends StatelessWidget {
  const _SudokuCell({
    required this.index,
    required this.value,
    required this.notes,
    required this.isFixed,
    required this.isSelected,
    required this.isInvalid,
    required this.isHighlighted,
    required this.isComplete,
    required this.notesMode,
    required this.boxBorderRight,
    required this.boxBorderBottom,
    required this.onTap,
  });

  final int index;
  final int value;
  final Set<int> notes;
  final bool isFixed;
  final bool isSelected;
  final bool isInvalid;
  final bool isHighlighted;
  final bool isComplete;
  final bool notesMode;
  final bool boxBorderRight;
  final bool boxBorderBottom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final row = index ~/ 9;
    final col = index % 9;
    final cellLabel = isFixed
        ? 'Row ${row + 1} column ${col + 1}, fixed $value'
        : value != 0
        ? 'Row ${row + 1} column ${col + 1}, $value'
        : 'Row ${row + 1} column ${col + 1}, empty';

    // Backgrounds: invalid > selected > fixed > highlighted > default
    Color background;
    if (isInvalid) {
      background = colorScheme.errorContainer;
    } else if (isSelected) {
      background = colorScheme.primaryContainer;
    } else if (isFixed) {
      background = colorScheme.surfaceContainerHighest;
    } else if (isHighlighted) {
      background = colorScheme.surfaceContainerLow;
    } else {
      background = colorScheme.surface;
    }

    return Semantics(
      label: cellLabel,
      button: !isFixed && !isComplete,
      onTap: isFixed || isComplete ? null : onTap,
      child: GestureDetector(
        onTap: isFixed || isComplete ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: Border(
              right: BorderSide(
                color: boxBorderRight
                    ? colorScheme.outline
                    : colorScheme.outlineVariant,
                width: boxBorderRight ? 2 : 0.5,
              ),
              bottom: BorderSide(
                color: boxBorderBottom
                    ? colorScheme.outline
                    : colorScheme.outlineVariant,
                width: boxBorderBottom ? 2 : 0.5,
              ),
            ),
          ),
          child: value != 0
              ? _ValueText(value: value, isFixed: isFixed)
              : notes.isNotEmpty
              ? _NotesGrid(notes: notes)
              : null,
        ),
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText({required this.value, required this.isFixed});

  final int value;
  final bool isFixed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isFixed ? colorScheme.onSurface : colorScheme.primary;
    return Center(
      child: Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 26,
          fontWeight: isFixed ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({required this.notes});

  final Set<int> notes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: List.generate(3, (row) {
          return Expanded(
            child: Row(
              children: List.generate(3, (col) {
                final digit = row * 3 + col + 1;
                final present = notes.contains(digit);
                return Expanded(
                  child: Center(
                    child: Text(
                      present ? '$digit' : '',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
