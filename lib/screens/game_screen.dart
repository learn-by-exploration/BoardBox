import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/checkers/checkers_board.dart';
import 'package:common_games/games/dots_and_boxes/dots_board.dart';
import 'package:common_games/games/gomoku/gomoku_board.dart';
import 'package:common_games/games/othello/othello_board.dart';
import 'package:common_games/games/tictactoe/tictactoe_board.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/screens/home_screen.dart';
import 'package:common_games/services/game_stats.dart';

class GameScreen extends StatefulWidget {
  final GameType gameType;
  final String title;
  final GameMode mode;
  final AiDifficulty difficulty;
  final int boardSize;

  const GameScreen({
    super.key,
    required this.gameType,
    required this.title,
    required this.mode,
    this.difficulty = AiDifficulty.medium,
    this.boardSize = 3,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  int _boardKey = 0;
  bool _gameOverShown = false;

  /// Notifier used by board widgets to expose their undo callback.
  /// When non-null, the AppBar undo button is enabled.
  final ValueNotifier<VoidCallback?> _undoNotifier = ValueNotifier(null);

  /// Notifier that board widgets update after every move with their model JSON.
  final ValueNotifier<Map<String, dynamic>?> _stateNotifier = ValueNotifier(
    null,
  );

  /// Restored state loaded from SharedPreferences on launch.
  Map<String, dynamic>? _savedState;
  bool _restoreLoaded = false;

  String get _saveKey {
    // Encode mode + difficulty so switching difficulty / mode in
    // single-player doesn't restore a stale board from a previous session.
    final sizePart =
        widget.gameType == GameType.tictactoe ||
            widget.gameType == GameType.dotsAndBoxes
        ? '_${widget.boardSize}'
        : '';
    return 'game_save_'
        '${widget.gameType.name}_'
        '${widget.mode.name}_'
        '${widget.difficulty.name}'
        '$sizePart';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tryRestoreGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _undoNotifier.dispose();
    _stateNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On Android, `paused` and `detached` fire in quick succession when the OS
    // kills the process. Removing the save on `detached` raced with the
    // `paused` save and erased the user's in-progress game. Save on pause,
    // and only clear when the user explicitly restarts.
    if (state == AppLifecycleState.paused) _saveGame();
  }

  Future<void> _tryRestoreGame() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_saveKey);
    Map<String, dynamic>? decodedState;
    if (json != null) {
      try {
        decodedState = jsonDecode(json) as Map<String, dynamic>;
      } on FormatException {
        await prefs.remove(_saveKey);
      } on TypeError {
        await prefs.remove(_saveKey);
      }
    }
    if (!mounted) return;
    setState(() {
      _savedState = decodedState;
      _restoreLoaded = true;
    });
  }

  Future<void> _saveGame() async {
    final state = _stateNotifier.value;
    if (state == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(state));
  }

