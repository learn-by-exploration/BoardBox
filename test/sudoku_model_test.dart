import 'package:flutter_test/flutter_test.dart';

import 'package:common_games/games/sudoku/sudoku_model.dart';
import 'package:common_games/games/sudoku/sudoku_puzzle.dart';

void main() {
  const solution = [
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

  SudokuPuzzle puzzleWithBlanks(Iterable<int> blanks) {
    final givens = List<int>.from(solution);
    for (final index in blanks) {
      givens[index] = 0;
    }
    return SudokuPuzzle(
      givens: givens,
      solution: solution,
      difficulty: SudokuDifficulty.easy,
    );
  }

  group('SudokuModel', () {
    test('rejects edits to fixed cells', () {
      final model = SudokuModel(puzzleWithBlanks([0]));

      expect(model.enterValue(1, 3), isFalse);
      expect(model.values[1], 3);
    });

    test('tracks incorrect entries and accepts corrections', () {
      final model = SudokuModel(puzzleWithBlanks([0]));

      expect(model.enterValue(0, 4), isTrue);
      expect(model.mistakes, 1);
      expect(model.state, isA<SudokuPlaying>());

      expect(model.enterValue(0, 5), isTrue);
      expect(model.mistakes, 1);
      expect(model.state, isA<SudokuCompleted>());
    });

    test('toggles notes only in empty editable cells', () {
      final model = SudokuModel(puzzleWithBlanks([0]));

      expect(model.toggleNote(0, 2), isTrue);
      expect(model.notes[0], contains(2));
      expect(model.toggleNote(0, 2), isTrue);
      expect(model.notes[0], isNot(contains(2)));
      expect(model.toggleNote(1, 2), isFalse);

      model.enterValue(0, 5);
      expect(model.toggleNote(0, 2), isFalse);
    });

    test('hint reveals a cell and records its use', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]));

      expect(model.revealHint(0), isTrue);
      expect(model.values[0], 5);
      expect(model.hintsUsed, 1);
      expect(model.revealHint(0), isFalse);
      expect(model.hintsUsed, 1);
    });

    test('save data round-trips values, notes, and counters', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]));
      model.enterValue(0, 4);
      model.toggleNote(1, 7);
      model.revealHint(0);

      final restored = SudokuModel.fromJson(model.toJson());

      expect(restored.values, model.values);
      expect(restored.notes[1], contains(7));
      expect(restored.mistakes, 1);
      expect(restored.hintsUsed, 1);
      expect(restored.state, isA<SudokuPlaying>());
    });

    test('rejects inconsistent completion data', () {
      final model = SudokuModel(puzzleWithBlanks([0]));
      final json = model.toJson()..['completed'] = true;

      expect(() => SudokuModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('puzzle defensively copies its grids', () {
      final givens = List<int>.from(solution)..[0] = 0;
      final puzzle = SudokuPuzzle(
        givens: givens,
        solution: solution,
        difficulty: SudokuDifficulty.easy,
      );

      givens[1] = 0;

      expect(puzzle.givens[1], 3);
    });
  });

  test('factory generates a valid puzzle with one solution', () {
    final puzzle = const SudokuPuzzleFactory().generate(SudokuDifficulty.easy);

    expect(puzzle.givens, hasLength(81));
    expect(puzzle.solution, hasLength(81));
    expect(puzzle.givens, contains(0));
    for (int index = 0; index < 81; index++) {
      if (puzzle.givens[index] != 0) {
        expect(puzzle.givens[index], puzzle.solution[index]);
      }
    }
  });
}
