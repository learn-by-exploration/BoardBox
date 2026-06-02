import 'dart:collection';

/// Pure Dart game logic for Gomoku (Five in a Row).
/// No Flutter imports — fully testable.
/// Reference: https://github.com/nickoala/five-in-a-row (board logic pattern)
enum GomokuPlayer { black, white }

sealed class GomokuState {
  const GomokuState();
}

final class GomokuPlaying extends GomokuState {
  const GomokuPlaying();
}

final class GomokuWin extends GomokuState {
  const GomokuWin(this.winner);
  final GomokuPlayer winner;
}

final class GomokuDraw extends GomokuState {
  const GomokuDraw();
}

class GomokuModel {
  static const int size = 15;

  List<List<GomokuPlayer?>> _board;
  GomokuPlayer current;
  GomokuState state;

  GomokuModel()
    : _board = List.generate(size, (_) => List.filled(size, null)),
      current = GomokuPlayer.black,
      state = const GomokuPlaying();

  /// Read-only view of the board.
  List<UnmodifiableListView<GomokuPlayer?>> get board =>
      _board.map(UnmodifiableListView<GomokuPlayer?>.new).toList();

  void restart() {
    _board = List.generate(size, (_) => List.filled(size, null));
    current = GomokuPlayer.black;
    state = const GomokuPlaying();
  }

  Map<String, dynamic> toJson() => {
    'board': _board.map((row) => row.map((c) => c?.index).toList()).toList(),
    'current': current.index,
    'state': _stateToJson(state),
  };

  static Map<String, dynamic> _stateToJson(GomokuState s) {
    if (s is GomokuWin) return {'type': 'win', 'winner': s.winner.index};
    if (s is GomokuDraw) return {'type': 'draw'};
    return {'type': 'playing'};
  }

  static GomokuModel fromJson(Map<String, dynamic> json) {
    final model = GomokuModel();
    final board = json['board'] as List;
    for (int r = 0; r < GomokuModel.size; r++) {
      final row = board[r] as List;
      for (int c = 0; c < GomokuModel.size; c++) {
        model._board[r][c] = row[c] == null
            ? null
            : GomokuPlayer.values[row[c] as int];
      }
    }
    model.current = GomokuPlayer.values[json['current'] as int];
    model.state = _stateFromJson(json['state'] as Map<String, dynamic>);
    return model;
  }

  static GomokuState _stateFromJson(Map<String, dynamic> s) {
    switch (s['type'] as String) {
      case 'win':
        return GomokuWin(GomokuPlayer.values[s['winner'] as int]);
      case 'draw':
        return const GomokuDraw();
      default:
        return const GomokuPlaying();
    }
  }

  bool play(int row, int col) {
    if (state is! GomokuPlaying) return false;
    if (row < 0 || row >= size || col < 0 || col >= size) return false;
    if (_board[row][col] != null) return false;

    _board[row][col] = current;

    if (_hasFive(row, col, current)) {
      state = GomokuWin(current);
    } else if (_isBoardFull()) {
      state = const GomokuDraw();
    } else {
      current = current == GomokuPlayer.black
          ? GomokuPlayer.white
          : GomokuPlayer.black;
    }
    return true;
  }

  bool _isBoardFull() {
    for (final row in _board) {
      for (final cell in row) {
        if (cell == null) return false;
      }
    }
    return true;
  }

  bool _hasFive(int r, int c, GomokuPlayer player) {
    const dirs = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ];

    for (final dir in dirs) {
      int count = 1;
      count += _countDir(r, c, dir[0], dir[1], player);
      count += _countDir(r, c, -dir[0], -dir[1], player);
      if (count >= 5) return true;
    }
    return false;
  }

  int _countDir(int r, int c, int dr, int dc, GomokuPlayer player) {
    int i = r + dr;
    int j = c + dc;
    int count = 0;
    while (i >= 0 && j >= 0 && i < size && j < size && _board[i][j] == player) {
      count++;
      i += dr;
      j += dc;
    }
    return count;
  }
}
