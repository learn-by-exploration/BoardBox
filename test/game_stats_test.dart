import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/services/game_stats.dart';

void main() {
  group('GameStats', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('recordKaruroWin increments and round-trips through prefs', () async {
      await GameStats.instance.init();
      expect(GameStats.instance.getKaruroWins(), 0);
      await GameStats.instance.recordKaruroWin();
      await GameStats.instance.recordKaruroWin();
      expect(GameStats.instance.getKaruroWins(), 2);

      // Re-init from the same mock prefs to simulate a process restart.
      // (init() just reads the existing singleton's prefs back, so a
      // fresh getInstance is the closest analogue to a restart.)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('karuro_wins'), 2);
    });

    test(
      'recordKlondikeWin increments and round-trips through prefs',
      () async {
        await GameStats.instance.init();
        expect(GameStats.instance.getKlondikeWins(), 0);
        await GameStats.instance.recordKlondikeWin();
        expect(GameStats.instance.getKlondikeWins(), 1);

        // Round-trip through SharedPreferences to verify the key/value path.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('klondike_wins'), 1);
      },
    );

    group('Minesweeper stats', () {
      test(
        'recordMinesweeperWin(beginner) increments and round-trips',
        () async {
          await GameStats.instance.init();
          expect(
            GameStats.instance.getMinesweeperWins(
              MinesweeperDifficulty.beginner,
            ),
            0,
          );
          await GameStats.instance.recordMinesweeperWin(
            MinesweeperDifficulty.beginner,
          );
          expect(
            GameStats.instance.getMinesweeperWins(
              MinesweeperDifficulty.beginner,
            ),
            1,
          );
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('minesweeper_beginner_wins'), 1);
        },
      );

      test(
        'recordMinesweeperLoss(intermediate) increments and round-trips',
        () async {
          await GameStats.instance.init();
          await GameStats.instance.recordMinesweeperLoss(
            MinesweeperDifficulty.intermediate,
          );
          expect(
            GameStats.instance.getMinesweeperLosses(
              MinesweeperDifficulty.intermediate,
            ),
            1,
          );
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('minesweeper_intermediate_losses'), 1);
        },
      );

      test('getMinesweeperPlayed sums wins + losses', () async {
        await GameStats.instance.init();
        await GameStats.instance.recordMinesweeperWin(
          MinesweeperDifficulty.expert,
        );
        await GameStats.instance.recordMinesweeperWin(
          MinesweeperDifficulty.expert,
        );
        await GameStats.instance.recordMinesweeperLoss(
          MinesweeperDifficulty.expert,
        );
        expect(
          GameStats.instance.getMinesweeperPlayed(MinesweeperDifficulty.expert),
          3,
        );
      });
    });
  });
}
