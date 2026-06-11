import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/karuro/karuro_puzzle.dart';

Map<String, dynamic> _puzzleJson(String source) =>
    json.decode(source) as Map<String, dynamic>;

void main() {
  group('KaruroPuzzle.fromJson', () {
    test('round-trips the reference easy puzzle', () {
      const raw = '''
{
  "id": "karuro-rt-001",
  "title": "Round Trip",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 3,
    "maxWordRunLength": 3,
    "crossingsPerCell": 2,
    "extremeSumShare": 0.5
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
      final puzzle = KaruroPuzzle.fromJson(_puzzleJson(raw));
      expect(puzzle.id, 'karuro-rt-001');
      expect(puzzle.title, 'Round Trip');
      expect(puzzle.difficulty, KaruroDifficulty.easy);
      expect(puzzle.rows, 3);
      expect(puzzle.cols, 3);
      expect(puzzle.cells[0][0], isA<KaruroBlockCell>());
      expect(puzzle.cells[1][1], isA<KaruroEntryCell>());
      expect(puzzle.entries, hasLength(1));
      final entry = puzzle.entries.single as KaruroNumberEntry;
      expect(entry.sum, 3);
      expect(entry.cells, [(1, 1), (1, 2)]);
      expect(puzzle.solutionAt(1, 1), '1');
      expect(puzzle.solutionAt(1, 2), '2');
      expect(puzzle.solutionAt(0, 0), isNull);

      // toJson should preserve enough to round-trip back to an equivalent
      // puzzle.
      final reEncoded = puzzle.toJson();
      final roundTripped = KaruroPuzzle.fromJson(reEncoded);
      expect(roundTripped.id, puzzle.id);
      expect(roundTripped.entries, hasLength(1));
      expect((roundTripped.entries.single as KaruroNumberEntry).sum, 3);
      expect(roundTripped.solution, puzzle.solution);
    });

    test('exposes word entries with clue and answer', () {
      const raw = '''
{
  "id": "karuro-rt-002",
  "title": "Word Only",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 0,
    "maxWordRunLength": 3,
    "crossingsPerCell": 1,
    "extremeSumShare": 0
  },
  "grid": { "rows": 3, "cols": 4 },
  "cells": [
    ["#", "#", "#", "#"],
    ["#", " ", " ", " "],
    ["#", "#", "#", "#"]
  ],
  "entries": [
    {
      "id": "1A",
      "number": 1,
      "direction": "across",
      "start": { "row": 1, "col": 1 },
      "length": 3,
      "kind": "word",
      "clue": "Solar disk",
      "answer": "SUN"
    }
  ],
  "solution": { "1,1": "S", "1,2": "U", "1,3": "N" }
}
''';
      final puzzle = KaruroPuzzle.fromJson(_puzzleJson(raw));
      final entry = puzzle.entries.single as KaruroWordEntry;
      expect(entry.clue, 'Solar disk');
      expect(entry.answer, 'SUN');
      expect(entry.cells, [(1, 1), (1, 2), (1, 3)]);
    });

    test('rejects unknown entry kind', () {
      const raw = '''
{
  "id": "karuro-bad-001",
  "title": "Bad Kind",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 1,
    "maxWordRunLength": 0,
    "crossingsPerCell": 1,
    "extremeSumShare": 0
  },
  "grid": { "rows": 2, "cols": 2 },
  "cells": [["#", "#"], ["#", " "]],
  "entries": [
    {
      "id": "1A",
      "number": 1,
      "direction": "across",
      "start": { "row": 1, "col": 1 },
      "length": 1,
      "kind": "image"
    }
  ],
  "solution": { "1,1": "1" }
}
''';
      expect(
        () => KaruroPuzzle.fromJson(_puzzleJson(raw)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects word entry whose solution does not spell the answer', () {
      const raw = '''
{
  "id": "karuro-bad-002",
  "title": "Bad Word",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 0,
    "maxWordRunLength": 3,
    "crossingsPerCell": 1,
    "extremeSumShare": 0
  },
  "grid": { "rows": 2, "cols": 3 },
  "cells": [["#", "#", "#"], ["#", " ", " "]],
  "entries": [
    {
      "id": "1A",
      "number": 1,
      "direction": "across",
      "start": { "row": 1, "col": 1 },
      "length": 2,
      "kind": "word",
      "clue": "Solar disk",
      "answer": "SUN"
    }
  ],
  "solution": { "1,1": "M", "1,2": "O" }
}
''';
      expect(
        () => KaruroPuzzle.fromJson(_puzzleJson(raw)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects entries that run out of bounds', () {
      const raw = '''
{
  "id": "karuro-bad-003",
  "title": "Out Of Bounds",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 3,
    "maxWordRunLength": 0,
    "crossingsPerCell": 1,
    "extremeSumShare": 0
  },
  "grid": { "rows": 2, "cols": 2 },
  "cells": [["#", "#"], ["#", " "]],
  "entries": [
    {
      "id": "1A",
      "number": 1,
      "direction": "across",
      "start": { "row": 1, "col": 0 },
      "length": 2,
      "kind": "number",
      "sum": 5
    }
  ],
  "solution": { "1,0": "2", "1,1": "3" }
}
''';
      expect(
        () => KaruroPuzzle.fromJson(_puzzleJson(raw)),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'sealed class exhaustiveness — every KaruroEntry is number or word',
      () {
        const raw = '''
{
  "id": "karuro-rt-003",
  "title": "Mixed",
  "difficulty": "medium",
  "metrics": {
    "maxNumericRunLength": 2,
    "maxWordRunLength": 2,
    "crossingsPerCell": 2,
    "extremeSumShare": 0.5
  },
  "grid": { "rows": 2, "cols": 2 },
  "cells": [["#", "#"], [" ", " "]],
  "entries": [
    {
      "id": "1A",
      "number": 1,
      "direction": "across",
      "start": { "row": 1, "col": 0 },
      "length": 2,
      "kind": "number",
      "sum": 5
    },
    {
      "id": "1D",
      "number": 1,
      "direction": "down",
      "start": { "row": 1, "col": 1 },
      "length": 1,
      "kind": "word",
      "clue": "Greeting",
      "answer": "O"
    }
  ],
  "solution": { "1,0": "2", "1,1": "O" }
}
''';
        final puzzle = KaruroPuzzle.fromJson(_puzzleJson(raw));
        expect(puzzle.entries, hasLength(2));
        final kinds = puzzle.entries.map((e) => e.kind).toList();
        expect(kinds, ['number', 'word']);
      },
    );
  });

  group('KaruroEntry.cells', () {
    test('across entries walk columns', () {
      const entry = KaruroNumberEntry(
        id: '1A',
        number: 1,
        direction: KaruroDirection.across,
        startRow: 2,
        startCol: 3,
        length: 4,
        sum: 10,
      );
      expect(entry.cells, [(2, 3), (2, 4), (2, 5), (2, 6)]);
    });

    test('down entries walk rows', () {
      const entry = KaruroNumberEntry(
        id: '1D',
        number: 1,
        direction: KaruroDirection.down,
        startRow: 2,
        startCol: 3,
        length: 4,
        sum: 10,
      );
      expect(entry.cells, [(2, 3), (3, 3), (4, 3), (5, 3)]);
    });
  });
}
