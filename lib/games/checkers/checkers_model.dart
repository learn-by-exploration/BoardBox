import 'dart:collection';

import 'package:common_games/models/json_helpers.dart';

/// Pure Dart game logic for Checkers (English Draughts).
/// Reference: https://github.com/nicholasgasior/flutter-checkers (game logic)
/// Rules: 8×8 board, mandatory captures, multi-jump chains, king promotion.
enum CheckersPlayer { red, black }

sealed class CheckersState {
  const CheckersState();
}

final class CheckersPlaying extends CheckersState {
  const CheckersPlaying();
}

final class CheckersWin extends CheckersState {
  const CheckersWin(this.winner);
  final CheckersPlayer winner;
}

/// Piece type: lowercase = normal, uppercase = king.
/// 'r' = red man, 'R' = red king, 'b' = black man, 'B' = black king.
class CheckersModel {
  static const int size = 8;

  List<List<String?>> _board;
  CheckersPlayer current;
  CheckersState state;
  int? selectedRow;
  int? selectedCol;
  List<List<int>> _highlightedMoves;
  bool _midJump;

  CheckersModel()
    : _board = List.generate(size, (_) => List.filled(size, null)),
      current = CheckersPlayer.red,
      state = const CheckersPlaying(),
      _highlightedMoves = [],
      _midJump = false {
    _setupInitial();
  }

  /// Read-only view of the board.
  List<UnmodifiableListView<String?>> get board =>
      _board.map(UnmodifiableListView<String?>.new).toList();

  /// Read-only view of highlighted moves.
  List<List<int>> get highlightedMoves => List.unmodifiable(_highlightedMoves);

