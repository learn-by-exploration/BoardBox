import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/tictactoe/tictactoe_model.dart';

void main() {
  group('TicTacToeModel — 3×3', () {
    test('starts with X, Playing, empty board', () {
      final m = TicTacToeModel(size: 3);
      expect(m.current, TicTacToePlayer.x);
      expect(m.state, isA<TicTacToePlaying>());
      expect(m.board.expand((r) => r).every((c) => c == null), isTrue);
    });

    test('play returns false on occupied cell', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      expect(m.play(0, 0), isFalse);
    });

    test('alternates turns', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      expect(m.current, TicTacToePlayer.o);
      m.play(1, 1);
      expect(m.current, TicTacToePlayer.x);
    });

    test('detects row win for X', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(1, 0); // X, O
      m.play(0, 1); m.play(1, 1); // X, O
      m.play(0, 2); // X wins row 0
      expect(m.state, isA<TicTacToeWin>());
      expect((m.state as TicTacToeWin).winner, TicTacToePlayer.x);
    });

    test('detects column win', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(0, 1); // X, O
      m.play(1, 0); m.play(0, 2); // X, O
      m.play(2, 0); // X wins col 0
      expect(m.state, isA<TicTacToeWin>());
    });

    test('detects diagonal win', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(0, 1); // X, O
      m.play(1, 1); m.play(0, 2); // X, O
      m.play(2, 2); // X wins diagonal
      expect(m.state, isA<TicTacToeWin>());
    });

    test('detects draw', () {
      final m = TicTacToeModel(size: 3);
      // X O X
      // X X O
      // O X O  → draw
      m.play(0, 0); m.play(0, 1);
      m.play(0, 2); m.play(1, 2);
      m.play(1, 0); m.play(2, 0);
      m.play(1, 1); m.play(2, 2);
      m.play(2, 1);
      expect(m.state, isA<TicTacToeDraw>());
    });

    test('play returns false after game over', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); // X wins
      expect(m.play(2, 2), isFalse);
    });

    test('restart resets to initial state', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(0, 1);
      m.restart();
      expect(m.state, isA<TicTacToePlaying>());
      expect(m.current, TicTacToePlayer.x);
      expect(m.board.expand((r) => r).every((c) => c == null), isTrue);
    });
  });

  group('TicTacToeModel — 4×4', () {
    test('win length is 4', () {
      expect(TicTacToeModel.winLengthFor(4), 4);
    });

    test('3 in a row does NOT win on 4×4', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); // X has 3 in a row — should still be Playing
      expect(m.state, isA<TicTacToePlaying>());
    });

    test('4 in a row wins on 4×4', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); m.play(1, 2);
      m.play(0, 3); // X wins row 0
      expect(m.state, isA<TicTacToeWin>());
    });
  });

  group('TicTacToeModel — 5×5', () {
    test('win length is 4', () {
      expect(TicTacToeModel.winLengthFor(5), 4);
    });

    test('4 in a row wins on 5×5', () {
      final m = TicTacToeModel(size: 5);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); m.play(1, 2);
      m.play(0, 3); // X has 4 in a row
      expect(m.state, isA<TicTacToeWin>());
    });
  });

  group('Serialization', () {
    test('toJson/fromJson round-trips correctly', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0); m.play(1, 1); m.play(0, 1);
      final json = m.toJson();
      final restored = TicTacToeModel.fromJson(json);
      expect(restored.size, 4);
      expect(restored.current, m.current);
      expect(restored.board[0][0], TicTacToePlayer.x);
      expect(restored.board[1][1], TicTacToePlayer.o);
      expect(restored.board[0][1], TicTacToePlayer.x);
    });
  });
}
