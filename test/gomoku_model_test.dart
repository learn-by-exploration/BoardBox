import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/gomoku/gomoku_model.dart';

void main() {
  group('GomokuModel', () {
    late GomokuModel game;

    setUp(() {
      game = GomokuModel();
    });

    test('starts with black player', () {
      expect(game.current, GomokuPlayer.black);
      expect(game.state, isA<GomokuPlaying>());
    });

    test('alternates players', () {
      game.play(0, 0);
      expect(game.current, GomokuPlayer.white);
      game.play(1, 0);
      expect(game.current, GomokuPlayer.black);
    });

    test('cannot play on occupied cell', () {
      game.play(0, 0);
      expect(game.play(0, 0), false);
    });

    test('rejects out-of-bounds moves', () {
      expect(game.play(-1, 0), false);
      expect(game.play(0, -1), false);
      expect(game.play(GomokuModel.size, 0), false);
      expect(game.play(0, GomokuModel.size), false);
      expect(game.current, GomokuPlayer.black);
    });

    test('detects horizontal five-in-a-row', () {
      // Black plays row 0, cols 0-4; white plays row 1
      for (int i = 0; i < 4; i++) {
        game.play(0, i); // black
        game.play(1, i); // white
      }
      game.play(0, 4); // black wins
      expect(game.state, isA<GomokuWin>());
      expect((game.state as GomokuWin).winner, GomokuPlayer.black);
    });

    test('detects vertical five-in-a-row', () {
      for (int i = 0; i < 4; i++) {
        game.play(i, 0); // black
        game.play(i, 1); // white
      }
      game.play(4, 0); // black wins
      expect(game.state, isA<GomokuWin>());
      expect((game.state as GomokuWin).winner, GomokuPlayer.black);
    });

    test('restart resets the game', () {
      game.play(0, 0);
      game.restart();
      expect(game.board[0][0], null);
      expect(game.current, GomokuPlayer.black);
      expect(game.state, isA<GomokuPlaying>());
    });
  });
}
