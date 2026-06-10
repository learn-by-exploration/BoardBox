import 'dart:collection';

import 'package:common_games/models/json_helpers.dart';

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

  Map<String, dynamic> toJson() => {
    'board': _board.map((row) => row.map((c) => c?.index).toList()).toList(),
    'current': current.index,
    'state': _stateToJson(state),
    'blackCount': blackCount,
    'whiteCount': whiteCount,
  };

  static Map<String, dynamic> _stateToJson(OthelloState s) {
    if (s is OthelloWin) return {'type': 'win', 'winner': s.winner.index};
    if (s is OthelloDraw) return {'type': 'draw'};
    return {'type': 'playing'};
  }

  static OthelloModel fromJson(Map<String, dynamic> json) {
    final model = OthelloModel();
    // Clear the initial setup
    for (int r = 0; r < OthelloModel.size; r++) {
      for (int c = 0; c < OthelloModel.size; c++) {
        model._board[r][c] = null;
      }
    }
    final board = readBoard<int>(
      json,
      'board',
      expectedOuter: OthelloModel.size,
      expectedInner: OthelloModel.size,
      isValidCell: (raw) =>
          raw is int && raw >= 0 && raw < OthelloPlayer.values.length,
    );
    for (int r = 0; r < OthelloModel.size; r++) {
      for (int c = 0; c < OthelloModel.size; c++) {
        model._board[r][c] = board[r][c] == null
            ? null
            : OthelloPlayer.values[board[r][c]!];
      }
    }
    model.current = readEnumByIndex<OthelloPlayer>(
      OthelloPlayer.values,
      json,
      'current',
      enumName: 'OthelloPlayer',
    );
    model.state = _stateFromJson(json['state'] as Map<String, dynamic>);
    model.blackCount = json['blackCount'] as int;
    model.whiteCount = json['whiteCount'] as int;
    return model;
  }

  static OthelloState _stateFromJson(Map<String, dynamic> s) {
    return readStateType<OthelloState>(
      stateJson: s,
      cases: {
        'win': (j) => OthelloWin(
          readEnumByIndex<OthelloPlayer>(
            OthelloPlayer.values,
            j,
            'winner',
            enumName: 'OthelloPlayer',
          ),
        ),
        'draw': (_) => const OthelloDraw(),
        'playing': (_) => const OthelloPlaying(),
      },
    );
  }

  bool play(int row, int col) {
    if (state is! OthelloPlaying) return false;
    if (row < 0 || row >= size || col < 0 || col >= size) return false;
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

  /// Ensures the current player has at least one valid move, and declares a
  /// winner if neither player can move. Call after state restoration and
  /// after any non-mutating transition that may have left `current` with no
  /// moves (e.g., the human's last move in a position where only the opponent
  /// can flip, after which the opponent's turn is set, etc.).
  void ensureValidTurn() {
    if (state is! OthelloPlaying) return;
    if (_hasValidMoves(current)) return;
    final opponent = current == OthelloPlayer.black
        ? OthelloPlayer.white
        : OthelloPlayer.black;
    if (_hasValidMoves(opponent)) {
      current = opponent;
      return;
    }
    _declareFinalResult();
  }

  void _declareFinalResult() {
    if (blackCount > whiteCount) {
      state = const OthelloWin(OthelloPlayer.black);
    } else if (whiteCount > blackCount) {
      state = const OthelloWin(OthelloPlayer.white);
    } else {
      state = const OthelloDraw();
    }
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
    final opponent = current == OthelloPlayer.black
        ? OthelloPlayer.white
        : OthelloPlayer.black;

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
    _declareFinalResult();
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
    final opponent = player == OthelloPlayer.black
        ? OthelloPlayer.white
        : OthelloPlayer.black;
    final flips = <List<int>>[];

    const dirs = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];

    for (final dir in dirs) {
      final line = <List<int>>[];
      int i = r + dir[0];
      int j = c + dir[1];
      while (i >= 0 &&
          j >= 0 &&
          i < size &&
          j < size &&
          _board[i][j] == opponent) {
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