  void _setupInitial() {
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < size; c++) {
        if ((r + c) % 2 == 1) _board[r][c] = 'b';
      }
    }
    for (int r = 5; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if ((r + c) % 2 == 1) _board[r][c] = 'r';
      }
    }
  }

  void restart() {
    _board = List.generate(size, (_) => List.filled(size, null));
    current = CheckersPlayer.red;
    state = const CheckersPlaying();
    selectedRow = null;
    selectedCol = null;
    _highlightedMoves = [];
    _midJump = false;
    _setupInitial();
  }

  Map<String, dynamic> toJson() => {
    'board': _board.map((row) => row.toList()).toList(),
    'current': current.index,
    'state': _stateToJson(state),
    'selectedRow': selectedRow,
    'selectedCol': selectedCol,
    'highlightedMoves': _highlightedMoves,
    'midJump': _midJump,
  };

  static Map<String, dynamic> _stateToJson(CheckersState s) {
    if (s is CheckersWin) return {'type': 'win', 'winner': s.winner.index};
    return {'type': 'playing'};
  }

  static CheckersModel fromJson(Map<String, dynamic> json) {
    final model = CheckersModel();
    final board = readBoard<String>(
      json,
      'board',
      expectedOuter: CheckersModel.size,
      expectedInner: CheckersModel.size,
      isValidCell: (raw) =>
          raw == 'r' || raw == 'R' || raw == 'b' || raw == 'B',
    );
    for (int r = 0; r < CheckersModel.size; r++) {
      for (int c = 0; c < CheckersModel.size; c++) {
        model._board[r][c] = board[r][c];
      }
    }
    model.current = readEnumByIndex<CheckersPlayer>(
      CheckersPlayer.values,
      json,
      'current',
      enumName: 'CheckersPlayer',
    );
    model.state = _stateFromJson(json['state'] as Map<String, dynamic>);
    model.selectedRow = json['selectedRow'] as int?;
    model.selectedCol = json['selectedCol'] as int?;
    model._highlightedMoves = (json['highlightedMoves'] as List)
        .map((m) => List<int>.from(m as List))
        .toList();
    model._midJump = json['midJump'] as bool;
    return model;
  }

  static CheckersState _stateFromJson(Map<String, dynamic> s) {
    return readStateType<CheckersState>(
      stateJson: s,
      cases: {
        'win': (j) => CheckersWin(
          readEnumByIndex<CheckersPlayer>(
            CheckersPlayer.values,
            j,
            'winner',
            enumName: 'CheckersPlayer',
          ),
        ),
        'playing': (_) => const CheckersPlaying(),
      },
    );
  }

  /// Returns true if tap was handled.
  bool tap(int row, int col) {
    if (state is! CheckersPlaying) return false;
    if (row < 0 || row >= size || col < 0 || col >= size) return false;

    // If mid-jump, only allow continuation
    if (_midJump) {
      if (_highlightedMoves.any((m) => m[0] == row && m[1] == col)) {
        _executeMove(selectedRow!, selectedCol!, row, col);
        return true;
      }
      return false;
    }

    // Tap on own piece → select it
    if (_isOwnPiece(row, col)) {
      final filteredMoves = enumerateMovesFor(row, col);
      if (filteredMoves.isEmpty) return false;
      selectedRow = row;
      selectedCol = col;
      _highlightedMoves = List.of(filteredMoves);
      return true;
    }

    // Tap on highlighted move → execute
    if (selectedRow != null &&
        _highlightedMoves.any((m) => m[0] == row && m[1] == col)) {
      _executeMove(selectedRow!, selectedCol!, row, col);
      return true;
    }

    return false;
  }

  void _executeMove(int fromR, int fromC, int toR, int toC) {
    final piece = _board[fromR][fromC]!;
    _board[fromR][fromC] = null;
    _board[toR][toC] = piece;

    // Capture?
    final isCapture = (toR - fromR).abs() == 2;
    if (isCapture) {
      final midR = (fromR + toR) ~/ 2;
      final midC = (fromC + toC) ~/ 2;
      _board[midR][midC] = null;
    }

    // Promote to king. Per English Draughts rules, promotion ends the turn
    // immediately — even if further captures would be available as a king.
    _promoteIfNeeded(toR, toC);
    final wasPromoted = _board[toR][toC] != piece;

    // Multi-jump continues only when: a capture occurred AND no promotion.
    if (isCapture && !wasPromoted) {
      final furtherCaptures = _getCapturesForPiece(toR, toC);
      if (furtherCaptures.isNotEmpty) {
        selectedRow = toR;
        selectedCol = toC;
        _highlightedMoves = furtherCaptures;
        _midJump = true;
        // A multi-jump chain can wipe out the opponent's last pieces. Check
        // now so the UI shows the correct winner as soon as the chain ends.
        _checkCaptureVictory();
        return;
      }
    }

    _endTurn();
  }

  /// Called during a multi-jump chain: if the opponent has no pieces left,
  /// declare the active player the winner immediately.
  void _checkCaptureVictory() {
    final opponent = current == CheckersPlayer.red
        ? CheckersPlayer.black
        : CheckersPlayer.red;
    if (!_playerHasPieces(opponent)) {
      state = CheckersWin(current);
      selectedRow = null;
      selectedCol = null;
      _highlightedMoves = [];
      _midJump = false;
    }
  }

  void _promoteIfNeeded(int r, int c) {
    final piece = _board[r][c];
    if (piece == 'r' && r == 0) _board[r][c] = 'R';
    if (piece == 'b' && r == size - 1) _board[r][c] = 'B';
  }

  void _endTurn() {
    selectedRow = null;
    selectedCol = null;
    _highlightedMoves = [];
    _midJump = false;
    current = current == CheckersPlayer.red
        ? CheckersPlayer.black
        : CheckersPlayer.red;

    // Check win condition — the current player (just switched) loses if
    // they have no pieces or no moves.
    if (!_playerHasPieces(current) || !_playerHasMoves(current)) {
      final winner = current == CheckersPlayer.red
          ? CheckersPlayer.black
          : CheckersPlayer.red;
      state = CheckersWin(winner);
    }
  }

  /// Clears the current selection without executing a move.
  /// No-op when mid-jump (cancelling a jump chain is illegal).
  void deselect() {
    if (_midJump) return;
    selectedRow = null;
    selectedCol = null;
    _highlightedMoves = [];
  }

  /// Returns the legal moves for the piece at ([row], [col]) under the
  /// current rules, **without mutating** [selectedRow], [selectedCol], or
  /// [highlightedMoves]. Filters to captures only when a capture is
  /// mandatory. Safe for AI move enumeration that probes many pieces.
  List<List<int>> enumerateMovesFor(int row, int col) {
    if (!_isOwnPiece(row, col)) return const [];
    final mustCapture = _mustCaptureExists();
    final moves = _getMovesForPiece(row, col);
    final filtered = mustCapture
        ? moves.where((m) => (m[0] - row).abs() == 2).toList()
        : moves;
    return List.unmodifiable(filtered);
  }

  /// True when the current player has at least one capture available.
  /// Public so the AI harness can stop duplicating the must-capture check.
  bool get mustCapture => _mustCaptureExists();

  bool _isOwnPiece(int r, int c) {
    final piece = _board[r][c];
    if (piece == null) return false;
    if (current == CheckersPlayer.red) return piece == 'r' || piece == 'R';
    return piece == 'b' || piece == 'B';
  }

  bool _mustCaptureExists() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_isOwnPiece(r, c) && _getCapturesForPiece(r, c).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  List<List<int>> _getMovesForPiece(int r, int c) {
    final piece = _board[r][c];
    if (piece == null) return [];
    final isKing = piece == 'R' || piece == 'B';
    final directions = <List<int>>[];

    if (isKing) {
      directions.addAll([
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
      ]);
    } else if (piece == 'r') {
      directions.addAll([
        [-1, -1],
        [-1, 1],
      ]);
    } else {
      directions.addAll([
        [1, -1],
        [1, 1],
      ]);
    }

    final moves = <List<int>>[];

    for (final d in directions) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (nr < 0 || nc < 0 || nr >= size || nc >= size) continue;

      if (_board[nr][nc] == null) {
        moves.add([nr, nc]);
      } else if (_isOpponent(nr, nc)) {
        // Check jump
        final jr = nr + d[0];
        final jc = nc + d[1];
        if (jr >= 0 &&
            jc >= 0 &&
            jr < size &&
            jc < size &&
            _board[jr][jc] == null) {
          moves.add([jr, jc]);
        }
      }
    }
    return moves;
  }

  List<List<int>> _getCapturesForPiece(int r, int c) {
    final piece = _board[r][c];
    if (piece == null) return [];
    final isKing = piece == 'R' || piece == 'B';
    final directions = <List<int>>[];

    if (isKing) {
      directions.addAll([
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
      ]);
    } else if (piece == 'r') {
      directions.addAll([
        [-1, -1],
        [-1, 1],
      ]);
    } else {
      directions.addAll([
        [1, -1],
        [1, 1],
      ]);
    }

    final captures = <List<int>>[];

    for (final d in directions) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (nr < 0 || nc < 0 || nr >= size || nc >= size) continue;
      if (_isOpponent(nr, nc)) {
        final jr = nr + d[0];
        final jc = nc + d[1];
        if (jr >= 0 &&
            jc >= 0 &&
            jr < size &&
            jc < size &&
            _board[jr][jc] == null) {
          captures.add([jr, jc]);
        }
      }
    }
    return captures;
  }

  bool _isOpponent(int r, int c) {
    final piece = _board[r][c];
    if (piece == null) return false;
    if (current == CheckersPlayer.red) return piece == 'b' || piece == 'B';
    return piece == 'r' || piece == 'R';
  }

  bool _playerHasPieces(CheckersPlayer player) {
    for (final row in _board) {
      for (final cell in row) {
        if (cell == null) continue;
        if (player == CheckersPlayer.red && (cell == 'r' || cell == 'R')) {
          return true;
        }
        if (player == CheckersPlayer.black && (cell == 'b' || cell == 'B')) {
          return true;
        }
      }
    }
    return false;
  }

  bool _playerHasMoves(CheckersPlayer player) {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == null) continue;
        final piece = _board[r][c]!;
        final isOwn = player == CheckersPlayer.red
            ? (piece == 'r' || piece == 'R')
            : (piece == 'b' || piece == 'B');
        if (isOwn && _getMovesForPiece(r, c).isNotEmpty) return true;
      }
    }
    return false;
  }
}
