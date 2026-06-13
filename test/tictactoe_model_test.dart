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
      m.play(0, 0);
      m.play(1, 0); // X, O
      m.play(0, 1);
      m.play(1, 1); // X, O
      m.play(0, 2); // X wins row 0
      expect(m.state, isA<TicTacToeWin>());
      expect((m.state as TicTacToeWin).winner, TicTacToePlayer.x);
    });

    test('detects column win', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      m.play(0, 1); // X, O
      m.play(1, 0);
      m.play(0, 2); // X, O
      m.play(2, 0); // X wins col 0
      expect(m.state, isA<TicTacToeWin>());
    });

    test('detects diagonal win', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      m.play(0, 1); // X, O
      m.play(1, 1);
      m.play(0, 2); // X, O
      m.play(2, 2); // X wins diagonal
      expect(m.state, isA<TicTacToeWin>());
    });

    test('detects draw', () {
      final m = TicTacToeModel(size: 3);
      // X O X
      // X X O
      // O X O  → draw
      m.play(0, 0);
      m.play(0, 1);
      m.play(0, 2);
      m.play(1, 2);
      m.play(1, 0);
      m.play(2, 0);
      m.play(1, 1);
      m.play(2, 2);
      m.play(2, 1);
      expect(m.state, isA<TicTacToeDraw>());
    });

    test('play returns false after game over', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      m.play(1, 0);
      m.play(0, 1);
      m.play(1, 1);
      m.play(0, 2); // X wins
      expect(m.play(2, 2), isFalse);
    });

    test('restart resets to initial state', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      m.play(0, 1);
      m.restart();
      expect(m.state, isA<TicTacToePlaying>());
      expect(m.current, TicTacToePlayer.x);
      expect(m.board.expand((r) => r).every((c) => c == null), isTrue);
    });
  });

  group('TicTacToeModel — 4×4', () {
    test('win length is 3', () {
      expect(TicTacToeModel.winLengthFor(4), 3);
    });

    test('3 in a row wins on 4×4', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0);
      m.play(1, 0);
      m.play(0, 1);
      m.play(1, 1);
      m.play(0, 2); // X wins row 0
      expect(m.state, isA<TicTacToeWin>());
    });
  });

  group('TicTacToeModel — 5×5', () {
    test('win length is 4', () {
      expect(TicTacToeModel.winLengthFor(5), 4);
    });

    test('4 in a row wins on 5×5', () {
      final m = TicTacToeModel(size: 5);
      m.play(0, 0);
      m.play(1, 0);
      m.play(0, 1);
      m.play(1, 1);
      m.play(0, 2);
      m.play(1, 2);
      m.play(0, 3); // X has 4 in a row
      expect(m.state, isA<TicTacToeWin>());
    });
  });

  group('Serialization', () {
    test('toJson/fromJson round-trips correctly', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0);
      m.play(1, 1);
      m.play(0, 1);
      final json = m.toJson();
      final restored = TicTacToeModel.fromJson(json);
      expect(restored.size, 4);
      expect(restored.current, m.current);
      expect(restored.board[0][0], TicTacToePlayer.x);
      expect(restored.board[1][1], TicTacToePlayer.o);
      expect(restored.board[0][1], TicTacToePlayer.x);
    });
  });

  group('TicTacToeModel — wouldWinAt probe', () {
    test('returns true when placing a piece would complete a line', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); // X
      m.play(1, 0); // O
      m.play(0, 1); // X — about to win on row 0
      expect(m.wouldWinAt(0, 2, TicTacToePlayer.x), isTrue);
      expect(m.wouldWinAt(0, 2, TicTacToePlayer.o), isFalse);
    });

    test('returns false when the cell is already occupied', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); // X
      // A probe on the occupied cell must not crash; it just observes
      // the line at (0,0), which has length 1 — below winLength=3.
      expect(m.wouldWinAt(0, 0, TicTacToePlayer.x), isFalse);
    });

    test('returns false for out-of-bounds probes', () {
      final m = TicTacToeModel(size: 3);
      expect(m.wouldWinAt(-1, 0, TicTacToePlayer.x), isFalse);
      expect(m.wouldWinAt(0, 99, TicTacToePlayer.x), isFalse);
    });

    test('does not mutate the board', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      m.play(1, 1);
      final snapshot = m.scratchBoard.map(List<TicTacToePlayer?>.of).toList();
      // Probe every empty cell for both players.
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          m.wouldWinAt(r, c, TicTacToePlayer.x);
          m.wouldWinAt(r, c, TicTacToePlayer.o);
        }
      }
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          expect(
            m.scratchBoard[r][c],
            snapshot[r][c],
            reason: 'cell ($r, $c) mutated by wouldWinAt',
          );
        }
      }
    });
  });
}
