import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/models/game_mode.dart';

/// Tracks wins, losses, and draws per game and difficulty.
///
/// **Initialization contract:** all public getters and setters await
/// [ready] before touching the underlying [SharedPreferences]. Any
/// read or write that races with [init] is suspended until the
/// initialization future completes. The first frame after a cold
/// start can therefore show the real persisted values without
/// "silent 0" fallthroughs.
///
/// **Why a `Future` gate, not sync `int` getters:** the prior
/// implementation returned `_prefs?.getInt(...) ?? 0`, so any read
/// before [init] finished would silently return 0. The home screen
/// renders before the splash finishes its first frame, so the
/// "0 wins" shown in that window was a real (if brief) user-visible
/// wrong value. Reads and writes now both await the same ready
/// future, eliminating the race.
class GameStats {
  GameStats._();

  static final GameStats instance = GameStats._();

  SharedPreferences? _prefs;
  final Completer<void> _ready = Completer<void>();

  /// True once [init] has populated [_prefs] and completed the
  /// ready gate. Exposed for tests via [ready].
  Future<void> get ready => _ready.future;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_ready.isCompleted) _ready.complete();
  }

  String _key(GameType game, AiDifficulty difficulty, String stat) =>
      '${game.name}_${difficulty.name}_$stat';

  Future<int> getWins(GameType game, AiDifficulty difficulty) async {
    await _ready.future;
    return _prefs?.getInt(_key(game, difficulty, 'wins')) ?? 0;
  }

  Future<int> getLosses(GameType game, AiDifficulty difficulty) async {
    await _ready.future;
    return _prefs?.getInt(_key(game, difficulty, 'losses')) ?? 0;
  }

  Future<int> getDraws(GameType game, AiDifficulty difficulty) async {
    await _ready.future;
    return _prefs?.getInt(_key(game, difficulty, 'draws')) ?? 0;
  }

  Future<int> getTotalPlayed(GameType game) async =>
      (await getTotalWins(game)) +
      (await getTotalLosses(game)) +
      (await getTotalDraws(game));

  Future<int> getTotalWins(GameType game) async {
    var total = 0;
    for (final difficulty in AiDifficulty.values) {
      total += await getWins(game, difficulty);
    }
    return total;
  }

  Future<int> getTotalLosses(GameType game) async {
    var total = 0;
    for (final difficulty in AiDifficulty.values) {
      total += await getLosses(game, difficulty);
    }
    return total;
  }

  Future<int> getTotalDraws(GameType game) async {
    var total = 0;
    for (final difficulty in AiDifficulty.values) {
      total += await getDraws(game, difficulty);
    }
    return total;
  }

  Future<int> getAllGamesWins() async {
    var total = 0;
    for (final game in GameType.values) {
      total += await getTotalWins(game);
    }
    return total;
  }

  Future<int> getAllGamesLosses() async {
    var total = 0;
    for (final game in GameType.values) {
      total += await getTotalLosses(game);
    }
    return total;
  }

  Future<int> getAllGamesDraws() async {
    var total = 0;
    for (final game in GameType.values) {
      total += await getTotalDraws(game);
    }
    return total;
  }

  Future<void> recordWin(GameType game, AiDifficulty difficulty) async {
    await _ready.future;
    final key = _key(game, difficulty, 'wins');
    final prefs = _prefs!;
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  Future<void> recordLoss(GameType game, AiDifficulty difficulty) async {
    await _ready.future;
    final key = _key(game, difficulty, 'losses');
    final prefs = _prefs!;
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  Future<void> recordDraw(GameType game, AiDifficulty difficulty) async {
    await _ready.future;
    final key = _key(game, difficulty, 'draws');
    final prefs = _prefs!;
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  // ─── Karuro (single-player puzzle) ────────────────────────────────────
  // Karuro has no AI opponent and no per-difficulty breakdown in v1, so
  // it lives outside the (game × AiDifficulty) key shape used by the
  // other games. The single counter is shown on the home tile.

  static const String _karuroWinsKey = 'karuro_wins';

  Future<int> getKaruroWins() async {
    await _ready.future;
    return _prefs?.getInt(_karuroWinsKey) ?? 0;
  }

  Future<void> recordKaruroWin() async {
    await _ready.future;
    final prefs = _prefs!;
    await prefs.setInt(_karuroWinsKey, (await getKaruroWins()) + 1);
  }

  // ─── Klondike (single-player card game) ──────────────────────────────
  // Klondike has no AI opponent and no per-difficulty breakdown in v1, so
  // it mirrors the Karuro pattern: a single win counter surfaced on the
  // home tile.

  static const String _klondikeWinsKey = 'klondike_wins';

  Future<int> getKlondikeWins() async {
    await _ready.future;
    return _prefs?.getInt(_klondikeWinsKey) ?? 0;
  }

  Future<void> recordKlondikeWin() async {
    await _ready.future;
    final prefs = _prefs!;
    await prefs.setInt(_klondikeWinsKey, (await getKlondikeWins()) + 1);
  }

  // ─── Minesweeper (single-player puzzle, per-difficulty) ───────────────
  // Minesweeper has no AI opponent but does have three classic
  // difficulty presets. Each gets its own wins/losses pair so the home
  // tile and setup screen can break down record per board size.
  // Keys follow the `<game>_<difficulty>_<stat>` shape used by the
  // AI-difficulty methods above.

  static String _minesweeperWinsKey(MinesweeperDifficulty d) =>
      'minesweeper_${d.name}_wins';

  static String _minesweeperLossesKey(MinesweeperDifficulty d) =>
      'minesweeper_${d.name}_losses';

  Future<int> getMinesweeperWins(MinesweeperDifficulty d) async {
    await _ready.future;
    return _prefs?.getInt(_minesweeperWinsKey(d)) ?? 0;
  }

  Future<int> getMinesweeperLosses(MinesweeperDifficulty d) async {
    await _ready.future;
    return _prefs?.getInt(_minesweeperLossesKey(d)) ?? 0;
  }

  Future<int> getMinesweeperPlayed(MinesweeperDifficulty d) async =>
      (await getMinesweeperWins(d)) + (await getMinesweeperLosses(d));

  Future<void> recordMinesweeperWin(MinesweeperDifficulty d) async {
    await _ready.future;
    final key = _minesweeperWinsKey(d);
    final prefs = _prefs!;
    await prefs.setInt(key, (await getMinesweeperWins(d)) + 1);
  }

  Future<void> recordMinesweeperLoss(MinesweeperDifficulty d) async {
    await _ready.future;
    final key = _minesweeperLossesKey(d);
    final prefs = _prefs!;
    await prefs.setInt(key, (await getMinesweeperLosses(d)) + 1);
  }
}
