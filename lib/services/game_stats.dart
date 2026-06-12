import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/models/game_mode.dart';
import 'package:common_games/screens/home_screen.dart';

/// Tracks wins, losses, and draws per game and difficulty.
class GameStats {
  GameStats._();

  static final GameStats instance = GameStats._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String _key(GameType game, AiDifficulty difficulty, String stat) =>
      '${game.name}_${difficulty.name}_$stat';

  int getWins(GameType game, AiDifficulty difficulty) =>
      _prefs?.getInt(_key(game, difficulty, 'wins')) ?? 0;

  int getLosses(GameType game, AiDifficulty difficulty) =>
      _prefs?.getInt(_key(game, difficulty, 'losses')) ?? 0;

  int getDraws(GameType game, AiDifficulty difficulty) =>
      _prefs?.getInt(_key(game, difficulty, 'draws')) ?? 0;

  int getTotalPlayed(GameType game) {
    return getTotalWins(game) + getTotalLosses(game) + getTotalDraws(game);
  }

  int getTotalWins(GameType game) => AiDifficulty.values.fold(
    0,
    (total, difficulty) => total + getWins(game, difficulty),
  );

  int getTotalLosses(GameType game) => AiDifficulty.values.fold(
    0,
    (total, difficulty) => total + getLosses(game, difficulty),
  );

  int getTotalDraws(GameType game) => AiDifficulty.values.fold(
    0,
    (total, difficulty) => total + getDraws(game, difficulty),
  );

  int getAllGamesWins() =>
      GameType.values.fold(0, (total, game) => total + getTotalWins(game));

  int getAllGamesLosses() =>
      GameType.values.fold(0, (total, game) => total + getTotalLosses(game));

  int getAllGamesDraws() =>
      GameType.values.fold(0, (total, game) => total + getTotalDraws(game));

  Future<void> recordWin(GameType game, AiDifficulty difficulty) async {
    final key = _key(game, difficulty, 'wins');
    await _prefs?.setInt(key, (_prefs?.getInt(key) ?? 0) + 1);
  }

  Future<void> recordLoss(GameType game, AiDifficulty difficulty) async {
    final key = _key(game, difficulty, 'losses');
    await _prefs?.setInt(key, (_prefs?.getInt(key) ?? 0) + 1);
  }

  Future<void> recordDraw(GameType game, AiDifficulty difficulty) async {
    final key = _key(game, difficulty, 'draws');
    await _prefs?.setInt(key, (_prefs?.getInt(key) ?? 0) + 1);
  }

  // ─── Karuro (single-player puzzle) ────────────────────────────────────
  // Karuro has no AI opponent and no per-difficulty breakdown in v1, so
  // it lives outside the (game × AiDifficulty) key shape used by the
  // other games. The single counter is shown on the home tile.

  static const String _karuroWinsKey = 'karuro_wins';

  int getKaruroWins() => _prefs?.getInt(_karuroWinsKey) ?? 0;

  Future<void> recordKaruroWin() async {
    await _prefs?.setInt(_karuroWinsKey, getKaruroWins() + 1);
  }

  // ─── Klondike (single-player card game) ──────────────────────────────
  // Klondike has no AI opponent and no per-difficulty breakdown in v1, so
  // it mirrors the Karuro pattern: a single win counter surfaced on the
  // home tile.

  static const String _klondikeWinsKey = 'klondike_wins';

  int getKlondikeWins() => _prefs?.getInt(_klondikeWinsKey) ?? 0;

  Future<void> recordKlondikeWin() async {
    await _prefs?.setInt(_klondikeWinsKey, getKlondikeWins() + 1);
  }
}
