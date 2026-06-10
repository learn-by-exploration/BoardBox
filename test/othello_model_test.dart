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

    test('ensureValidTurn keeps current player when they have moves', () {
      game.ensureValidTurn();
      expect(game.current, OthelloPlayer.black);
      expect(game.state, isA<OthelloPlaying>());
    });

    test('fromJson rejects out-of-range enum index with FormatException', () {
      final json = OthelloModel().toJson();
      json['current'] = 99; // forward-compat / corrupt save
      expect(
        () => OthelloModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson rejects truncated board with FormatException', () {
      final json = OthelloModel().toJson();
      // Truncate to 3 rows
      json['board'] = (json['board'] as List).sublist(0, 3);
      expect(
        () => OthelloModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson rejects unknown state type with FormatException', () {
      final json = OthelloModel().toJson();
      json['state'] = {'type': 'unknown_future_state'};
      expect(
        () => OthelloModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