  Future<void> _clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  void _restartGame() {
    _stateNotifier.value = null;
    _clearSave();
    setState(() {
      _boardKey++;
      _gameOverShown = false; // allow next game-over dialog on the fresh board
      _savedState = null;
      _restoreLoaded = true;
    });
    // Reset undo notifier so the button becomes disabled for the new game
    _undoNotifier.value = null;
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _recordStat(String result) {
    final lower = result.toLowerCase();
    final isDraw = lower.contains('draw') || lower.contains('tie');

    if (isDraw) {
      return GameStats.instance.recordDraw(widget.gameType, widget.difficulty);
    }

    // Each game assigns human to a specific colour/label.
    // Gomoku: human=Black, AI=White
    // Othello: human=Black, AI=White
    // Checkers: human=Red, AI=Black  ← cannot share "black wins" with Gomoku/Othello
    // Dots & Boxes: human=Player 1, AI=Player 2
    final humanWinToken = switch (widget.gameType) {
      GameType.gomoku => 'black wins',
      GameType.othello => 'black wins',
      GameType.checkers => 'red wins',
      GameType.dotsAndBoxes => 'player 1 wins',
      GameType.tictactoe => 'x wins',
    };

    if (lower.contains(humanWinToken)) {
      return GameStats.instance.recordWin(widget.gameType, widget.difficulty);
    }
    return GameStats.instance.recordLoss(widget.gameType, widget.difficulty);
  }

  /// Called by board widgets when the game ends.
  void _onGameOver(String result) {
    if (!mounted || _gameOverShown) return;
    _gameOverShown = true;

    // Record stats for single-player games. Fire-and-forget is safe here:
    // GameStats awaits its own SharedPreferences write internally and the
    // stat is durable even if the user navigates away immediately.
    if (widget.mode == GameMode.singlePlayer) {
      unawaited(_recordStat(result));
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final isDraw =
            result.toLowerCase().contains('draw') ||
            result.toLowerCase().contains('tie');

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            isDraw ? Icons.handshake_outlined : Icons.emoji_events_rounded,
            size: 48,
            color: isDraw ? colorScheme.tertiary : const Color(0xFFFFB300),
          ),
          title: Text(
            isDraw ? 'It\'s a Draw!' : 'Game Over',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(result, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _goHome();
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Home'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _restartGame();
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = widget.mode == GameMode.singlePlayer
        ? 'vs AI (${widget.difficulty.label})'
        : '2 Players';
    final sizeLabel =
        widget.gameType == GameType.tictactoe ||
            widget.gameType == GameType.dotsAndBoxes
        ? '${widget.boardSize}×${widget.boardSize}'
        : null;
    final gameDetailsLabel = sizeLabel == null
        ? modeLabel
        : '$sizeLabel · $modeLabel';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Chip(
            avatar: Icon(
              widget.mode == GameMode.singlePlayer
                  ? Icons.smart_toy_outlined
                  : Icons.people_outline,
              size: 18,
            ),
            label: Text(gameDetailsLabel),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder<VoidCallback?>(
            valueListenable: _undoNotifier,
            builder: (ctx, undoFn, _) {
              if (undoFn == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.undo_rounded),
                tooltip: 'Undo',
                onPressed: undoFn,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Restart',
            onPressed: _restartGame,
          ),
        ],
      ),
      body: SafeArea(
        child: _restoreLoaded
            ? _buildBoard()
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildBoard() {
    switch (widget.gameType) {
      case GameType.gomoku:
        return GomokuBoard(
          key: ValueKey(_boardKey),
          mode: widget.mode,
          difficulty: widget.difficulty,
          onGameOver: _onGameOver,
          undoNotifier: _undoNotifier,
          stateNotifier: _stateNotifier,
          initialState: _savedState,
        );
      case GameType.othello:
        return OthelloBoard(
          key: ValueKey(_boardKey),
          mode: widget.mode,
          difficulty: widget.difficulty,
          onGameOver: _onGameOver,
          undoNotifier: _undoNotifier,
          stateNotifier: _stateNotifier,
          initialState: _savedState,
        );
      case GameType.checkers:
        return CheckersBoard(
          key: ValueKey(_boardKey),
          mode: widget.mode,
          difficulty: widget.difficulty,
          onGameOver: _onGameOver,
          undoNotifier: _undoNotifier,
          stateNotifier: _stateNotifier,
          initialState: _savedState,
        );
      case GameType.dotsAndBoxes:
        return DotsBoard(
          key: ValueKey(_boardKey),
          mode: widget.mode,
          boardSize: widget.boardSize,
          difficulty: widget.difficulty,
          onGameOver: _onGameOver,
          undoNotifier: _undoNotifier,
          stateNotifier: _stateNotifier,
          initialState: _savedState,
        );
      case GameType.tictactoe:
        return TicTacToeBoard(
          key: ValueKey(_boardKey),
          mode: widget.mode,
          boardSize: widget.boardSize,
          difficulty: widget.difficulty,
          onGameOver: _onGameOver,
          undoNotifier: _undoNotifier,
          stateNotifier: _stateNotifier,
          initialState: _savedState,
        );
    }
  }
}
