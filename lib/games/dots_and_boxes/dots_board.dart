import 'dart:math';

import 'package:flutter/material.dart';

import 'package:common_games/games/dots_and_boxes/dots_model.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/widgets/game_status_bar.dart';

class DotsBoard extends StatefulWidget {
  const DotsBoard({
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
  State<DotsBoard> createState() => _DotsBoardState();
}

class _DotsBoardState extends State<DotsBoard> {
  late DotsModel _game;
  final Random _rng = Random();
  bool _aiThinking = false;

  static const Color _p1Color = Color(0xFF1565C0); // blue
  static const Color _p2Color = Color(0xFFC62828); // red

  String? get _overrideMessage {
    if (_aiThinking) return 'Computer thinking…';
    return switch (_game.state) {
      DotsPlaying() => null,
      DotsWin(:final winner) =>
        '${winner == DotsPlayer.player1 ? "Player 1" : "Player 2"} wins!',
      DotsDraw() => 'Draw!',
    };
  }

  bool get _isAiTurn =>
      widget.mode == GameMode.singlePlayer &&
      _game.current == DotsPlayer.player2 &&
      _game.state is DotsPlaying;

  void _pushStateNotifier() {
    widget.stateNotifier?.value = _game.toJson();
  }

  @override
  void initState() {
    super.initState();
    _game = widget.initialState != null
        ? DotsModel.fromJson(widget.initialState!)
        : DotsModel();
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
    final available = <(int, int, int)>[];
    for (int r = 0; r < DotsModel.dotRows; r++) {
      for (int c = 0; c < DotsModel.dotCols - 1; c++) {
        if (_game.hLines[r][c] == null) available.add((0, r, c));
      }
    }
    for (int r = 0; r < DotsModel.dotRows - 1; r++) {
      for (int c = 0; c < DotsModel.dotCols; c++) {
        if (_game.vLines[r][c] == null) available.add((1, r, c));
      }
    }
    if (available.isEmpty) return;

    late final (int, int, int) pick;
    switch (widget.difficulty) {
      case AiDifficulty.easy:
        pick = available[_rng.nextInt(available.length)];
      case AiDifficulty.medium:
        final completing = available.where(_completesBox).toList();
        final candidates = completing.isNotEmpty ? completing : available;
        pick = candidates[_rng.nextInt(candidates.length)];
      case AiDifficulty.hard:
        final completing = available.where(_completesBox).toList();
        if (completing.isNotEmpty) {
          pick = completing[_rng.nextInt(completing.length)];
        } else {
          final safe = available.where((l) => !_givesBox(l)).toList();
          final candidates = safe.isNotEmpty ? safe : available;
          pick = candidates[_rng.nextInt(candidates.length)];
        }
    }

    if (pick.$1 == 0) {
      _game.drawHLine(pick.$2, pick.$3);
    } else {
      _game.drawVLine(pick.$2, pick.$3);
    }

    setState(() => _aiThinking = false);
    _pushStateNotifier();
    _checkGameOver();
    _scheduleAiMove();
  }

  bool _completesBox((int, int, int) line) {
    final type = line.$1;
    final r = line.$2;
    final c = line.$3;
    if (type == 0) {
      if (r > 0) {
        final sides = (_game.hLines[r - 1][c] != null ? 1 : 0) +
            (_game.vLines[r - 1][c] != null ? 1 : 0) +
            (_game.vLines[r - 1][c + 1] != null ? 1 : 0);
        if (sides == 3) return true;
      }
      if (r < DotsModel.boxRows) {
        final sides = (_game.hLines[r + 1][c] != null ? 1 : 0) +
            (_game.vLines[r][c] != null ? 1 : 0) +
            (_game.vLines[r][c + 1] != null ? 1 : 0);
        if (sides == 3) return true;
      }
    } else {
      if (c > 0) {
        final sides = (_game.hLines[r][c - 1] != null ? 1 : 0) +
            (_game.hLines[r + 1][c - 1] != null ? 1 : 0) +
            (_game.vLines[r][c - 1] != null ? 1 : 0);
        if (sides == 3) return true;
      }
      if (c < DotsModel.boxCols) {
        final sides = (_game.hLines[r][c] != null ? 1 : 0) +
            (_game.hLines[r + 1][c] != null ? 1 : 0) +
            (_game.vLines[r][c + 1] != null ? 1 : 0);
        if (sides == 3) return true;
      }
    }
    return false;
  }

  bool _givesBox((int, int, int) line) {
    final type = line.$1;
    final r = line.$2;
    final c = line.$3;
    if (type == 0) {
      if (r > 0) {
        final sides = (_game.hLines[r - 1][c] != null ? 1 : 0) +
            (_game.vLines[r - 1][c] != null ? 1 : 0) +
            (_game.vLines[r - 1][c + 1] != null ? 1 : 0);
        if (sides == 2) return true;
      }
      if (r < DotsModel.boxRows) {
        final sides = (_game.hLines[r + 1][c] != null ? 1 : 0) +
            (_game.vLines[r][c] != null ? 1 : 0) +
            (_game.vLines[r][c + 1] != null ? 1 : 0);
        if (sides == 2) return true;
      }
    } else {
      if (c > 0) {
        final sides = (_game.hLines[r][c - 1] != null ? 1 : 0) +
            (_game.hLines[r + 1][c - 1] != null ? 1 : 0) +
            (_game.vLines[r][c - 1] != null ? 1 : 0);
        if (sides == 2) return true;
      }
      if (c < DotsModel.boxCols) {
        final sides = (_game.hLines[r][c] != null ? 1 : 0) +
            (_game.hLines[r + 1][c] != null ? 1 : 0) +
            (_game.vLines[r][c + 1] != null ? 1 : 0);
        if (sides == 2) return true;
      }
    }
    return false;
  }

  void _checkGameOver() {
    final state = _game.state;
    if (state is DotsWin) {
      final winner =
          state.winner == DotsPlayer.player1 ? 'Player 1' : 'Player 2';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call(
            '$winner wins!\nP1: ${_game.score1} · P2: ${_game.score2}');
      });
    } else if (state is DotsDraw) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call(
            "It's a draw!\nP1: ${_game.score1} · P2: ${_game.score2}");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePlayer = _game.current == DotsPlayer.player1 ? 1 : 2;

    return Column(
      children: [
        GameStatusBar(
          player1: PlayerInfo(
              label: 'Player 1', color: _p1Color, score: _game.score1),
          player2: PlayerInfo(
              label: 'Player 2', color: _p2Color, score: _game.score2),
          activePlayer: _game.state is DotsPlaying ? activePlayer : 0,
          message: _overrideMessage,
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CustomPaint(
                  painter: _DotsPainter(_game),
                  // LayoutBuilder gives the actual paint-canvas size so
                  // tap mapping never reads from the wrong RenderObject.
                  child: LayoutBuilder(
                    builder: (_, constraints) => GestureDetector(
                      onTapDown: (d) => _handleTap(constraints.biggest, d),
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

  void _handleTap(Size paintAreaSize, TapDownDetails details) {
    if (_aiThinking) return;
    // localPosition is already in the GestureDetector's coordinate space
    // (which fills the CustomPaint canvas). No padding subtraction needed.
    final dx = details.localPosition.dx;
    final dy = details.localPosition.dy;
    final paintSize = paintAreaSize.width < paintAreaSize.height
        ? paintAreaSize.width
        : paintAreaSize.height;
    if (dx < 0 || dy < 0 || dx > paintAreaSize.width || dy > paintAreaSize.height) {
      return;
    }

    final cellW = paintSize / (DotsModel.dotCols - 1);
    final cellH = paintSize / (DotsModel.dotRows - 1);
    final gridX = dx / cellW;
    final gridY = dy / cellH;
    final fracX = gridX - gridX.floor();
    final fracY = gridY - gridY.floor();

    bool acted = false;
    if (fracY < 0.25 || fracY > 0.75) {
      final lineRow = gridY.round();
      final lineCol = gridX.floor();
      if (lineCol >= 0 && lineCol < DotsModel.dotCols - 1) {
        acted = _game.drawHLine(lineRow, lineCol);
      }
    } else if (fracX < 0.25 || fracX > 0.75) {
      final lineRow = gridY.floor();
      final lineCol = gridX.round();
      if (lineRow >= 0 && lineRow < DotsModel.dotRows - 1) {
        acted = _game.drawVLine(lineRow, lineCol);
      }
    } else {
      final nearestCol = gridX.round();
      final nearestRow = gridY.round();
      final distToHLine = (gridY - nearestRow).abs();
      final distToVLine = (gridX - nearestCol).abs();
      if (distToHLine < distToVLine) {
        final lineRow = nearestRow;
        final lineCol = gridX.floor();
        if (lineCol >= 0 && lineCol < DotsModel.dotCols - 1) {
          acted = _game.drawHLine(lineRow, lineCol);
        }
      } else {
        final lineRow = gridY.floor();
        final lineCol = nearestCol;
        if (lineRow >= 0 && lineRow < DotsModel.dotRows - 1) {
          acted = _game.drawVLine(lineRow, lineCol);
        }
      }
    }

    if (acted) {
      setState(() {});
      _pushStateNotifier();
      _checkGameOver();
      _scheduleAiMove();
    }
  }
}

class _DotsPainter extends CustomPainter {
  final DotsModel game;

  static const Color _p1Color = Color(0xFF1565C0);
  static const Color _p2Color = Color(0xFFC62828);

  _DotsPainter(this.game);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / (DotsModel.dotCols - 1);
    final cellH = size.height / (DotsModel.dotRows - 1);

    final dotPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;

    // Captured boxes
    for (int r = 0; r < DotsModel.boxRows; r++) {
      for (int c = 0; c < DotsModel.boxCols; c++) {
        final owner = game.boxes[r][c];
        if (owner == null) continue;
        final fill = Paint()
          ..color =
              (owner == DotsPlayer.player1 ? _p1Color : _p2Color)
                  .withValues(alpha: 0.18);
        canvas.drawRect(
            Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH), fill);
      }
    }

    // Horizontal lines (coloured by owner)
    for (int r = 0; r < DotsModel.dotRows; r++) {
      for (int c = 0; c < DotsModel.dotCols - 1; c++) {
        final player = game.hLines[r][c];
        if (player == null) continue;
        final linePaint = Paint()
          ..color = player == DotsPlayer.player1 ? _p1Color : _p2Color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c * cellW, r * cellH),
            Offset((c + 1) * cellW, r * cellH), linePaint);
      }
    }

    // Vertical lines (coloured by owner)
    for (int r = 0; r < DotsModel.dotRows - 1; r++) {
      for (int c = 0; c < DotsModel.dotCols; c++) {
        final player = game.vLines[r][c];
        if (player == null) continue;
        final linePaint = Paint()
          ..color = player == DotsPlayer.player1 ? _p1Color : _p2Color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c * cellW, r * cellH),
            Offset(c * cellW, (r + 1) * cellH), linePaint);
      }
    }

    // Dots (drawn last, on top)
    for (int r = 0; r < DotsModel.dotRows; r++) {
      for (int c = 0; c < DotsModel.dotCols; c++) {
        canvas.drawCircle(Offset(c * cellW, r * cellH), 6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
