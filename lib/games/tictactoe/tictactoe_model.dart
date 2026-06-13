import 'dart:collection';
import 'dart:math' as math;

import 'package:common_games/models/json_helpers.dart';

enum TicTacToePlayer { x, o }

sealed class TicTacToeState {
  const TicTacToeState();
}

final class TicTacToePlaying extends TicTacToeState {
  const TicTacToePlaying();
}

final class TicTacToeWin extends TicTacToeState {
  const TicTacToeWin(this.winner);
  final TicTacToePlayer winner;
}

final class TicTacToeDraw extends TicTacToeState {
  const TicTacToeDraw();
}

class TicTacToeModel {
  /// Win length for a given board size:
  /// 3×3 and 4×4 → 3-in-a-row, 5×5 → 4-in-a-row.
  static int winLengthFor(int size) => size < 5 ? 3 : 4;

  final int size;
  final int winLength;

  List<List<TicTacToePlayer?>> _board;
  TicTacToePlayer current;
  TicTacToeState state;
  int? lastRow;
  int? lastCol;

  TicTacToeModel({required this.size})
    : winLength = winLengthFor(size),
      _board = List.generate(size, (_) => List.filled(size, null)),
      current = TicTacToePlayer.x,
      state = const TicTacToePlaying();

  List<UnmodifiableListView<TicTacToePlayer?>> get board =>
      _board.map(UnmodifiableListView<TicTacToePlayer?>.new).toList();

  /// Internal scratch accessor for the AI harness, which mutates cells
  /// and reverts them to reason about hypothetical moves. Do not call
  /// from UI code — use the read-only [board] getter instead.
  List<List<TicTacToePlayer?>> get scratchBoard => _board;

  List<(int, int)> get emptyCells {
    final cells = <(int, int)>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == null) cells.add((r, c));
      }
    }
    return cells;
  }

  void restart() {
    _board = List.generate(size, (_) => List.filled(size, null));
    current = TicTacToePlayer.x;
    state = const TicTacToePlaying();
    lastRow = null;
    lastCol = null;
  }

  bool play(int row, int col) {
    if (state is! TicTacToePlaying) return false;
    if (row < 0 || row >= size || col < 0 || col >= size) return false;
    if (_board[row][col] != null) return false;

    _board[row][col] = current;
    lastRow = row;
    lastCol = col;

    if (_checkWin(row, col, current)) {
      state = TicTacToeWin(current);
    } else if (emptyCells.isEmpty) {
      state = const TicTacToeDraw();
    } else {
      current = current == TicTacToePlayer.x
          ? TicTacToePlayer.o
          : TicTacToePlayer.x;
    }
    return true;
  }

  /// Returns true if [player] would have a winning line at ([row], [col])
  /// *if* a piece of theirs were placed there. Does not mutate the board —
  /// safe for AI move enumeration that probes many cells in a row.
  bool wouldWinAt(int row, int col, TicTacToePlayer player) {
    if (row < 0 || row >= size || col < 0 || col >= size) return false;
    return _lineAt(row, col, player);
  }

  bool _checkWin(int row, int col, TicTacToePlayer player) =>
      _lineAt(row, col, player);

  /// Scan the four directions through ([row], [col]) for [player] pieces.
  /// Returns true if any direction has [winLength] or more pieces.
  bool _lineAt(int row, int col, TicTacToePlayer player) {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (final d in dirs) {
      int count = 1;
      int r = row + d.$1, c = col + d.$2;
      while (r >= 0 &&
          c >= 0 &&
          r < size &&
          c < size &&
          _board[r][c] == player) {
        count++;
        r += d.$1;
        c += d.$2;
      }
      r = row - d.$1;
      c = col - d.$2;
      while (r >= 0 &&
          c >= 0 &&
          r < size &&
          c < size &&
          _board[r][c] == player) {
        count++;
        r -= d.$1;
        c -= d.$2;
      }
      if (count >= winLength) return true;
    }
    return false;
  }

  /// Heuristic evaluation: positive = good for [forPlayer].
  /// Line-scan: each unblocked line scores 10^(pieces_in_line).
  int evaluate(TicTacToePlayer forPlayer) {
    final s = state;
    if (s is TicTacToeWin) {
      return s.winner == forPlayer ? 1000000 : -1000000;
    }
    if (s is TicTacToeDraw) return 0;

    final opponent = forPlayer == TicTacToePlayer.x
        ? TicTacToePlayer.o
        : TicTacToePlayer.x;
    int score = 0;

    for (final line in _allLinesOfWinLength()) {
      int mine = 0, theirs = 0;
      for (final cell in line) {
        final v = _board[cell.$1][cell.$2];
        if (v == forPlayer) {
          mine++;
        } else if (v == opponent) {
          theirs++;
        }
      }
      if (mine > 0 && theirs == 0) score += math.pow(10, mine).toInt();
      if (theirs > 0 && mine == 0) score -= math.pow(10, theirs).toInt();
    }
    return score;
  }

  List<List<(int, int)>> _allLinesOfWinLength() {
    final lines = <List<(int, int)>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c <= size - winLength; c++) {
        lines.add(List.generate(winLength, (i) => (r, c + i)));
      }
    }
    for (int c = 0; c < size; c++) {
      for (int r = 0; r <= size - winLength; r++) {
        lines.add(List.generate(winLength, (i) => (r + i, c)));
      }
    }
    for (int r = 0; r <= size - winLength; r++) {
      for (int c = 0; c <= size - winLength; c++) {
        lines.add(List.generate(winLength, (i) => (r + i, c + i)));
      }
    }
    for (int r = 0; r <= size - winLength; r++) {
      for (int c = winLength - 1; c < size; c++) {
        lines.add(List.generate(winLength, (i) => (r + i, c - i)));
      }
    }
    return lines;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'size': size,
    'board': _board.map((row) => row.map((c) => c?.index).toList()).toList(),
    'current': current.index,
    'state': _stateToJson(state),
    'lastRow': lastRow,
    'lastCol': lastCol,
  };

  static Map<String, dynamic> _stateToJson(TicTacToeState s) {
    if (s is TicTacToeWin) return {'type': 'win', 'winner': s.winner.index};
    if (s is TicTacToeDraw) return {'type': 'draw'};
    return {'type': 'playing'};
  }

  static TicTacToeModel fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int;
    final model = TicTacToeModel(size: size);
    final board = readBoard<int>(
      json,
      'board',
      expectedOuter: size,
      expectedInner: size,
      isValidCell: (raw) =>
          raw is int && raw >= 0 && raw < TicTacToePlayer.values.length,
    );
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        model._board[r][c] = board[r][c] == null
            ? null
            : TicTacToePlayer.values[board[r][c]!];
      }
    }
    model.current = readEnumByIndex<TicTacToePlayer>(
      TicTacToePlayer.values,
      json,
      'current',
      enumName: 'TicTacToePlayer',
    );
    model.state = _stateFromJson(json['state'] as Map<String, dynamic>);
    model.lastRow = json['lastRow'] as int?;
    model.lastCol = json['lastCol'] as int?;
    return model;
  }

  static TicTacToeState _stateFromJson(Map<String, dynamic> s) {
    return readStateType<TicTacToeState>(
      stateJson: s,
      cases: {
        'win': (j) => TicTacToeWin(
          readEnumByIndex<TicTacToePlayer>(
            TicTacToePlayer.values,
            j,
            'winner',
            enumName: 'TicTacToePlayer',
          ),
        ),
        'draw': (_) => const TicTacToeDraw(),
        'playing': (_) => const TicTacToePlaying(),
      },
    );
  }
}
