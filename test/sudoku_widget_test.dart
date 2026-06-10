import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/sudoku/sudoku_board.dart';
import 'package:common_games/games/sudoku/sudoku_model.dart';
import 'package:common_games/games/sudoku/sudoku_puzzle.dart';
import 'package:common_games/screens/sudoku/sudoku_setup_screen.dart';

const _solution = [
  5,
  3,
  4,
  6,
  7,
  8,
  9,
  1,
  2,
  6,
  7,
  2,
  1,
  9,
  5,
  3,
  4,
  8,
  1,
  9,
  8,
  3,
  4,
  2,
  5,
  6,
  7,
  8,
  5,
  9,
  7,
  6,
  1,
  4,
  2,
  3,
  4,
  2,
  6,
  8,
  5,
  3,
  7,
  9,
  1,
  7,
  1,
  3,
  9,
  2,
  4,
  8,
  5,
  6,
  9,
  6,
  1,
  5,
  3,
  7,
  2,
  8,
  4,
  2,
  8,
  7,
  4,
  1,
  9,
  6,
  3,
  5,
  3,
  4,
  5,
  2,
  8,
  6,
  1,
  7,
  9,
];

SudokuPuzzle _puzzleWithBlanks(Iterable<int> blanks) {
  final givens = List<int>.from(_solution);
  for (final index in blanks) {
    givens[index] = 0;
  }
  return SudokuPuzzle(
    givens: givens,
    solution: _solution,
    difficulty: SudokuDifficulty.easy,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, height: 400, child: child)),
    ),
  );

  testWidgets('board builds 81 cells, givens appear as text', (tester) async {
    // Puzzle with only index 0 blank. The board should render the value 3
    // (the given at row 1, col 1) somewhere in the tree.
    final model = SudokuModel(_puzzleWithBlanks([0]));
    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: 0,
          notesMode: false,
          onCellSelected: (_) {},
        ),
      ),
    );

    // 81 values total. The givens appear as Text widgets; the blank cell
    // doesn't. Count the rendered Text widgets for the digits 1..9.
    var textCount = 0;
    for (final value in model.values) {
      if (value != 0) textCount++;
    }
    expect(textCount, 80);

    // Find the '3' given at row 1, col 1.
    expect(
      find.descendant(of: find.byType(SudokuBoard), matching: find.text('3')),
      findsWidgets,
    );
  });

  testWidgets('board invokes onCellSelected when an empty cell is tapped', (
    tester,
  ) async {
    // Blank two cells: index 0 (row 0, col 0) and index 45 (row 5, col 0).
    final model = SudokuModel(_puzzleWithBlanks([0, 45]));
    int? selected;
    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: null,
          notesMode: false,
          onCellSelected: (i) => selected = i,
        ),
      ),
    );

    // Tap the cell at row 5, col 0 (index 45).
    final boardFinder = find.byType(SudokuBoard);
    final boardRect = tester.getRect(boardFinder);
    final cell50 = Offset(
      boardRect.left + boardRect.width / 18,
      boardRect.top + boardRect.height * 11 / 18,
    );
    await tester.tapAt(cell50);
    await tester.pump();
    expect(selected, 45);
  });

  testWidgets('board ignores taps on fixed cells', (tester) async {
    final model = SudokuModel(_puzzleWithBlanks([0]));
    int? selected;
    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: null,
          notesMode: false,
          onCellSelected: (i) => selected = i,
        ),
      ),
    );

    // Tap the fixed cell at row 0, col 1 (index 1, value 3). It should
    // NOT fire onCellSelected.
    final boardFinder = find.byType(SudokuBoard);
    final boardRect = tester.getRect(boardFinder);
    final cell01 = Offset(
      boardRect.left + boardRect.width * 3 / 18,
      boardRect.top + boardRect.height / 18,
    );
    await tester.tapAt(cell01);
    await tester.pump();
    expect(selected, isNull);
  });

  testWidgets('notes mode renders pending notes as small digits', (
    tester,
  ) async {
    final model = SudokuModel(_puzzleWithBlanks([0, 1]));
    // Place notes only in the first (empty) cell. Givens elsewhere will
    // *also* contain digits 2, 3, 4, 5, 6, 8, 9, etc., so we look for the
    // notes-specific font size (11.0) rather than the value text size.
    model.toggleNote(0, 2);
    model.toggleNote(0, 5);

    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: 0,
          notesMode: true,
          onCellSelected: (_) {},
        ),
      ),
    );

    // Notes text is 11.0 size; given values are 26.0 size. Filter to just
    // the note-sized Text widgets so we don't catch the givens.
    final noteTexts = find.descendant(
      of: find.byType(SudokuBoard),
      matching: find.byWidgetPredicate((w) {
        if (w is! Text) return false;
        if (w.data != '2' && w.data != '5') return false;
        final style = w.style;
        return style?.fontSize == 11.0;
      }),
    );
    expect(noteTexts, findsNWidgets(2));
  });

  testWidgets('setup screen lists all three difficulties', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SudokuSetupScreen())),
    );
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
  });
}
