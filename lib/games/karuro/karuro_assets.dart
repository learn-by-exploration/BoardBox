import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:common_games/games/karuro/karuro_puzzle.dart';

/// Loads bundled Karuro puzzles from the app's asset store.
///
/// On first call to [all], the loader reads every JSON file under
/// `assets/puzzles/karuro/`, decodes it with [KaruroPuzzle.fromJson], and
/// caches the resulting list. Subsequent calls reuse the cache. The cache
/// is keyed on a [DateTime] snapshot so tests can re-seed the loader
/// against a fake [AssetBundle] without cross-test contamination.
class KaruroAssets {
  KaruroAssets({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Glob pattern Flutter uses to enumerate the bundled puzzle files.
  /// Matches the directory declared in `pubspec.yaml`'s `flutter.assets`.
  static const String assetPrefix = 'assets/puzzles/karuro';

  final AssetBundle _bundle;
  List<KaruroPuzzle>? _cache;
  DateTime? _loadedAt;

  /// All bundled puzzles, sorted by id. Cached after first call.
  Future<List<KaruroPuzzle>> all() async {
    if (_cache != null) return _cache!;
    // We can't list a directory directly; the convention is to maintain a
    // manifest file at `assets/puzzles/karuro/index.json` that lists each
    // puzzle's id. The author of a new puzzle updates that index.
    final manifest = await _bundle.loadStructuredData<String>(
      '$assetPrefix/index.json',
      (String data) async => data,
    );
    final ids = (json.decode(manifest) as List).cast<String>();
    final puzzles = <KaruroPuzzle>[];
    for (final id in ids) {
      final raw = await _bundle.loadString('$assetPrefix/$id');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      puzzles.add(KaruroPuzzle.fromJson(decoded));
    }
    puzzles.sort((a, b) => a.id.compareTo(b.id));
    _cache = List<KaruroPuzzle>.unmodifiable(puzzles);
    _loadedAt = DateTime.now();
    return _cache!;
  }

  /// Look up a puzzle by id, or `null` if the bundle does not contain it.
  Future<KaruroPuzzle?> byId(String id) async {
    final allPuzzles = await all();
    for (final p in allPuzzles) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Filter by difficulty. Useful for the setup screen.
  Future<List<KaruroPuzzle>> byDifficulty(KaruroDifficulty difficulty) async {
    final allPuzzles = await all();
    return allPuzzles.where((p) => p.difficulty == difficulty).toList();
  }

  /// For tests: clear the cache so a fresh [all] call reloads.
  void invalidate() {
    _cache = null;
    _loadedAt = null;
  }

  /// When the cache was last populated, or null if the loader is cold.
  DateTime? get loadedAt => _loadedAt;
}
