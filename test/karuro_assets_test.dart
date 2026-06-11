import 'dart:math' as math;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/karuro/karuro_assets.dart';
import 'package:common_games/games/karuro/karuro_model.dart';
import 'package:common_games/games/karuro/karuro_puzzle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KaruroAssets', () {
    const manifest = '["karuro-001.json"]';
    const puzzleJson = '''
{
  "id": "karuro-001",
  "title": "Sunny Start",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 3,
    "maxWordRunLength": 4,
    "crossingsPerCell": 2,
    "extremeSumShare": 0.5
  },
  "grid": { "rows": 5, "cols": 5 },
  "cells": [
    ["#", "#", "#", "#", "#"],
    ["#", " ", " ", " ", "#"],
    ["#", " ", " ", " ", "#"],
    ["#", " ", " ", " ", "#"],
    ["#", "#", "#", "#", "#"]
  ],
  "entries": [
    {
      "id": "1A",
      "number": 1,
      "direction": "across",
      "start": { "row": 1, "col": 1 },
      "length": 3,
      "kind": "number",
      "sum": 6
    }
  ],
  "solution": { "1,1": "1", "1,2": "2", "1,3": "3" }
}
''';

    setUp(() {
      // Each test starts with a clean asset bundle.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('loads all puzzles from the manifest', () async {
      final bundle = TestAssetBundle({
        'assets/puzzles/karuro/index.json': manifest,
        'assets/puzzles/karuro/karuro-001.json': puzzleJson,
      });
      final loader = KaruroAssets(bundle: bundle);
      final puzzles = await loader.all();
      expect(puzzles, hasLength(1));
      expect(puzzles.single.id, 'karuro-001');
    });

    test('all() caches results across calls', () async {
      final bundle = TestAssetBundle({
        'assets/puzzles/karuro/index.json': manifest,
        'assets/puzzles/karuro/karuro-001.json': puzzleJson,
      });
      final loader = KaruroAssets(bundle: bundle);
      final first = await loader.all();
      final second = await loader.all();
      expect(identical(first, second), isTrue);
      expect(loader.loadedAt, isNotNull);
    });

    test('invalidate() forces a reload', () async {
      final bundle = TestAssetBundle({
        'assets/puzzles/karuro/index.json': manifest,
        'assets/puzzles/karuro/karuro-001.json': puzzleJson,
      });
      final loader = KaruroAssets(bundle: bundle);
      final first = await loader.all();
      final firstLoadedAt = loader.loadedAt;
      loader.invalidate();
      final second = await loader.all();
      expect(identical(first, second), isFalse);
      expect(loader.loadedAt, isNotNull);
      expect(loader.loadedAt, isNot(firstLoadedAt));
    });

    test('byId returns the matching puzzle or null', () async {
      final bundle = TestAssetBundle({
        'assets/puzzles/karuro/index.json': manifest,
        'assets/puzzles/karuro/karuro-001.json': puzzleJson,
      });
      final loader = KaruroAssets(bundle: bundle);
      final found = await loader.byId('karuro-001');
      expect(found, isNotNull);
      expect(found!.id, 'karuro-001');
      final missing = await loader.byId('does-not-exist');
      expect(missing, isNull);
    });

    test('byDifficulty filters by enum bucket', () async {
      const easyManifest = '["easy-1.json", "medium-1.json"]';
      const easyJson = '''
{
  "id": "easy-1",
  "title": "Easy One",
  "difficulty": "easy",
  "metrics": {
    "maxNumericRunLength": 2,
    "maxWordRunLength": 0,
    "crossingsPerCell": 1,
    "extremeSumShare": 0
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
      "sum": 3
    }
  ],
  "solution": { "1,0": "1", "1,1": "2" }
}
''';
      const mediumJson = '''
{
  "id": "medium-1",
  "title": "Medium One",
  "difficulty": "medium",
  "metrics": {
    "maxNumericRunLength": 3,
    "maxWordRunLength": 0,
    "crossingsPerCell": 1,
    "extremeSumShare": 0
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
      "sum": 7
    }
  ],
  "solution": { "1,0": "3", "1,1": "4" }
}
''';
      final bundle = TestAssetBundle({
        'assets/puzzles/karuro/index.json': easyManifest,
        'assets/puzzles/karuro/easy-1.json': easyJson,
        'assets/puzzles/karuro/medium-1.json': mediumJson,
      });
      final loader = KaruroAssets(bundle: bundle);
      final easy = await loader.byDifficulty(KaruroDifficulty.easy);
      expect(easy.map((p) => p.id), ['easy-1']);
      final medium = await loader.byDifficulty(KaruroDifficulty.medium);
      expect(medium.map((p) => p.id), ['medium-1']);
      final hard = await loader.byDifficulty(KaruroDifficulty.hard);
      expect(hard, isEmpty);
    });
  });

  group('KaruroAssets — bundled puzzles', () {
    // These tests load the real `assets/puzzles/karuro/` bundle. They
    // catch schema drift, missing-index entries, and authored-but-broken
    // puzzles that the mock-bundle tests above can't see.
    late KaruroAssets loader;
    late List<KaruroPuzzle> puzzles;

    setUpAll(() async {
      loader = KaruroAssets();
      puzzles = await loader.all();
    });

    test('index.json lists 41 puzzles and every entry parses', () {
      expect(puzzles, hasLength(41));
      // ids must be unique and in lexicographic order
      final ids = puzzles.map((p) => p.id).toList();
      expect(ids.toSet(), hasLength(41));
      final sorted = [...ids]..sort();
      expect(ids, sorted);
    });

    test('every puzzle has a difficulty bucket and at least one entry', () {
      for (final p in puzzles) {
        expect(
          KaruroDifficulty.values,
          contains(p.difficulty),
          reason: '${p.id} has an unknown difficulty ${p.difficulty}',
        );
        expect(p.entries, isNotEmpty, reason: '${p.id} has no entries');
      }
    });

    test('metrics reflect the actual entries', () {
      for (final p in puzzles) {
        int maxNumeric = 0;
        int maxWord = 0;
        for (final e in p.entries) {
          if (e is KaruroNumberEntry) {
            maxNumeric = math.max(maxNumeric, e.length);
          } else if (e is KaruroWordEntry) {
            maxWord = math.max(maxWord, e.length);
          }
        }
        expect(
          p.metrics.maxNumericRunLength,
          maxNumeric,
          reason: '${p.id} metric maxNumericRunLength mismatch',
        );
        expect(
          p.metrics.maxWordRunLength,
          maxWord,
          reason: '${p.id} metric maxWordRunLength mismatch',
        );
        // extremeSumShare is in [0, 1]
        expect(p.metrics.extremeSumShare, inInclusiveRange(0, 1));
        expect(p.metrics.crossingsPerCell, greaterThanOrEqualTo(0));
      }
    });

    test('difficulty distribution matches the bundle (15/14/12)', () {
      final easy = puzzles.where((p) => p.difficulty == KaruroDifficulty.easy);
      final medium = puzzles.where(
        (p) => p.difficulty == KaruroDifficulty.medium,
      );
      final hard = puzzles.where((p) => p.difficulty == KaruroDifficulty.hard);
      expect(easy, hasLength(15));
      expect(medium, hasLength(14));
      expect(hard, hasLength(12));
    });

    test('entering the solution for two puzzles flips isWon', () {
      for (final p in puzzles.take(2)) {
        final model = KaruroModel(p);
        for (int r = 0; r < p.rows; r++) {
          for (int c = 0; c < p.cols; c++) {
            if (p.cells[r][c] is! KaruroEntryCell) continue;
            final v = p.solutionAt(r, c);
            if (v == null) continue;
            model.enterValue(r, c, v);
          }
        }
        expect(
          model.isWon,
          isTrue,
          reason: '${p.id} solution did not flip isWon',
        );
        expect(model.state, isA<KaruroWon>());
      }
    });
  });
}

/// In-memory [AssetBundle] for tests. Looks up string assets from a fixed
/// map; throws [FlutterError] for unknown keys so missing-asset bugs surface.
class TestAssetBundle extends CachingAssetBundle {
  TestAssetBundle(this._files);

  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async {
    final value = _files[key];
    if (value == null) {
      throw FlutterError('TestAssetBundle: missing asset $key');
    }
    return ByteData.view(Uint8List.fromList(value.codeUnits).buffer);
  }
}
