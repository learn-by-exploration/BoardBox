import 'dart:math';

import 'package:flutter/material.dart';

import 'package:common_games/games/gomoku/gomoku_model.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/services/haptic_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/widgets/game_status_bar.dart';

class GomokuBoard extends StatefulWidget {
  const GomokuBoard({
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
  State<GomokuBoard> createState() => _GomokuBoardState();
}

class _GomokuBoardState extends State<GomokuBoard> {
  late GomokuModel _game;
  final Random _rng = Random();
  bool _aiThinking = false;
  (int, int)? _lastMove;

  final List<Map<String, dynamic>> _history = [];

  void _pushHistory() {
    _history.add(_game.toJson());
  }

  void _performUndo() {
    if (_history.isEmpty) return;
    // In single-player mode undo both human and AI response
    if (widget.mode == GameMode.singlePlayer && _history.length >= 2) {
      _history.removeLast();
    }
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    setState(() {
      _game = GomokuModel.fromJson(snapshot);
      _aiThinking = false;
      _lastMove = null;
    });
    _updateUndoNotifier();
    _pushStateNotifier();
  }

  void _updateUndoNotifier() {
    widget.undoNotifier?.value = _history.isNotEmpty ? _performUndo : null;
  }

  bool get _isAiTurn =>
      widget.mode == GameMode.singlePlayer &&
      _game.current == GomokuPlayer.white &&
      _game.state is GomokuPlaying;

  String? get _overrideMessage {
    if (_aiThinking) return 'Computer thinking…';
    return switch (_game.state) {
      GomokuPlaying() => null,
      GomokuWin(:final winner) =>
        '${winner == GomokuPlayer.black ? "Black" : "White"} wins!',
      GomokuDraw() => 'Draw!',
    };
  }

  void _onTap(int row, int col) {
    if (_aiThinking) return;
    _pushHistory();
    final played = _game.play(row, col);
    if (!played) {
      // revert the history push since nothing changed
      _history.removeLast();
      return;
    }
    HapticService.onMove();
    setState(() => _lastMove = (row, col));
    _updateUndoNotifier();
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
    final board = _game.board;
    final empty = <(int, int)>[];
    for (int r = 0; r < GomokuModel.size; r++) {
      for (int c = 0; c < GomokuModel.size; c++) {
        if (board[r][c] == null) empty.add((r, c));
      }
    }
    if (empty.isEmpty) {
      setState(() => _aiThinking = false);
      _updateUndoNotifier();
      return;
    }

    final (int, int) pick;
    switch (widget.difficulty) {
      case AiDifficulty.easy:
        pick = empty[_rng.nextInt(empty.length)];
      case AiDifficulty.medium:
        final adjacent = empty.where((pos) {
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              final nr = pos.$1 + dr;
              final nc = pos.$2 + dc;
              if (nr >= 0 &&
                  nc >= 0 &&
                  nr < GomokuModel.size &&
                  nc < GomokuModel.size &&
                  board[nr][nc] != null) {
                return true;
              }
            }
          }
          return false;
        }).toList();
        final cands = adjacent.isNotEmpty ? adjacent : empty;
        pick = cands[_rng.nextInt(cands.length)];
      case AiDifficulty.hard:
        pick = _bestMoveHard(board, empty);
    }

    setState(() {
      _game.play(pick.$1, pick.$2);
      _lastMove = pick;
      _aiThinking = false;
    });
    _updateUndoNotifier();
    _pushStateNotifier();
    _checkGameOver();
  }

