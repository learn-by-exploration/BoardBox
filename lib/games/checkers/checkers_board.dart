import 'dart:math';

import 'package:flutter/material.dart';

import 'package:common_games/games/checkers/checkers_model.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/widgets/game_status_bar.dart';

class CheckersBoard extends StatefulWidget {
  const CheckersBoard({
    super.key,
    required this.mode,
    this.difficulty = AiDifficulty.medium,
    this.onGameOver,
    this.undoNotifier,
    this.stateNotifier,
    this.initialState,
  });

  final GameMode mode;
  final AiDifficulty difficulty;
  final void Function(String result)? onGameOver;
  final ValueNotifier<VoidCallback?>? undoNotifier;
  final ValueNotifier<Map<String, dynamic>?>? stateNotifier;
  final Map<String, dynamic>? initialState;

  @override
  State<CheckersBoard> createState() => _CheckersBoardState();
}

class _CheckersBoardState extends State<CheckersBoard> {
  late CheckersModel _game;
  final Random _rng = Random();
  bool _aiThinking = false;

  String? get _overrideMessage {
    if (_aiThinking) return 'Computer thinking…';
    return switch (_game.state) {
      CheckersPlaying() => null,
      CheckersWin(:final winner) =>
        '${winner == CheckersPlayer.red ? "Red" : "Black"} wins!',
    };
  }

  bool get _isAiTurn =>
      widget.mode == GameMode.singlePlayer &&
      _game.current == CheckersPlayer.black &&
      _game.state is CheckersPlaying;

  void _pushStateNotifier() {
    widget.stateNotifier?.value = _game.toJson();
  }

  @override
  void initState() {
    super.initState();
    _game = widget.initialState != null
        ? CheckersModel.fromJson(widget.initialState!)
        : CheckersModel();
  }

  void _onTap(int row, int col) {
    if (_aiThinking) return;
    setState(() {
      _game.tap(row, col);
    });
    _pushStateNotifier();
    _checkGameOver();
    _scheduleAiMove();
  }

