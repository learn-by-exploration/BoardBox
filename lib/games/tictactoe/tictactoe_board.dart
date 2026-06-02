import 'dart:math';

import 'package:flutter/material.dart';

import 'package:common_games/games/tictactoe/tictactoe_model.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/services/haptic_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/widgets/game_status_bar.dart';

class TicTacToeBoard extends StatefulWidget {
  const TicTacToeBoard({
    super.key,
    required this.mode,
    required this.boardSize,
    this.difficulty = AiDifficulty.medium,
    this.onGameOver,
    this.undoNotifier,
    this.stateNotifier,
    this.initialState,
  });

  final GameMode mode;
  final int boardSize;
  final AiDifficulty difficulty;
  final void Function(String result)? onGameOver;
  final ValueNotifier<VoidCallback?>? undoNotifier;
  final ValueNotifier<Map<String, dynamic>?>? stateNotifier;
  final Map<String, dynamic>? initialState;

  @override
  State<TicTacToeBoard> createState() => _TicTacToeBoardState();
}

class _TicTacToeBoardState extends State<TicTacToeBoard> {
  late TicTacToeModel _game;
  bool _aiThinking = false;
  final List<Map<String, dynamic>> _history = [];
  final Random _rng = Random();

  // O is the AI in single-player mode
  bool get _isAiTurn =>
      widget.mode == GameMode.singlePlayer &&
      _game.current == TicTacToePlayer.o &&
      _game.state is TicTacToePlaying;

  String? get _overrideMessage {
    if (_aiThinking) return 'Computer thinking…';
    return switch (_game.state) {
      TicTacToePlaying() => null,
      TicTacToeWin(:final winner) =>
        '${winner == TicTacToePlayer.x ? "X" : "O"} wins!',
      TicTacToeDraw() => 'Draw!',
    };
  }

  @override
  void initState() {
    super.initState();
    _game = widget.initialState != null
        ? TicTacToeModel.fromJson(widget.initialState!)
        : TicTacToeModel(size: widget.boardSize);
    _updateUndoNotifier();
    _pushStateNotifier();
  }

  void _pushHistory() {
    _history.add(_game.toJson());
  }

  void _performUndo() {
    if (_history.isEmpty) return;
    if (widget.mode == GameMode.singlePlayer && _history.length >= 2) {
      _history.removeLast();
    }
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    setState(() {
      _game = TicTacToeModel.fromJson(snapshot);
      _aiThinking = false;
    });
    _updateUndoNotifier();
    _pushStateNotifier();
  }

  void _updateUndoNotifier() {
    widget.undoNotifier?.value = _history.isNotEmpty ? _performUndo : null;
  }

  void _pushStateNotifier() {
    widget.stateNotifier?.value = _game.toJson();
  }

