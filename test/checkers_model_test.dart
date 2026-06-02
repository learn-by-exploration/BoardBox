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

    test('restart resets the game', () {
      game.tap(5, 0);
      game.restart();
      expect(game.selectedRow, null);
      expect(game.current, CheckersPlayer.red);
    });
  });
}
