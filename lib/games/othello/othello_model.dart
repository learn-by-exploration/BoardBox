import 'dart:collection';

/// Pure Dart game logic for Othello (Reversi).
/// Reference: https://github.com/nicoseng/othello_flutter (flip mechanics)
enum OthelloPlayer { black, white }

sealed class OthelloState {
  const OthelloState();
}

final class OthelloPlaying extends OthelloState {
  const OthelloPlaying();
}

final class OthelloWin extends OthelloState {
  const OthelloWin(this.winner);
  final OthelloPlayer winner;
}

final class OthelloDraw extends OthelloState {
  const OthelloDraw();
}

class OthelloModel {
  static const int size = 8;

  List<List<OthelloPlayer?>> _board;
  OthelloPlayer current;
  OthelloState state;
  int blackCount;
  int whiteCount;

  OthelloModel()
      : _board = List.generate(size, (_) => List.filled(size, null)),
        current = OthelloPlayer.black,
        state = const OthelloPlaying(),
        blackCount = 2,
        whiteCount = 2 {
    _setupInitial();
  }

  /// Read-only view of the board.
  List<UnmodifiableListView<OthelloPlayer?>> get board =>
      _board.map(UnmodifiableListView<OthelloPlayer?>.new).toList();

  void _setupInitial() {
    const mid = size ~/ 2;
    _board[mid - 1][mid - 1] = OthelloPlayer.white;
    _board[mid - 1][mid] = OthelloPlayer.black;
    _board[mid][mid - 1] = OthelloPlayer.black;
    _board[mid][mid] = OthelloPlayer.white;
  }

  void restart() {
    _board = List.generate(size, (_) => List.filled(size, null));
    current = OthelloPlayer.black;
    state = const OthelloPlaying();
    blackCount = 2;
    whiteCount = 2;
    _setupInitial();
  }

  bool play(int row, int col) {
    if (state is! OthelloPlaying) return false;
    if (_board[row][col] != null) return false;

    final flips = _getFlips(row, col, current);
    if (flips.isEmpty) return false;

    _board[row][col] = current;
    for (final pos in flips) {
      _board[pos[0]][pos[1]] = current;
    }

    _updateCounts();
    _advance();
    return true;
  }

  List<List<int>> getValidMoves() {
    final moves = <List<int>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == null && _getFlips(r, c, current).isNotEmpty) {
          moves.add([r, c]);
        }
      }
    }
    return moves;
  }

  void _advance() {
    final opponent =
        current == OthelloPlayer.black ? OthelloPlayer.white : OthelloPlayer.black;

    // Check if opponent has moves
    if (_hasValidMoves(opponent)) {
      current = opponent;
      return;
    }

    // Opponent has no moves; check if current still has moves
    if (_hasValidMoves(current)) {
      // current keeps turn (opponent passes)
      return;
    }

    // Neither has moves — game over
    if (blackCount > whiteCount) {
      state = const OthelloWin(OthelloPlayer.black);
    } else if (whiteCount > blackCount) {
      state = const OthelloWin(OthelloPlayer.white);
    } else {
      state = const OthelloDraw();
    }
  }

  bool _hasValidMoves(OthelloPlayer player) {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == null && _getFlips(r, c, player).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  void _updateCounts() {
    int b = 0, w = 0;
    for (final row in _board) {
      for (final cell in row) {
        if (cell == OthelloPlayer.black) b++;
        if (cell == OthelloPlayer.white) w++;
      }
    }
    blackCount = b;
    whiteCount = w;
  }

  List<List<int>> _getFlips(int r, int c, OthelloPlayer player) {
    final opponent =
        player == OthelloPlayer.black ? OthelloPlayer.white : OthelloPlayer.black;
    final flips = <List<int>>[];

    const dirs = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1],           [0, 1],
      [1, -1],  [1, 0],  [1, 1],
    ];

    for (final dir in dirs) {
      final line = <List<int>>[];
      int i = r + dir[0];
      int j = c + dir[1];
      while (i >= 0 && j >= 0 && i < size && j < size && _board[i][j] == opponent) {
        line.add([i, j]);
        i += dir[0];
        j += dir[1];
      }
      if (line.isNotEmpty &&
          i >= 0 &&
          j >= 0 &&
          i < size &&
          j < size &&
          _board[i][j] == player) {
        flips.addAll(line);
      }
    }
    return flips;
  }
}
