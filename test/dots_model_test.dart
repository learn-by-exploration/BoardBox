import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/dots_and_boxes/dots_model.dart';

void main() {
  group('DotsModel', () {
    late DotsModel game;

    setUp(() {
      game = DotsModel();
    });

    test('player 1 goes first', () {
      expect(game.current, DotsPlayer.player1);
      expect(game.state, isA<DotsPlaying>());
    });

    test('drawing a line switches player', () {
      game.drawHLine(0, 0);
      expect(game.current, DotsPlayer.player2);
    });

    test('cannot draw same line twice', () {
      game.drawHLine(0, 0);
      expect(game.drawHLine(0, 0), false);
    });

    test('capturing a box gives extra turn', () {
      // Complete a box at (0,0) — needs top, bottom, left, right
      game.drawHLine(0, 0); // top - switches to P2
      game.drawHLine(1, 0); // bottom - switches to P1
      game.drawVLine(0, 0); // left - switches to P2
      // P2 completes the box
      game.drawVLine(0, 1); // right - captures! P2 keeps turn
      expect(game.score2, 1);
      expect(game.current, DotsPlayer.player2); // extra turn
    });

    test('restart resets scores', () {
      game.drawHLine(0, 0);
      game.restart();
      expect(game.score1, 0);
      expect(game.score2, 0);
      expect(game.current, DotsPlayer.player1);
    });
  });
}
