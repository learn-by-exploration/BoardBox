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

    test(
      'completing two boxes with one line scores both and keeps the turn',
      () {
        // Set up: box (0,0) needs only its right side; box (0,1) needs only
        // its left side. The shared line is vLine(0, 1) — drawing it completes
        // BOTH boxes in one move. Player must keep the turn.
        game.drawHLine(0, 0); // top of (0,0) — P2
        game.drawHLine(1, 0); // bottom of (0,0) — P1
        game.drawVLine(0, 0); // left of (0,0) — P2
        game.drawHLine(0, 1); // top of (0,1) — P1
        game.drawHLine(1, 1); // bottom of (0,1) — P2
        game.drawVLine(0, 2); // right of (0,1) — P1
        // P1 now draws the shared vertical at (0,1) — captures BOTH boxes.
        game.drawVLine(0, 1);

        expect(game.score1, 2);
        expect(game.current, DotsPlayer.player1);
      },
    );

    test('restart resets scores', () {
      game.drawHLine(0, 0);
      game.restart();
      expect(game.score1, 0);
      expect(game.score2, 0);
      expect(game.current, DotsPlayer.player1);
    });

    test('supports a 7×7 dot grid', () {
      final largeGame = DotsModel(gridSize: 7);

      expect(largeGame.dotRows, 7);
      expect(largeGame.dotCols, 7);
      expect(largeGame.boxRows, 6);
      expect(largeGame.boxCols, 6);
      expect(largeGame.hLines.length, 7);
      expect(largeGame.hLines.first.length, 6);
      expect(largeGame.vLines.length, 6);
      expect(largeGame.vLines.first.length, 7);
      expect(largeGame.boxes.length, 6);
      expect(largeGame.boxes.first.length, 6);
      expect(largeGame.drawHLine(6, 5), isTrue);
      expect(largeGame.drawVLine(5, 6), isTrue);
    });

    test('serialization preserves the selected grid size', () {
      final largeGame = DotsModel(gridSize: 6);
      largeGame.drawHLine(0, 0);

      final restored = DotsModel.fromJson(largeGame.toJson());

      expect(restored.gridSize, 6);
      expect(restored.hLines[0][0], DotsPlayer.player1);
    });

    test('legacy saves infer their grid size from line data', () {
      final json = DotsModel().toJson()..remove('gridSize');

      final restored = DotsModel.fromJson(json);

      expect(restored.gridSize, 5);
    });
  });
}
