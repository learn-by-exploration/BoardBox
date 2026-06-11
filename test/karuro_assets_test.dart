import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/karuro/karuro_assets.dart';
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
