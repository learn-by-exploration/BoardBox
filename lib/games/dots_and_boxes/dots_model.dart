import 'dart:collection';

/// Pure Dart game logic for Dots and Boxes.
/// 5×5 dot grid (4×4 boxes).
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
  static const int dotRows = 5;
  static const int dotCols = 5;
  static const int boxRows = dotRows - 1;
  static const int boxCols = dotCols - 1;

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

  DotsModel()
      : current = DotsPlayer.player1,
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

  /// Draw a horizontal line between (row, col) and (row, col+1).
  bool drawHLine(int row, int col) {
    if (state is! DotsPlaying) return false;
    if (row < 0 || row >= dotRows || col < 0 || col >= dotCols - 1) return false;
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
    if (row < 0 || row >= dotRows - 1 || col < 0 || col >= dotCols) return false;
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
    current =
        current == DotsPlayer.player1 ? DotsPlayer.player2 : DotsPlayer.player1;
  }

  void _checkGameOver() {
    const totalBoxes = boxRows * boxCols;
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