  void _onTap(int row, int col) {
    if (_aiThinking || _game.state is! TicTacToePlaying) return;
    _pushHistory();
    final played = _game.play(row, col);
    if (!played) {
      _history.removeLast();
      return;
    }
    HapticService.onMove();
    setState(() {});
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
            AiDifficulty.easy => 600,
            AiDifficulty.medium => 400,
            AiDifficulty.hard => 200,
          };
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (!mounted || !_isAiTurn) return;
      _playAiMove();
    });
  }

  void _playAiMove() {
    if (!mounted) return;
    final board = _game.board.map(List<TicTacToePlayer?>.from).toList();
    final empty = _game.emptyCells;
    if (empty.isEmpty) return;

    final (int, int) pick;

    switch (widget.difficulty) {
      case AiDifficulty.easy:
        // 30% smart, 70% random
        if (_rng.nextDouble() < 0.3) {
          pick = _smartMove(board, empty);
        } else {
          pick = empty[_rng.nextInt(empty.length)];
        }

      case AiDifficulty.medium:
        pick = _smartMove(board, empty);

      case AiDifficulty.hard:
        final maxDepth = switch (widget.boardSize) {
          3 => 9,
          4 => 6,
          _ => 4,
        };
        pick = _bestMove(
          board,
          widget.boardSize,
          _game.winLength,
          TicTacToePlayer.o,
          maxDepth,
          _rng,
        );
    }

    setState(() {
      _game.play(pick.$1, pick.$2);
      _aiThinking = false;
    });
    HapticService.onMove();
    _updateUndoNotifier();
    _pushStateNotifier();
    _checkGameOver();
  }

  /// Wins immediately if possible, else blocks opponent's immediate win, else random.
  (int, int) _smartMove(
    List<List<TicTacToePlayer?>> board,
    List<(int, int)> empty,
  ) {
    // Try to win
    for (final cell in empty) {
      final tempBoard = board.map(List<TicTacToePlayer?>.from).toList();
      tempBoard[cell.$1][cell.$2] = TicTacToePlayer.o;
      if (_wouldWin(
        tempBoard,
        cell.$1,
        cell.$2,
        TicTacToePlayer.o,
        widget.boardSize,
        _game.winLength,
      )) {
        return cell;
      }
    }
    // Try to block
    for (final cell in empty) {
      final tempBoard = board.map(List<TicTacToePlayer?>.from).toList();
      tempBoard[cell.$1][cell.$2] = TicTacToePlayer.x;
      if (_wouldWin(
        tempBoard,
        cell.$1,
        cell.$2,
        TicTacToePlayer.x,
        widget.boardSize,
        _game.winLength,
      )) {
        return cell;
      }
    }
    return empty[_rng.nextInt(empty.length)];
  }

  void _checkGameOver() {
    final s = _game.state;
    if (s is TicTacToeWin) {
      HapticService.onGameOver();
      final name = s.winner == TicTacToePlayer.x ? 'X' : 'O';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call('$name wins!');
      });
    } else if (s is TicTacToeDraw) {
      HapticService.onGameOver();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call("It's a draw!");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isXTurn = _game.current == TicTacToePlayer.x;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        GameStatusBar(
          player1: PlayerInfo(label: 'X', color: colorScheme.primary),
          player2: PlayerInfo(label: 'O', color: colorScheme.tertiary),
          activePlayer: _game.state is TicTacToePlaying ? (isXTurn ? 1 : 2) : 0,
          message: _overrideMessage,
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.boardSize,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: widget.boardSize * widget.boardSize,
                    itemBuilder: (ctx, index) {
                      final row = index ~/ widget.boardSize;
                      final col = index % widget.boardSize;
                      final piece = _game.board[row][col];
                      final isLastMove =
                          _game.lastRow == row && _game.lastCol == col;
                      return _TicTacToeCell(
                        piece: piece,
                        isLastMove: isLastMove,
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
        ),
      ],
    );
  }
}

// ── Cell widget ───────────────────────────────────────────────────────────────

class _TicTacToeCell extends StatelessWidget {
  const _TicTacToeCell({
    required this.piece,
    required this.isLastMove,
    required this.onTap,
    required this.row,
    required this.col,
  });

  final TicTacToePlayer? piece;
  final bool isLastMove;
  final VoidCallback onTap;
  final int row;
  final int col;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isLastMove && piece != null
        ? colorScheme.primaryContainer.withValues(alpha: 0.4)
        : colorScheme.surface;

    final String label;
    if (piece == TicTacToePlayer.x) {
      label = 'X at row ${row + 1} column ${col + 1}';
    } else if (piece == TicTacToePlayer.o) {
      label = 'O at row ${row + 1} column ${col + 1}';
    } else {
      label = 'Empty row ${row + 1} column ${col + 1}';
    }

