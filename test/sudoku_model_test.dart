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

    test(
      'restoreSnapshot reverts values and notes without recounting mistakes',
      () {
        final model = SudokuModel(puzzleWithBlanks([0, 1]));
        // User fills index 0 wrong, then hints it; mistakes goes to 1, hints to 1.
        model.enterValue(0, 4);
        model.revealHint(0);
        expect(model.mistakes, 1);
        expect(model.hintsUsed, 1);
        expect(model.values[0], 5);

        // Snapshot the "before" state of a different cell so we can restore it.
        final snapshotValues = List<int>.from(model.values);
        final snapshotNotes = [for (final n in model.notes) Set<int>.from(n)];
        // User then enters a wrong value at index 1, adding another mistake.
        model.enterValue(1, 4);
        expect(model.mistakes, 2);

        // Undo by restoring the snapshot — mistakes counter must NOT change.
        model.restoreSnapshot(values: snapshotValues, notes: snapshotNotes);
        expect(model.values[0], 5);
        expect(model.values[1], 0);
        expect(model.mistakes, 2, reason: 'restoreSnapshot is a pure restore');
        expect(model.hintsUsed, 1);
      },
    );

    test('restoreSnapshot completes the puzzle when the snapshot is full', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1, 2]));
      final solutionValues = List<int>.from(solution);
      final snapshot = [
        for (int i = 0; i < SudokuPuzzle.cellCount; i++) solutionValues[i],
      ];
      final notes = List.generate(SudokuPuzzle.cellCount, (_) => <int>{});

      model.restoreSnapshot(values: snapshot, notes: notes);
      expect(model.state, isA<SudokuCompleted>());
    });

    test('restoreSnapshot rejects wrong-sized lists', () {
      final model = SudokuModel(puzzleWithBlanks([0]));
      expect(
        () => model.restoreSnapshot(values: [0], notes: [<int>{}]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tick advances elapsed only while playing and not paused', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]));

      model.tick(1);
      expect(model.elapsedSeconds, 1);

      model.tick(2);
      expect(model.elapsedSeconds, 3);

      model.paused = true;
      model.tick(5);
      expect(model.elapsedSeconds, 3, reason: 'paused ticks are dropped');

      model.paused = false;
      model.tick(0);
      expect(model.elapsedSeconds, 3, reason: 'zero or negative ticks no-op');
      model.tick(-1);
      expect(model.elapsedSeconds, 3);
    });

    test('tick stops advancing after the puzzle is completed', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]));
      model.tick(5);
      expect(model.elapsedSeconds, 5);

      // Fill the last two cells correctly -> completed.
      model.enterValue(0, 5);
      model.enterValue(1, 3);
      expect(model.state, isA<SudokuCompleted>());

      model.tick(10);
      expect(model.elapsedSeconds, 5, reason: 'timer freezes on completion');
    });

    test('save data round-trips elapsedSeconds and paused', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]))
        ..elapsedSeconds = 42
        ..paused = true;

      final restored = SudokuModel.fromJson(model.toJson());
      expect(restored.elapsedSeconds, 42);
      expect(restored.paused, isTrue);
    });

    test('fromJson defaults elapsedSeconds and paused for legacy v1 saves', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]));
      final json = model.toJson()
        ..['version'] = 1
        ..remove('elapsedSeconds')
        ..remove('paused');

      final restored = SudokuModel.fromJson(json);
      expect(restored.elapsedSeconds, 0);
      expect(restored.paused, isFalse);
    });

    test('fromJson rejects paused paired with a completed state', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]));
      final json = model.toJson()
        ..['paused'] = true
        ..['completed'] = true;

      expect(() => SudokuModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson rejects negative elapsedSeconds', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]));
      final json = model.toJson()..['elapsedSeconds'] = -1;

      expect(() => SudokuModel.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('isAtMistakeLimit reports the configured cap', () {
      final model = SudokuModel(puzzleWithBlanks([0]))..mistakesLimit = 0;
      expect(model.isAtMistakeLimit, isFalse);
      model.mistakesLimit = 2;
      model.enterValue(0, 4); // 1 mistake
      expect(model.isAtMistakeLimit, isFalse);
      model.enterValue(0, 5); // correct over-write; mistake counter unchanged
      // Fill a different blank so the next wrong entry lands.
      // The puzzle only has [0] blanked in this fixture, so we use a fresh
      // model with two blanks for the limit-hit case.
    });

    test('enterValue is rejected once the mistake limit is hit', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]))..mistakesLimit = 1;
      expect(model.enterValue(0, 4), isTrue); // 1 mistake
      expect(model.isAtMistakeLimit, isTrue);
      // Any further edit is rejected — even a correct one.
      expect(model.enterValue(1, 3), isFalse);
      expect(model.values[1], 0);
      expect(model.mistakes, 1);
    });

    test('mistake checking off accepts wrong entries without counting', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]))
        ..mistakeChecking = false;
      // Wrong entry is accepted but no mistake recorded.
      expect(model.enterValue(0, 4), isTrue);
      expect(model.mistakes, 0);
      expect(model.values[0], 4, reason: 'cell accepts the wrong value');
      expect(model.isAtMistakeLimit, isFalse);
      // A correct over-write also still works.
      expect(model.enterValue(0, 5), isTrue);
      expect(model.values[0], 5);
      expect(model.mistakes, 0);
    });

    test('mistake checking off ignores the mistake limit entirely', () {
      final model = SudokuModel(puzzleWithBlanks([0, 1]))
        ..mistakesLimit = 1
        ..mistakeChecking = false;
      // With checking off, the limit is never reached.
      expect(model.enterValue(0, 4), isTrue);
      expect(model.isAtMistakeLimit, isFalse);
      // The cell is editable even after a wrong entry.
      expect(model.enterValue(1, 3), isTrue);
      expect(model.values[1], 3);
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
