import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  });
}