    return Semantics(
      label: label,
      button: piece == null,
      child: GestureDetector(
        onTap: piece == null ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: piece == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: CustomPaint(
                    painter: _SymbolPainter(
                      player: piece!,
                      primaryColor: colorScheme.primary,
                      tertiaryColor: colorScheme.tertiary,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SymbolPainter extends CustomPainter {
  final TicTacToePlayer player;
  final Color primaryColor;
  final Color tertiaryColor;

  const _SymbolPainter({
    required this.player,
    required this.primaryColor,
    required this.tertiaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = size.width * 0.12;
    final strokeWidth = (size.width * 0.14).clamp(2.5, 8.0);

    if (player == TicTacToePlayer.x) {
      final paint = Paint()
        ..color = primaryColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(padding, padding),
        Offset(size.width - padding, size.height - padding),
        paint,
      );
      canvas.drawLine(
        Offset(size.width - padding, padding),
        Offset(padding, size.height - padding),
        paint,
      );
    } else {
      final paint = Paint()
        ..color = tertiaryColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      final center = Offset(size.width / 2, size.height / 2);
      final radius = (size.width / 2) - padding;
      canvas.drawCircle(center, radius < 1 ? 1 : radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) => old.player != player;
}

// ── AI top-level functions ────────────────────────────────────────────────────

bool _wouldWin(
  List<List<TicTacToePlayer?>> board,
  int row,
  int col,
  TicTacToePlayer player,
  int size,
  int winLength,
) {
  const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
  for (final d in dirs) {
    int count = 1;
    int r = row + d.$1, c = col + d.$2;
    while (r >= 0 && c >= 0 && r < size && c < size && board[r][c] == player) {
      count++;
      r += d.$1;
      c += d.$2;
    }
    r = row - d.$1;
    c = col - d.$2;
    while (r >= 0 && c >= 0 && r < size && c < size && board[r][c] == player) {
      count++;
      r -= d.$1;
      c -= d.$2;
    }
    if (count >= winLength) return true;
  }
  return false;
}

bool _isBoardFull(List<List<TicTacToePlayer?>> board, int size) {
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      if (board[r][c] == null) return false;
    }
  }
  return true;
}

int _evaluateBoard(
  List<List<TicTacToePlayer?>> board,
  int size,
  int winLength,
  TicTacToePlayer forPlayer,
) {
  final opponent = forPlayer == TicTacToePlayer.x
      ? TicTacToePlayer.o
      : TicTacToePlayer.x;
  int score = 0;

  void scanLine(List<(int, int)> cells) {
    int mine = 0, theirs = 0;
    for (final cell in cells) {
      final v = board[cell.$1][cell.$2];
      if (v == forPlayer) {
        mine++;
      } else if (v == opponent) {
        theirs++;
      }
    }
    if (mine > 0 && theirs == 0) score += pow(10, mine).toInt();
    if (theirs > 0 && mine == 0) score -= pow(10, theirs).toInt();
  }

  for (int r = 0; r < size; r++) {
    for (int c = 0; c <= size - winLength; c++) {
      scanLine(List.generate(winLength, (i) => (r, c + i)));
    }
  }
  for (int c = 0; c < size; c++) {
    for (int r = 0; r <= size - winLength; r++) {
      scanLine(List.generate(winLength, (i) => (r + i, c)));
    }
  }
  for (int r = 0; r <= size - winLength; r++) {
    for (int c = 0; c <= size - winLength; c++) {
      scanLine(List.generate(winLength, (i) => (r + i, c + i)));
    }
  }
  for (int r = 0; r <= size - winLength; r++) {
    for (int c = winLength - 1; c < size; c++) {
      scanLine(List.generate(winLength, (i) => (r + i, c - i)));
    }
  }
  return score;
}

List<(int, int)> _orderedEmpty(List<List<TicTacToePlayer?>> board, int size) {
  final mid = size ~/ 2;
  final cells = <(int, int)>[];
  if (board[mid][mid] == null) cells.add((mid, mid));
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      if (board[r][c] == null && !(r == mid && c == mid)) {
        cells.add((r, c));
      }
    }
  }
  return cells;
}

int _alphabeta(
  List<List<TicTacToePlayer?>> board,
  int size,
  int winLength,
  TicTacToePlayer currentPlayer,
  TicTacToePlayer aiPlayer,
  int depth,
  bool isMaximizing,
  int alpha,
  int beta,
) {
  if (depth == 0 || _isBoardFull(board, size)) {
    return _evaluateBoard(board, size, winLength, aiPlayer);
  }

  final cells = _orderedEmpty(board, size);
  if (cells.isEmpty) return _evaluateBoard(board, size, winLength, aiPlayer);

  if (isMaximizing) {
    int best = -1000001;
    for (final cell in cells) {
      board[cell.$1][cell.$2] = currentPlayer;
      if (_wouldWin(board, cell.$1, cell.$2, currentPlayer, size, winLength)) {
        board[cell.$1][cell.$2] = null;
        return currentPlayer == aiPlayer ? 100000 + depth : -(100000 + depth);
      }
      final next = currentPlayer == TicTacToePlayer.x
          ? TicTacToePlayer.o
          : TicTacToePlayer.x;
      final score = _alphabeta(
        board,
        size,
        winLength,
        next,
        aiPlayer,
        depth - 1,
        false,
        alpha,
        beta,
      );
      board[cell.$1][cell.$2] = null;
      best = max(best, score);
      alpha = max(alpha, best);
      if (beta <= alpha) break;
    }
    return best;
  } else {
    int best = 1000001;
    for (final cell in cells) {
      board[cell.$1][cell.$2] = currentPlayer;
      if (_wouldWin(board, cell.$1, cell.$2, currentPlayer, size, winLength)) {
        board[cell.$1][cell.$2] = null;
        return currentPlayer == aiPlayer ? 100000 + depth : -(100000 + depth);
      }
      final next = currentPlayer == TicTacToePlayer.x
          ? TicTacToePlayer.o
          : TicTacToePlayer.x;
      final score = _alphabeta(
        board,
        size,
        winLength,
        next,
        aiPlayer,
        depth - 1,
        true,
        alpha,
        beta,
      );
      board[cell.$1][cell.$2] = null;
      best = min(best, score);
      beta = min(beta, best);
      if (beta <= alpha) break;
    }
    return best;
  }
}

(int, int) _bestMove(
  List<List<TicTacToePlayer?>> board,
  int size,
  int winLength,
  TicTacToePlayer aiPlayer,
  int maxDepth,
  Random rng,
) {
  final cells = _orderedEmpty(board, size);
  if (cells.isEmpty) return (0, 0);

  // Check for immediate winning move first
  for (final cell in cells) {
    board[cell.$1][cell.$2] = aiPlayer;
    if (_wouldWin(board, cell.$1, cell.$2, aiPlayer, size, winLength)) {
      board[cell.$1][cell.$2] = null;
      return cell;
    }
    board[cell.$1][cell.$2] = null;
  }

  // Check for must-block move
  final human = aiPlayer == TicTacToePlayer.x
      ? TicTacToePlayer.o
      : TicTacToePlayer.x;
  for (final cell in cells) {
    board[cell.$1][cell.$2] = human;
    if (_wouldWin(board, cell.$1, cell.$2, human, size, winLength)) {
      board[cell.$1][cell.$2] = null;
      return cell;
    }
    board[cell.$1][cell.$2] = null;
  }

  int bestScore = -1000002;
  final bestMoves = <(int, int)>[];
  final next = aiPlayer == TicTacToePlayer.x
      ? TicTacToePlayer.o
      : TicTacToePlayer.x;

  for (final cell in cells) {
    board[cell.$1][cell.$2] = aiPlayer;
    final score = _alphabeta(
      board,
      size,
      winLength,
      next,
      aiPlayer,
      maxDepth - 1,
      false,
      -1000002,
      1000002,
    );
    board[cell.$1][cell.$2] = null;
    if (score > bestScore) {
      bestScore = score;
      bestMoves
        ..clear()
        ..add(cell);
    } else if (score == bestScore) {
      bestMoves.add(cell);
    }
  }

  return bestMoves[rng.nextInt(bestMoves.length)];
}
