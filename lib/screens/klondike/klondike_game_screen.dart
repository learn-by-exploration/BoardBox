import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/klondike/klondike_ai.dart';
import 'package:common_games/games/klondike/klondike_board.dart';
import 'package:common_games/games/klondike/klondike_model.dart';
import 'package:common_games/services/game_stats.dart';
import 'package:common_games/services/haptic_service.dart';

/// Full Klondike play loop. Loads (or deals) a model, renders the board,
/// routes user actions, and persists progress to SharedPreferences.
///
/// Save key: `klondike_save`. Holds the full model state including the
/// seed and elapsed timer, so a backgrounded game returns to the
/// exact same position.
class KlondikeGameScreen extends StatefulWidget {
  const KlondikeGameScreen({super.key});

  static const String saveKey = 'klondike_save';

  @override
  State<KlondikeGameScreen> createState() => _KlondikeGameScreenState();
}

class _KlondikeGameScreenState extends State<KlondikeGameScreen>
    with WidgetsBindingObserver {
  KlondikeModel? _model;
  Timer? _clockTimer;
  Timer? _autoCompleteTimer;
  bool _wonShown = false;
  bool _autoCompleting = false;

  static const String _newGameKey = 'klondike_new_game';
  static const String _hintKey = 'klondike_hint';
  static const String _undoKey = 'klondike_undo';
  static const String _backKey = 'klondike_back';
  static const String _timerPillKey = 'klondike_timer_pill';
  static const String _movesPillKey = 'klondike_moves_pill';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _autoCompleteTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the move clock any time the app isn't foregrounded. The
    // 1Hz [Timer.periodic] would otherwise keep ticking and inflate
    // the elapsed timer while the user is in another app.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _clockTimer?.cancel();
      unawaited(_saveNow());
    } else if (state == AppLifecycleState.resumed) {
      _startClock();
    }
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(KlondikeGameScreen.saveKey);
    if (saved != null) {
      try {
        _restoreFromJson(saved);
        _startClock();
        _maybeAutoComplete();
        return;
      } on FormatException {
        await prefs.remove(KlondikeGameScreen.saveKey);
      } on TypeError {
        await prefs.remove(KlondikeGameScreen.saveKey);
      }
    }
    _startNewModel();
  }

  void _restoreFromJson(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final model = KlondikeModel.fromJson(decoded);
    setState(() {
      _model = model;
      _wonShown = model.state is KlondikeWon;
    });
  }

  void _startNewModel() {
    setState(() {
      _model = KlondikeModel.deal();
      _wonShown = false;
    });
    _startClock();
    _saveNow();
  }

  /// Clear the persisted Klondike save. Awaited so the in-flight
  /// `prefs.remove` cannot lose to a subsequent `_saveNow()` triggered
  /// by the new game starting in `_onNewGame`.
  Future<void> _clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(KlondikeGameScreen.saveKey);
  }

  void _onNewGame() {
    HapticService.onSelect();
    unawaited(_clearSave());
    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = null;
    setState(() {
      _model = KlondikeModel.deal();
      _wonShown = false;
    });
    _startClock();
    _saveNow();
  }

  void _onHint() {
    final model = _model;
    if (model == null) return;
    if (model.state is! KlondikePlaying) return;
    final move = KlondikeHint.findValidMove(model);
    if (move == null) {
      HapticService.onError();
      return;
    }
    // For tableau-to-tableau moves the model's tapTableau API needs the
    // source tap first (to select) then the destination tap. Apply the
    // move via the AI helper to keep the timing correct.
    final applied = applyKlondikeMove(model, move);
    if (applied) {
      HapticService.onMove();
      setState(() {});
      _saveNow();
      _checkWin();
      _maybeAutoComplete();
    } else {
      HapticService.onError();
    }
  }

  void _onUndo() {
    final model = _model;
    if (model == null) return;
    if (model.state is! KlondikePlaying) return;
    if (model.undo()) {
      HapticService.onMove();
      _saveNow();
      setState(() {});
      // Undo may have left the model in a non-auto-complete state.
      _stopAutoComplete();
    }
  }

  void _onBoardChanged() {
    // Hook called by KlondikeBoard after a tap-driven mutation. Persist
    // and re-evaluate auto-complete.
    setState(() {});
    _saveNow();
    _checkWin();
    _maybeAutoComplete();
  }

  void _onBack() {
    Navigator.of(context).pop();
  }

  Future<void> _saveNow() async {
    final model = _model;
    if (model == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      KlondikeGameScreen.saveKey,
      jsonEncode(model.toJson()),
    );
  }

  void _checkWin() {
    final model = _model;
    if (model == null) return;
    if (model.state is KlondikeWon && !_wonShown) {
      _wonShown = true;
      HapticService.onGameOver();
      GameStats.instance.recordKlondikeWin();
      unawaited(_clearSave());
      _stopAutoComplete();
      _clockTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWinDialog();
      });
    }
  }

  void _showWinDialog() {
    final model = _model;
    final moves = model?.moves ?? 0;
    final seconds = model?.elapsedSeconds ?? 0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            Icons.celebration_outlined,
            size: 48,
            color: colorScheme.primary,
          ),
          title: const Text(
            'You won!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Moves: $moves\n'
            'Time: ${_formatTime(seconds)}',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Home'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _onNewGame();
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('New game'),
            ),
          ],
        );
      },
    );
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final model = _model;
      if (model == null) return;
      if (model.state is! KlondikePlaying) return;
      model.elapsedSeconds += 1;
      if (mounted) setState(() {});
    });
  }

  void _maybeAutoComplete() {
    final model = _model;
    if (model == null) return;
    if (!KlondikeAutoComplete.canAutoComplete(model)) {
      _stopAutoComplete();
      return;
    }
    if (_autoCompleting) return;
    _autoCompleting = true;
    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final m = _model;
      if (m == null) return;
      if (!KlondikeAutoComplete.canAutoComplete(m)) {
        _stopAutoComplete();
        return;
      }
      // Play any top-card that fits a foundation.
      var madeMove = false;
      for (var c = 0; c < 7; c++) {
        final pile = m.tableau[c];
        if (pile.isEmpty) continue;
        final top = pile.top.card;
        for (var f = 0; f < 4; f++) {
          if (_canMoveToFoundationAuto(top, m.foundations[f])) {
            m.tapTableauToFoundation(c, pile.length - 1, f);
            madeMove = true;
            break;
          }
        }
        if (madeMove) break;
      }
      if (!madeMove) {
        _stopAutoComplete();
        return;
      }
      HapticService.onSelect();
      setState(() {});
      _saveNow();
      _checkWin();
    });
  }

  void _stopAutoComplete() {
    _autoCompleting = false;
    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klondike'),
        actions: [
          IconButton(
            key: const ValueKey(_newGameKey),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'New game',
            onPressed: model == null ? null : _onNewGame,
          ),
          IconButton(
            key: const ValueKey(_hintKey),
            icon: const Icon(Icons.lightbulb_outline_rounded),
            tooltip: 'Hint',
            onPressed: model == null ? null : _onHint,
          ),
          IconButton(
            key: const ValueKey(_undoKey),
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: model == null || !model.canUndo ? null : _onUndo,
          ),
        ],
      ),
      body: SafeArea(
        child: model == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, model),
      ),
    );
  }

  Widget _buildBody(BuildContext context, KlondikeModel model) {
    return Column(
      children: [
        _StatusBar(
          model: model,
          timerKey: _timerPillKey,
          movesKey: _movesPillKey,
          autoCompleting: _autoCompleting,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: KlondikeBoard(
            model: model,
            onModelChanged: (_) => _onBoardChanged(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey(_backKey),
              onPressed: _onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.model,
    required this.timerKey,
    required this.movesKey,
    required this.autoCompleting,
  });

  final KlondikeModel model;
  final String timerKey;
  final String movesKey;
  final bool autoCompleting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _Pill(
            key: const ValueKey('klondike_timer_pill'),
            icon: Icons.timer_outlined,
            label: _formatTime(model.elapsedSeconds),
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          _Pill(
            key: const ValueKey('klondike_moves_pill'),
            icon: Icons.swap_horiz_rounded,
            label: '${model.moves}',
            color: colorScheme.tertiary,
          ),
          const Spacer(),
          if (autoCompleting)
            _Pill(
              icon: Icons.auto_awesome_rounded,
              label: 'Auto-playing…',
              color: colorScheme.secondary,
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

bool _canMoveToFoundationAuto(PlayingCard card, Pile foundation) {
  if (foundation.isEmpty) return card.rank == Rank.ace;
  final top = foundation.top.card;
  return top.suit == card.suit && card.rank.index == top.rank.index + 1;
}