  void _scheduleAiMove() {
    if (!_isAiTurn) return;
    setState(() => _aiThinking = true);
    final delay = SettingsService.instance.fastAiMoves
        ? 150
        : switch (widget.difficulty) {
            AiDifficulty.easy => 700,
            AiDifficulty.medium => 500,
            AiDifficulty.hard => 300,
          };
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (!mounted || !_isAiTurn) return;
      _playAiMove();
    });
  }

  void _playAiMove() {
    if (!mounted) return;
    final piecesWithMoves = <(int, int, List<List<int>>)>[];
    final mustCapture = _checkMustCapture();

    for (int r = 0; r < CheckersModel.size; r++) {
      for (int c = 0; c < CheckersModel.size; c++) {
        final piece = _game.board[r][c];
        if (piece == null) continue;
        if (piece != 'b' && piece != 'B') continue;
        final didSelect = _game.tap(r, c);
        if (!didSelect) {
          continue; // tap failed (e.g. piece has no moves under mandatory-capture) — skip to avoid reading stale highlightedMoves
        }
        final moves = List<List<int>>.from(_game.highlightedMoves);
        if (moves.isNotEmpty) piecesWithMoves.add((r, c, moves));
      }
    }

    _game.deselect(); // clear selection without risk of executing a move

    if (piecesWithMoves.isEmpty) {
      setState(() => _aiThinking = false);
      return;
    }

    late final (int, int, List<List<int>>) pick;
    late final List<int> move;

    switch (widget.difficulty) {
      case AiDifficulty.easy:
        final p = piecesWithMoves[_rng.nextInt(piecesWithMoves.length)];
        pick = p;
        move = p.$3[_rng.nextInt(p.$3.length)];
      case AiDifficulty.medium:
        final captures = piecesWithMoves
            .where((e) => e.$3.any((m) => (m[0] - e.$1).abs() == 2))
            .toList();
        final candidates = (mustCapture && captures.isNotEmpty)
            ? captures
            : piecesWithMoves;
        final p = candidates[_rng.nextInt(candidates.length)];
        pick = p;
        move = p.$3[_rng.nextInt(p.$3.length)];
      case AiDifficulty.hard:
        final captures = piecesWithMoves
            .where((e) => e.$3.any((m) => (m[0] - e.$1).abs() == 2))
            .toList();
        if (mustCapture && captures.isNotEmpty) {
          final p = captures[_rng.nextInt(captures.length)];
          pick = p;
          // Black promotes at row 7 (CheckersModel.size - 1), not row 0.
          final kingCaptures = p.$3
              .where(
                (m) =>
                    m[0] == CheckersModel.size - 1 || (m[0] - p.$1).abs() == 2,
              )
              .toList();
          move = kingCaptures.isNotEmpty
              ? kingCaptures[_rng.nextInt(kingCaptures.length)]
              : p.$3[_rng.nextInt(p.$3.length)];
        } else {
          int bestScore = -1;
          var bestPick = piecesWithMoves[0];
          var bestMove = piecesWithMoves[0].$3[0];
          for (final p in piecesWithMoves) {
            final isKing = _game.board[p.$1][p.$2] == 'B';
            for (final m in p.$3) {
              int score = 0;
              if (isKing) score += 5;
              score += (p.$1 - m[0]);
              score += (3 - (m[1] - 3).abs());
              if (score > bestScore) {
                bestScore = score;
                bestPick = p;
                bestMove = m;
              }
            }
          }
          pick = bestPick;
          move = bestMove;
        }
    }

    _game.tap(pick.$1, pick.$2);
    _game.tap(move[0], move[1]);

    while (_game.selectedRow != null &&
        _game.highlightedMoves.isNotEmpty &&
        _game.current == CheckersPlayer.black) {
      final jumps = _game.highlightedMoves;
      final jump = jumps[_rng.nextInt(jumps.length)];
      _game.tap(jump[0], jump[1]);
    }

    setState(() => _aiThinking = false);
    _pushStateNotifier();
    _checkGameOver();
    _scheduleAiMove();
  }

  void _checkGameOver() {
    final state = _game.state;
    if (state is CheckersWin) {
      final winner = state.winner == CheckersPlayer.red ? 'Red' : 'Black';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call('$winner wins!');
      });
    }
  }

  bool _checkMustCapture() {
    for (int r = 0; r < CheckersModel.size; r++) {
      for (int c = 0; c < CheckersModel.size; c++) {
        final piece = _game.board[r][c];
        if (piece == 'b' || piece == 'B') {
          final isKing = piece == 'B';
          final directions = isKing
              ? [(-1, -1), (-1, 1), (1, -1), (1, 1)]
              : [(1, -1), (1, 1)];
          for (final d in directions) {
            final nr = r + d.$1;
            final nc = c + d.$2;
            if (nr < 0 || nc < 0 || nr >= 8 || nc >= 8) continue;
            final mid = _game.board[nr][nc];
            if (mid == 'r' || mid == 'R') {
              final jr = nr + d.$1;
              final jc = nc + d.$2;
              if (jr >= 0 &&
                  jc >= 0 &&
                  jr < 8 &&
                  jc < 8 &&
                  _game.board[jr][jc] == null) {
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showMoveHints = SettingsService.instance.showMoveHints;
    return Column(
      children: [
        GameStatusBar(
          player1: const PlayerInfo(label: 'Red', color: Color(0xFFD32F2F)),
          player2: const PlayerInfo(label: 'Black', color: Color(0xFF424242)),
          activePlayer: _game.state is CheckersPlaying
              ? (_game.current == CheckersPlayer.red ? 1 : 2)
              : 0,
          message: _overrideMessage,
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF5D4037), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: CheckersModel.size,
                  ),
                  itemCount: CheckersModel.size * CheckersModel.size,
                  itemBuilder: (context, index) {
                    final row = index ~/ CheckersModel.size;
                    final col = index % CheckersModel.size;
                    return _CheckersCell(
                      row: row,
                      col: col,
                      piece: _game.board[row][col],
                      isSelected:
                          _game.selectedRow == row && _game.selectedCol == col,
                      isHighlighted:
                          showMoveHints &&
                          _game.highlightedMoves.any(
                            (m) => m[0] == row && m[1] == col,
                          ),
                      onTap: () => _onTap(row, col),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckersCell extends StatelessWidget {
  const _CheckersCell({
    required this.row,
    required this.col,
    required this.piece,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
  });

  final int row;
  final int col;
  final String? piece;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = (row + col) % 2 == 1;

    Color bgColor;
    if (isSelected) {
      bgColor = const Color(0xFF5C9CE6);
    } else if (isHighlighted) {
      bgColor = const Color(0xFFA5D6A7);
    } else {
      bgColor = isDark ? const Color(0xFF769656) : const Color(0xFFEEEED2);
    }

    return Semantics(
      label: _cellLabel(),
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: isHighlighted
                ? Border.all(color: const Color(0xFF4CAF50), width: 2)
                : null,
          ),
          child: Center(
            child: piece != null
                ? _CheckersPiece(piece: piece!, isSelected: isSelected)
                : isHighlighted
                ? Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  String _cellLabel() {
    final rowLetter = String.fromCharCode('A'.codeUnitAt(0) + row);
    final colNum = col + 1;
    if (piece != null) {
      final color = (piece == 'r' || piece == 'R') ? 'Red' : 'Black';
      final type = (piece == 'R' || piece == 'B') ? 'king' : 'piece';
      final sel = isSelected ? ', selected' : '';
      return '$color $type at $rowLetter$colNum$sel';
    }
    if (isHighlighted) return 'Move to $rowLetter$colNum';
    return 'Empty $rowLetter$colNum';
  }
}

class _CheckersPiece extends StatelessWidget {
  const _CheckersPiece({required this.piece, this.isSelected = false});

  final String piece;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isRed = piece == 'r' || piece == 'R';
    final isKing = piece == 'R' || piece == 'B';
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRed ? Colors.red.shade700 : Colors.grey.shade900,
        border: Border.all(
          color: isSelected
              ? Colors.white
              : isRed
              ? Colors.red.shade900
              : Colors.grey.shade700,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF5C9CE6).withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: isSelected ? 8 : 3,
            spreadRadius: isSelected ? 2 : 0,
            offset: isSelected ? Offset.zero : const Offset(1, 2),
          ),
        ],
      ),
      child: isKing
          ? const Center(child: Icon(Icons.star, color: Colors.amber, size: 18))
          : null,
    );
  }
}
