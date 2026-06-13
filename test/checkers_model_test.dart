import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/checkers/checkers_model.dart';

void main() {
  group('CheckersModel', () {
    late CheckersModel game;

    setUp(() {
      game = CheckersModel();
    });

    test('red moves first', () {
      expect(game.current, CheckersPlayer.red);
      expect(game.state, isA<CheckersPlaying>());
    });

    test('initial board has 12 pieces per player', () {
      int red = 0, black = 0;
      for (final row in game.board) {
        for (final cell in row) {
          if (cell == 'r') red++;
          if (cell == 'b') black++;
        }
      }
      expect(red, 12);
      expect(black, 12);
    });

    test('selecting own piece highlights moves', () {
      // Red piece at (5,0) - tap it
      final result = game.tap(5, 0);
      expect(result, true);
      expect(game.selectedRow, 5);
      expect(game.selectedCol, 0);
      expect(game.highlightedMoves.isNotEmpty, true);
    });

    test('cannot select opponent piece', () {
      final result = game.tap(2, 1); // black piece
      expect(result, false);
    });

    test('rejects out-of-bounds taps', () {
      expect(game.tap(-1, 0), false);
      expect(game.tap(0, -1), false);
      expect(game.tap(CheckersModel.size, 0), false);
      expect(game.tap(0, CheckersModel.size), false);
      expect(game.current, CheckersPlayer.red);
    });

    test('restart resets the game', () {
      game.tap(5, 0);
      game.restart();
      expect(game.selectedRow, null);
      expect(game.current, CheckersPlayer.red);
    });

    test('multi-jump that captures all opponent pieces wins immediately', () {
      // Construct a position where red can chain-capture every black piece.
      // We test the public contract: after a single tap+execute sequence that
      // removes the last opponent piece mid-chain, state becomes CheckersWin.
      // Build a custom board via the JSON path:
      final customJson = <String, Object?>{
        'board': [
          [null, null, null, null, null, null, null, null],
          [null, null, 'b', null, null, null, null, null],
          [null, null, null, 'r', null, null, null, null],
          [null, null, null, null, null, null, null, null],
          [null, null, null, null, null, null, null, null],
          [null, null, null, null, null, null, null, null],
          [null, null, null, null, null, null, null, null],
          [null, null, null, null, null, null, null, null],
        ],
        'current': 0, // red
        'state': {'type': 'playing'},
        'selectedRow': null,
        'selectedCol': null,
        'highlightedMoves': <List<int>>[],
        'midJump': false,
      };
      final g = CheckersModel.fromJson(customJson);
      // Red at (2,3) jumps to (0,1) over (1,2)? No: (2,3) to (0,1) isn't
      // a valid jump. (2,3) can jump (1,2)→(0,1). After landing at (0,1)
      // the chain ends. Opponent still has no pieces (only 1 black, captured).
      // Expect state == CheckersWin(red).
      // Select piece
      expect(g.tap(2, 3), true);
      // Perform the jump
      expect(g.tap(0, 1), true);
      expect(g.state, isA<CheckersWin>());
      expect((g.state as CheckersWin).winner, CheckersPlayer.red);
    });

    test('fromJson rejects invalid piece character with FormatException', () {
      final json = CheckersModel().toJson();
      (json['board'] as List)[0][0] = 'x'; // invalid
      expect(
        () => CheckersModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('enumerateMovesFor returns legal moves and does not mutate state', () {
      // Red is to move. Tap on (5,0) selects it and highlights moves.
      // enumerateMovesFor should return the same moves without touching
      // selectedRow/Col or highlightedMoves on the model.
      final moves = game.enumerateMovesFor(5, 0);
      // From a fresh game, the (5,0) red man can move to (4,1).
      expect(moves, isNotEmpty);
      expect(
        moves,
        contains(predicate<List<int>>((m) => m[0] == 4 && m[1] == 1)),
      );
      // State must be untouched.
      expect(game.selectedRow, isNull);
      expect(game.selectedCol, isNull);
      expect(game.highlightedMoves, isEmpty);
    });

    test('enumerateMovesFor returns empty for opponent pieces', () {
      // Black piece at (2,1) — not red's piece, so no legal moves.
      expect(game.enumerateMovesFor(2, 1), isEmpty);
    });
  });
}
