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
    int total = 0;
    for (final d in AiDifficulty.values) {
      total += getWins(game, d) + getLosses(game, d) + getDraws(game, d);
    }
    return total;
  }

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
}