  (int, int) _bestMoveHard(
    List<List<GomokuPlayer?>> board,
    List<(int, int)> empty,
  ) {
    // Restrict candidates to cells within distance 2 of existing stones
    final candidates = empty.where((pos) {
      for (int dr = -2; dr <= 2; dr++) {
        for (int dc = -2; dc <= 2; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = pos.$1 + dr, nc = pos.$2 + dc;
          if (nr >= 0 &&
              nc >= 0 &&
              nr < GomokuModel.size &&
              nc < GomokuModel.size &&
              board[nr][nc] != null) {
            return true;
          }
        }
      }
      return false;
    }).toList();

    final pool = candidates.isNotEmpty ? candidates : empty;

    int bestScore = -1;
    (int, int) bestMove = pool[_rng.nextInt(pool.length)];

    for (final pos in pool) {
      final score = _evaluateCell(board, pos);
      if (score > bestScore) {
        bestScore = score;
        bestMove = pos;
      }
    }
    return bestMove;
  }

  /// Evaluates a candidate cell by scoring all 4 directions for both players.
  /// Offense score uses white (AI), defense uses black (human) × 1.1 weight.
  int _evaluateCell(List<List<GomokuPlayer?>> board, (int, int) pos) {
    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];
    int totalScore = 0;

    for (final dir in directions) {
      final offScore = _directionScore(board, pos, dir, GomokuPlayer.white);
      final defScore = _directionScore(board, pos, dir, GomokuPlayer.black);
      totalScore += offScore + (defScore * 1.1).toInt();
    }
    return totalScore;
  }

  /// Scores placing at [pos] in [dir] for [player].
  /// Counts run length and whether each end is open, closed (blocked by
  /// opponent), or wall (edge of board). Open ends multiply the threat value.
  int _directionScore(
    List<List<GomokuPlayer?>> board,
    (int, int) pos,
    (int, int) dir,
    GomokuPlayer player,
  ) {
    int count = 1; // the cell itself
    int openEnds = 0;

    // Count in positive direction
    int r = pos.$1 + dir.$1, c = pos.$2 + dir.$2;
    while (r >= 0 &&
        c >= 0 &&
        r < GomokuModel.size &&
        c < GomokuModel.size &&
        board[r][c] == player) {
      count++;
      r += dir.$1;
      c += dir.$2;
    }
    // Check if positive end is open
    if (r >= 0 &&
        c >= 0 &&
        r < GomokuModel.size &&
        c < GomokuModel.size &&
        board[r][c] == null) {
      openEnds++;
    }

    // Count in negative direction
    r = pos.$1 - dir.$1;
    c = pos.$2 - dir.$2;
    while (r >= 0 &&
        c >= 0 &&
        r < GomokuModel.size &&
        c < GomokuModel.size &&
        board[r][c] == player) {
      count++;
      r -= dir.$1;
      c -= dir.$2;
    }
    // Check if negative end is open
    if (r >= 0 &&
        c >= 0 &&
        r < GomokuModel.size &&
        c < GomokuModel.size &&
        board[r][c] == null) {
      openEnds++;
    }

    // A run of 5+ is already a win; score very high
    if (count >= 5) return 200000;

    // Score by run length × open-end multiplier
    return switch (count) {
      4 =>
        openEnds == 2
            ? 50000
            : openEnds == 1
            ? 10000
            : 100,
      3 =>
        openEnds == 2
            ? 5000
            : openEnds == 1
            ? 1000
            : 50,
      2 =>
        openEnds == 2
            ? 500
            : openEnds == 1
            ? 100
            : 10,
      1 =>
        openEnds == 2
            ? 50
            : openEnds == 1
            ? 10
            : 1,
      _ => 0,
    };
  }

  void _checkGameOver() {
    final state = _game.state;
    if (state is GomokuWin) {
      final winner = state.winner == GomokuPlayer.black ? 'Black' : 'White';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HapticService.onGameOver();
        widget.onGameOver?.call('$winner wins!');
      });
    } else if (state is GomokuDraw) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HapticService.onGameOver();
        widget.onGameOver?.call('It\'s a draw!');
      });
    }
  }

  void _handleTap(BoxConstraints constraints, TapDownDetails details) {
    if (_aiThinking || _game.state is! GomokuPlaying) return;
    final colCellSize = constraints.maxWidth / (GomokuModel.size - 1);
    final rowCellSize = constraints.maxHeight / (GomokuModel.size - 1);
    final col = (details.localPosition.dx / colCellSize).round();
    final row = (details.localPosition.dy / rowCellSize).round();
    if (row < 0 || row >= GomokuModel.size) return;
    if (col < 0 || col >= GomokuModel.size) return;
    _onTap(row, col);
  }

  void _pushStateNotifier() {
    widget.stateNotifier?.value = _game.toJson();
  }

  @override
  void initState() {
    super.initState();
    _game = widget.initialState != null
        ? GomokuModel.fromJson(widget.initialState!)
        : GomokuModel();
    _updateUndoNotifier();
  }

  @override
  Widget build(BuildContext context) {
    final activePlayer = _game.current == GomokuPlayer.black ? 1 : 2;

    return Column(
      children: [
        GameStatusBar(
          player1: const PlayerInfo(label: 'Black', color: Color(0xFF222222)),
          player2: const PlayerInfo(label: 'White', color: Color(0xFF888888)),
          activePlayer: _game.state is GomokuPlaying ? activePlayer : 0,
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
                    colors: [Color(0xFFE8C876), Color(0xFFD4A44C)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8B6914), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) => GestureDetector(
                      onTapDown: (d) => _handleTap(constraints, d),
                      child: CustomPaint(
                        painter: _GomokuPainter(_game, _lastMove),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GomokuPainter extends CustomPainter {
  final GomokuModel game;
  final (int, int)? lastMove;

  static const _starPoints = [
    (3, 3),
    (3, 7),
    (3, 11),
    (7, 3),
    (7, 7),
    (7, 11),
    (11, 3),
    (11, 7),
    (11, 11),
  ];

  const _GomokuPainter(this.game, this.lastMove);

  @override
  void paint(Canvas canvas, Size size) {
    const n = GomokuModel.size; // 15
    final colCellSize = size.width / (n - 1);
    final rowCellSize = size.height / (n - 1);
    final stoneR = colCellSize * 0.44;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    for (int i = 0; i < n; i++) {
      canvas.drawLine(
        Offset(0, i * rowCellSize),
        Offset(size.width, i * rowCellSize),
        gridPaint,
      );
      canvas.drawLine(
        Offset(i * colCellSize, 0),
        Offset(i * colCellSize, size.height),
        gridPaint,
      );
    }

    // Star points (traditional 15×15 positions)
    final starPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    for (final pt in _starPoints) {
      canvas.drawCircle(
        Offset(pt.$2 * colCellSize, pt.$1 * rowCellSize),
        3.5,
        starPaint,
      );
    }

    // Stones
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final piece = game.board[r][c];
        if (piece == null) continue;
        _drawStone(
          canvas,
          Offset(c * colCellSize, r * rowCellSize),
          stoneR,
          piece,
          isLast: lastMove == (r, c),
        );
      }
    }
  }

  void _drawStone(
    Canvas canvas,
    Offset center,
    double radius,
    GomokuPlayer player, {
    bool isLast = false,
  }) {
    // Shadow (drawn first, behind the stone)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(center.translate(1, 2), radius * 0.92, shadowPaint);

    // Stone fill with radial gradient
    final gradient = player == GomokuPlayer.black
        ? const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: [Color(0xFF666666), Color(0xFF111111)],
          )
        : const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: [Colors.white, Color(0xFFCCCCCC)],
          );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        ),
    );

    // Border ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = player == GomokuPlayer.black
            ? Colors.black87
            : Colors.grey.shade400
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );

    // Last-move indicator dot
    if (isLast) {
      canvas.drawCircle(
        center,
        radius * 0.28,
        Paint()
          ..color = player == GomokuPlayer.black
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GomokuPainter old) =>
      old.lastMove != lastMove || old.game != game;
}
