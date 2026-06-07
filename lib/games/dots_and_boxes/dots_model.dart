import 'dart:collection';

/// Pure Dart game logic for Dots and Boxes.
enum DotsPlayer { player1, player2 }

sealed class DotsState {
  const DotsState();
}

final class DotsPlaying extends DotsState {
  const DotsPlaying();
}

final class DotsWin extends DotsState {
  const DotsWin(this.winner);
  final DotsPlayer winner;
}

final class DotsDraw extends DotsState {
  const DotsDraw();
}

class DotsModel {
  final int gridSize;

  int get dotRows => gridSize;
  int get dotCols => gridSize;
  int get boxRows => gridSize - 1;
  int get boxCols => gridSize - 1;

  /// hLines[row][col] = player who drew the line, or null if undrawn.
  late List<List<DotsPlayer?>> _hLines;

  /// vLines[row][col] = player who drew the line, or null if undrawn.
  late List<List<DotsPlayer?>> _vLines;

  /// boxes[row][col] = player who captured it, or null.
  late List<List<DotsPlayer?>> _boxes;

  DotsPlayer current;
  DotsState state;
  int score1;
  int score2;

  DotsModel({this.gridSize = 5})
    : assert(gridSize >= 2),
      current = DotsPlayer.player1,
      state = const DotsPlaying(),
      score1 = 0,
      score2 = 0 {
    _hLines = List.generate(dotRows, (_) => List.filled(dotCols - 1, null));
    _vLines = List.generate(dotRows - 1, (_) => List.filled(dotCols, null));
    _boxes = List.generate(boxRows, (_) => List.filled(boxCols, null));
  }

  List<UnmodifiableListView<DotsPlayer?>> get hLines =>
      _hLines.map(UnmodifiableListView<DotsPlayer?>.new).toList();

  List<UnmodifiableListView<DotsPlayer?>> get vLines =>
      _vLines.map(UnmodifiableListView<DotsPlayer?>.new).toList();

  List<UnmodifiableListView<DotsPlayer?>> get boxes =>
      _boxes.map(UnmodifiableListView<DotsPlayer?>.new).toList();

  void restart() {
    _hLines = List.generate(dotRows, (_) => List.filled(dotCols - 1, null));
    _vLines = List.generate(dotRows - 1, (_) => List.filled(dotCols, null));
    _boxes = List.generate(boxRows, (_) => List.filled(boxCols, null));
    current = DotsPlayer.player1;
    state = const DotsPlaying();
    score1 = 0;
    score2 = 0;
  }

  Map<String, dynamic> toJson() => {
    'gridSize': gridSize,
    'hLines': _hLines.map((row) => row.map((c) => c?.index).toList()).toList(),
    'vLines': _vLines.map((row) => row.map((c) => c?.index).toList()).toList(),
    'boxes': _boxes.map((row) => row.map((c) => c?.index).toList()).toList(),
    'current': current.index,
    'state': _stateToJson(state),
    'score1': score1,
    'score2': score2,
  };

  static Map<String, dynamic> _stateToJson(DotsState s) {
    if (s is DotsWin) return {'type': 'win', 'winner': s.winner.index};
    if (s is DotsDraw) return {'type': 'draw'};
    return {'type': 'playing'};
  }

  static DotsModel fromJson(Map<String, dynamic> json) {
    final gridSize =
        json['gridSize'] as int? ?? (json['hLines'] as List).length;
    final model = DotsModel(gridSize: gridSize);
    final hLines = json['hLines'] as List;
    for (int r = 0; r < model.dotRows; r++) {
      final row = hLines[r] as List;
      for (int c = 0; c < model.dotCols - 1; c++) {
        model._hLines[r][c] = row[c] == null
            ? null
            : DotsPlayer.values[row[c] as int];
      }
    }
    final vLines = json['vLines'] as List;
    for (int r = 0; r < model.dotRows - 1; r++) {
      final row = vLines[r] as List;
      for (int c = 0; c < model.dotCols; c++) {
        model._vLines[r][c] = row[c] == null
            ? null
            : DotsPlayer.values[row[c] as int];
      }
    }
    final boxes = json['boxes'] as List;
    for (int r = 0; r < model.boxRows; r++) {
      final row = boxes[r] as List;
      for (int c = 0; c < model.boxCols; c++) {
        model._boxes[r][c] = row[c] == null
            ? null
            : DotsPlayer.values[row[c] as int];
      }
    }
    model.current = DotsPlayer.values[json['current'] as int];
    model.state = _stateFromJson(json['state'] as Map<String, dynamic>);
    model.score1 = json['score1'] as int;
    model.score2 = json['score2'] as int;
    return model;
  }

  static DotsState _stateFromJson(Map<String, dynamic> s) {
    switch (s['type'] as String) {
      case 'win':
        return DotsWin(DotsPlayer.values[s['winner'] as int]);
      case 'draw':
        return const DotsDraw();
      default:
        return const DotsPlaying();
    }
  }

  /// Draw a horizontal line between (row, col) and (row, col+1).
  bool drawHLine(int row, int col) {
    if (state is! DotsPlaying) return false;
    if (row < 0 || row >= dotRows || col < 0 || col >= dotCols - 1) {
      return false;
    }
    if (_hLines[row][col] != null) return false;

    _hLines[row][col] = current;
    final captured = _captureBoxes(row, col, true);
    if (!captured) _switchPlayer();
    _checkGameOver();
    return true;
  }

  /// Draw a vertical line between (row, col) and (row+1, col).
  bool drawVLine(int row, int col) {
    if (state is! DotsPlaying) return false;
    if (row < 0 || row >= dotRows - 1 || col < 0 || col >= dotCols) {
      return false;
    }
    if (_vLines[row][col] != null) return false;

    _vLines[row][col] = current;
    final captured = _captureBoxes(row, col, false);
    if (!captured) _switchPlayer();
    _checkGameOver();
    return true;
  }

  bool _captureBoxes(int row, int col, bool horizontal) {
    bool captured = false;
    if (horizontal) {
      if (row > 0 && _isBoxComplete(row - 1, col)) {
        _boxes[row - 1][col] = current;
        _addScore();
        captured = true;
      }
      if (row < boxRows && _isBoxComplete(row, col)) {
        _boxes[row][col] = current;
        _addScore();
        captured = true;
      }
    } else {
      if (col > 0 && _isBoxComplete(row, col - 1)) {
        _boxes[row][col - 1] = current;
        _addScore();
        captured = true;
      }
      if (col < boxCols && _isBoxComplete(row, col)) {
        _boxes[row][col] = current;
        _addScore();
        captured = true;
      }
    }
    return captured;
  }

  bool _isBoxComplete(int r, int c) {
    if (_boxes[r][c] != null) return false;
    return _hLines[r][c] != null &&
        _hLines[r + 1][c] != null &&
        _vLines[r][c] != null &&
        _vLines[r][c + 1] != null;
  }

  void _addScore() {
    if (current == DotsPlayer.player1) {
      score1++;
    } else {
      score2++;
    }
  }

  void _switchPlayer() {
    current = current == DotsPlayer.player1
        ? DotsPlayer.player2
        : DotsPlayer.player1;
  }

  void _checkGameOver() {
    final totalBoxes = boxRows * boxCols;
    if (score1 + score2 == totalBoxes) {
      if (score1 > score2) {
        state = const DotsWin(DotsPlayer.player1);
      } else if (score2 > score1) {
        state = const DotsWin(DotsPlayer.player2);
      } else {
        state = const DotsDraw();
      }
    }
  }
}
