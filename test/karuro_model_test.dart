import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/karuro/karuro_model.dart';
import 'package:common_games/games/karuro/karuro_puzzle.dart';

/// A minimal two-entry, two-cell Karuro puzzle for tests.
///
/// 3x3 grid, outer border all blocks, only (1,1) and (1,2) are entry cells.
/// Entry 1A: across length 2, sum 3 (digits 1+2). Solution: 1, 2.
const _puzzleRaw = '''
{
  "id": "model-test-001",
  "title": "Two Cells",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 2,
    "maxWordRunLength": 0,
    "crossingsPerCell": 1,
    "extremeSumShare": 1
  },
  "grid": { "rows": 3, "cols": 3 },
  "cells": [
    ["#", "#", "#"],
    ["#", " ", " "],
    ["#", "#", "#"]
  ],
  "entries": [
    {
      "id": "1A",
      "number": 1,
      "direction": "across",
      "start": { "row": 1, "col": 1 },
      "length": 2,
      "kind": "number",
      "sum": 3
    }
  ],
  "solution": { "1,1": "1", "1,2": "2" }
}
''';

KaruroPuzzle _puzzle() =>
    KaruroPuzzle.fromJson(json.decode(_puzzleRaw) as Map<String, dynamic>);

void main() {
  group('KaruroModel', () {
    late KaruroPuzzle puzzle;
    late KaruroModel model;

    setUp(() {
      puzzle = _puzzle();
      model = KaruroModel(puzzle);
    });

    test('starts with all cells empty and state Playing', () {
      expect(model.values, hasLength(puzzle.rows * puzzle.cols));
      for (final v in model.values) {
        expect(v, isNull);
      }
      expect(model.state, isA<KaruroPlaying>());
      expect(model.isWon, isFalse);
      expect(model.canUndo, isFalse);
    });

    test('enterValue writes a value and tracks undo', () {
      expect(model.enterValue(1, 1, '1'), isTrue);
      expect(model.valueAt(1, 1), '1');
      expect(model.canUndo, isTrue);
    });

    test('enterValue normalizes letter case to upper', () {
      model.enterValue(1, 1, 'a');
      expect(model.valueAt(1, 1), 'A');
    });

    test('enterValue returns false when the value matches existing', () {
      model.enterValue(1, 1, '1');
      expect(model.enterValue(1, 1, '1'), isFalse);
    });

    test('enterValue rejects non-entry cells', () {
      expect(() => model.enterValue(0, 0, '1'), throwsA(isA<ArgumentError>()));
    });

    test('enterValue rejects out-of-bounds cells', () {
      expect(() => model.enterValue(-1, 0, '1'), throwsA(isA<ArgumentError>()));
    });

    test('erase clears a filled cell', () {
      model.enterValue(1, 1, '1');
      expect(model.erase(1, 1), isTrue);
      expect(model.valueAt(1, 1), isNull);
    });

    test('erase returns false on an empty cell', () {
      expect(model.erase(1, 1), isFalse);
    });

    test('undo reverts the last mutation', () {
      model.enterValue(1, 1, '1');
      model.erase(1, 1);
      expect(model.valueAt(1, 1), isNull);
      expect(model.canUndo, isTrue);
      // undo pops the erase, restoring the '1'.
      model.undo();
      expect(model.valueAt(1, 1), '1');
      // undo pops the enter, restoring null.
      model.undo();
      expect(model.valueAt(1, 1), isNull);
    });

    test('undo returns false when history is empty', () {
      expect(model.undo(), isFalse);
    });

    test('wrongCells returns cells that do not match the solution', () {
      model.enterValue(1, 1, '9'); // wrong
      model.enterValue(1, 2, '2'); // right
      final wrong = model.wrongCells();
      // Flat index for (1, 1) is 1*3 + 1 = 4.
      expect(wrong, contains(4));
      // (1, 2) is index 5 and matches the solution, so it is not wrong.
      expect(wrong, isNot(contains(5)));
    });

    test('isWon flips only when every solution cell matches', () {
      expect(model.isWon, isFalse);
      model.enterValue(1, 1, '1');
      expect(model.isWon, isFalse);
      model.enterValue(1, 2, '2');
      expect(model.isWon, isTrue);
      expect(model.state, isA<KaruroWon>());
    });

    test('enterValue after winning is a no-op', () {
      model.enterValue(1, 1, '1');
      model.enterValue(1, 2, '2');
      expect(model.state, isA<KaruroWon>());
      expect(model.enterValue(1, 1, '5'), isFalse);
      expect(model.valueAt(1, 1), '1');
    });

    test('undo restores Playing after a winning move is undone', () {
      model.enterValue(1, 1, '1');
      model.enterValue(1, 2, '2');
      expect(model.state, isA<KaruroWon>());
      model.undo();
      expect(model.state, isA<KaruroPlaying>());
    });

    test('runRuleErrorCells flags duplicate digits in a run', () {
      // Use a puzzle with a run long enough to allow duplicates.
      final dupPuzzle = KaruroPuzzle.fromJson({
        'id': 'dup-test',
        'title': 'Dup',
        'difficulty': 'easy',
        'metrics': const {
          'maxNumericRunLength': 3,
          'maxWordRunLength': 0,
          'crossingsPerCell': 1,
          'extremeSumShare': 0,
        },
        'grid': const {'rows': 3, 'cols': 4},
        'cells': const [
          ['#', '#', '#', '#'],
          ['#', ' ', ' ', ' '],
          ['#', '#', '#', '#'],
        ],
        'entries': const [
          {
            'id': '1A',
            'number': 1,
            'direction': 'across',
            'start': {'row': 1, 'col': 1},
            'length': 3,
            'kind': 'number',
            'sum': 9,
          },
        ],
        'solution': const {'1,1': '1', '1,2': '2', '1,3': '3'},
      });
      final dupModel = KaruroModel(dupPuzzle);
      dupModel.enterValue(1, 1, '1');
      dupModel.enterValue(1, 2, '1'); // duplicate
      dupModel.enterValue(1, 3, '3');
      final errors = dupModel.runRuleErrorCells();
      // Flat indices for row 1, cols 1-3 in a 4-wide grid: 5, 6, 7.
      expect(errors, contains(5));
      expect(errors, contains(6));
    });

    test('toJson then fromJson round-trips the model', () {
      model.enterValue(1, 1, '1');
      model.enterValue(1, 2, '9'); // wrong on purpose
      final json = model.toJson();
      final restored = KaruroModel.fromJson(
        json,
        (id) => id == puzzle.id ? puzzle : null,
      );
      expect(restored, isNotNull);
      expect(restored.valueAt(1, 1), '1');
      expect(restored.valueAt(1, 2), '9');
      expect(restored.canUndo, isTrue);
    });

    test('fromJson throws on unknown puzzle id', () {
      final json = model.toJson();
      expect(
        () => KaruroModel.fromJson(json, (_) => null),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws on version mismatch', () {
      final json = model.toJson()..['version'] = 999;
      expect(
        () => KaruroModel.fromJson(json, (_) => puzzle),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
