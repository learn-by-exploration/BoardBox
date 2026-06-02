import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/othello/othello_model.dart';

void main() {
  group('OthelloModel', () {
    late OthelloModel game;

    setUp(() {
      game = OthelloModel();
    });

    test('initial board has 4 pieces', () {
      expect(game.blackCount, 2);
      expect(game.whiteCount, 2);
    });

    test('black moves first', () {
      expect(game.current, OthelloPlayer.black);
    });

    test('valid moves exist at start', () {
      final moves = game.getValidMoves();
      expect(moves.isNotEmpty, true);
    });

    test('playing on invalid cell returns false', () {
      expect(game.play(0, 0), false); // no flips possible
    });

    test('rejects out-of-bounds moves', () {
      expect(game.play(-1, 0), false);
      expect(game.play(0, -1), false);
      expect(game.play(OthelloModel.size, 0), false);
      expect(game.play(0, OthelloModel.size), false);
      expect(game.current, OthelloPlayer.black);
    });

    test('playing valid move flips pieces', () {
      // d3 (row=2, col=3) is valid for black at start
      final played = game.play(2, 3);
      expect(played, true);
      expect(game.blackCount, 4);
      expect(game.whiteCount, 1);
    });

    test('restart resets the game', () {
      game.play(2, 3);
      game.restart();
      expect(game.blackCount, 2);
      expect(game.whiteCount, 2);
      expect(game.current, OthelloPlayer.black);
    });
  });
}
