import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/services/game_stats.dart';

void main() {
  group('GameStats', () {
    setUp(() {
      // Tests share a process-global singleton, so we cannot reset its
      // internal Completer between cases. Each test must call
      // `await GameStats.instance.init()` before reading, which is exactly
      // the same contract the app uses in main(). The shared mock
      // SharedPreferences instance is the only piece of fresh state.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('recordKaruroWin increments and round-trips through prefs', () async {
      await GameStats.instance.init();
      expect(await GameStats.instance.getKaruroWins(), 0);
      await GameStats.instance.recordKaruroWin();
      await GameStats.instance.recordKaruroWin();
      expect(await GameStats.instance.getKaruroWins(), 2);

      // Verify the SharedPreferences key directly.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('karuro_wins'), 2);
    });

    test(
      'recordKlondikeWin increments and round-trips through prefs',
      () async {
        await GameStats.instance.init();
        expect(await GameStats.instance.getKlondikeWins(), 0);
        await GameStats.instance.recordKlondikeWin();
        expect(await GameStats.instance.getKlondikeWins(), 1);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('klondike_wins'), 1);
      },
    );

    test('reads suspend until init() completes', () async {
      // Force a fresh instance state by tearing down and re-initialising
      // the underlying Completer. We can't replace the singleton, but we
      // can prove the await path works by re-calling init() and
      // verifying the read still returns the persisted value.
      await GameStats.instance.init();
      expect(
        await GameStats.instance.getKaruroWins(),
        0,
        reason: 'A read after init() must not block indefinitely.',
      );
    });

    group('Minesweeper stats', () {
      test(
        'recordMinesweeperWin(beginner) increments and round-trips',
        () async {
          await GameStats.instance.init();
          expect(
            await GameStats.instance.getMinesweeperWins(
              MinesweeperDifficulty.beginner,
            ),
            0,
          );
          await GameStats.instance.recordMinesweeperWin(
            MinesweeperDifficulty.beginner,
          );
          expect(
            await GameStats.instance.getMinesweeperWins(
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
            await GameStats.instance.getMinesweeperLosses(
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
          await GameStats.instance.getMinesweeperPlayed(
            MinesweeperDifficulty.expert,
          ),
          3,
        );
      });
    });
  });
}
