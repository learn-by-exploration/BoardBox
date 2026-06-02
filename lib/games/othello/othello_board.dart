import 'dart:math';

import 'package:flutter/material.dart';

import 'package:common_games/games/othello/othello_model.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/widgets/game_status_bar.dart';

class OthelloBoard extends StatefulWidget {
  const OthelloBoard({
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
  State<OthelloBoard> createState() => _OthelloBoardState();
}

class _OthelloBoardState extends State<OthelloBoard> {
  late OthelloModel _game;
  final Random _rng = Random();
  bool _aiThinking = false;

  String? get _overrideMessage {
    if (_aiThinking) return 'Computer thinking…';
    return switch (_game.state) {
      OthelloPlaying() => null,
      OthelloWin(:final winner) =>
        '${winner == OthelloPlayer.black ? "Black" : "White"} wins!',
      OthelloDraw() => 'Draw!',
    };
  }

  bool get _isAiTurn =>
      widget.mode == GameMode.singlePlayer &&
      _game.current == OthelloPlayer.white &&
      _game.state is OthelloPlaying;

  void _pushStateNotifier() {
    widget.stateNotifier?.value = _game.toJson();
  }

  @override
  void initState() {
    super.initState();
    _game = widget.initialState != null
        ? OthelloModel.fromJson(widget.initialState!)
        : OthelloModel();
  }

  void _onTap(int row, int col) {
    if (_aiThinking) return;
    final played = _game.play(row, col);
    if (!played) return;
    setState(() {});
    _pushStateNotifier();
    _checkGameOver();
    _scheduleAiMove();
  }

  void _scheduleAiMove() {
    if (!_isAiTurn) return;
    setState(() => _aiThinking = true);
    final delay = switch (widget.difficulty) {
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
    final moves = _game.getValidMoves();
    if (moves.isEmpty) return;

    List<int> pick;
    switch (widget.difficulty) {
      case AiDifficulty.easy:
        pick = moves[_rng.nextInt(moves.length)];
      case AiDifficulty.medium:
        const corners = [(0, 0), (0, 7), (7, 0), (7, 7)];
        List<int>? cornerMove;
        for (final c in corners) {
          final idx = moves.indexWhere((m) => m[0] == c.$1 && m[1] == c.$2);
          if (idx != -1) {
            cornerMove = moves[idx];
            break;
          }
        }
        if (cornerMove != null) {
          pick = cornerMove;
        } else {
          final edges = moves
              .where((m) => m[0] == 0 || m[0] == 7 || m[1] == 0 || m[1] == 7)
              .toList();
          final candidates = edges.isNotEmpty ? edges : moves;
          pick = candidates[_rng.nextInt(candidates.length)];
        }
      case AiDifficulty.hard:
        pick = _bestMoveHard(moves);
    }

    setState(() {
      _game.play(pick[0], pick[1]);
      _aiThinking = false;
    });
    _pushStateNotifier();
    _checkGameOver();
    _scheduleAiMove();
  }

  List<int> _bestMoveHard(List<List<int>> moves) {
    const weights = [
      [120, -20, 20, 5, 5, 20, -20, 120],
      [-20, -40, -5, -5, -5, -5, -40, -20],
      [20, -5, 15, 3, 3, 15, -5, 20],
      [5, -5, 3, 3, 3, 3, -5, 5],
      [5, -5, 3, 3, 3, 3, -5, 5],
      [20, -5, 15, 3, 3, 15, -5, 20],
      [-20, -40, -5, -5, -5, -5, -40, -20],
      [120, -20, 20, 5, 5, 20, -20, 120],
    ];
    int bestScore = -1000;
    List<int> bestMove = moves[0];
    for (final m in moves) {
      final score = weights[m[0]][m[1]];
      if (score > bestScore) {
        bestScore = score;
        bestMove = m;
      }
    }
    return bestMove;
  }

  void _checkGameOver() {
    final state = _game.state;
    if (state is OthelloWin) {
      final winner = state.winner == OthelloPlayer.black ? 'Black' : 'White';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call(
            '$winner wins!\nBlack: ${_game.blackCount} · White: ${_game.whiteCount}');
      });
    } else if (state is OthelloDraw) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call(
            "It's a draw!\nBlack: ${_game.blackCount} · White: ${_game.whiteCount}");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validMoves = _game.getValidMoves();
    final activePlayer = _game.current == OthelloPlayer.black ? 1 : 2;

    return Column(
      children: [
        GameStatusBar(
          player1: PlayerInfo(
            label: 'Black',
            color: const Color(0xFF212121),
            score: _game.blackCount,
          ),
          player2: PlayerInfo(
            label: 'White',
            color: const Color(0xFF9E9E9E),
            score: _game.whiteCount,
          ),
          activePlayer: _game.state is OthelloPlaying ? activePlayer : 0,
          message: _overrideMessage,
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1B5E20), width: 3),
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
                  crossAxisCount: OthelloModel.size,
                ),
                itemCount: OthelloModel.size * OthelloModel.size,
                itemBuilder: (context, index) {
                  final row = index ~/ OthelloModel.size;
                  final col = index % OthelloModel.size;
                  final isValid =
                      validMoves.any((m) => m[0] == row && m[1] == col);
                  return _OthelloCell(
                    piece: _game.board[row][col],
                    isValidMove: isValid,
                    onTap: () => _onTap(row, col),
                    row: row,
                    col: col,
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

class _OthelloCell extends StatelessWidget {
  const _OthelloCell({
    required this.piece,
    required this.isValidMove,
    required this.onTap,
    required this.row,
    required this.col,
  });

  final int row;
  final int col;
  final OthelloPlayer? piece;
  final bool isValidMove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rowLetter = String.fromCharCode('A'.codeUnitAt(0) + row);
    final colNum = col + 1;
    String label;
    if (piece != null) {
      label =
          '${piece == OthelloPlayer.black ? "Black" : "White"} disc at $rowLetter$colNum';
    } else if (isValidMove) {
      label = 'Valid move at $rowLetter$colNum';
    } else {
      label = 'Empty $rowLetter$colNum';
    }
    return Semantics(
      label: label,
      button: piece == null && isValidMove,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.black.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Center(
            child: piece != null
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: piece == OthelloPlayer.black
                          ? const RadialGradient(
                              center: Alignment(-0.3, -0.3),
                              colors: [Color(0xFF444444), Color(0xFF111111)],
                            )
                          : const RadialGradient(
                              center: Alignment(-0.3, -0.3),
                              colors: [Colors.white, Color(0xFFDDDDDD)],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 3,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                  )
                : isValidMove
                    ? Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
