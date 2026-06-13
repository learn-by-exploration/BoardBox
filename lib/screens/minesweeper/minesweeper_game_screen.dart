import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/minesweeper/minesweeper_board.dart';
import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/services/game_stats.dart';
import 'package:common_games/services/haptic_service.dart';

/// Full Minesweeper play loop. Loads (or deals) a model, renders the
/// board, drives a 1Hz clock, and persists progress to
/// SharedPreferences.
///
/// Save key: `minesweeper_save_<difficulty.name>` — one per difficulty
/// so the player can keep three games in flight (Beginner /
/// Intermediate / Expert) and return to each independently. Holds the
/// full model state including the seed and elapsed timer, so a
/// backgrounded game returns to the exact same position.
class MinesweeperGameScreen extends StatefulWidget {
  const MinesweeperGameScreen({super.key, required this.difficulty});

  final MinesweeperDifficulty difficulty;

  /// Per-difficulty save key. Exposed for tests.
  static String saveKeyFor(MinesweeperDifficulty d) =>
      'minesweeper_save_${d.name}';

  @override
  State<MinesweeperGameScreen> createState() => _MinesweeperGameScreenState();
}

class _MinesweeperGameScreenState extends State<MinesweeperGameScreen> {
  MinesweeperModel? _model;
  Timer? _clockTimer;
  bool _outcomeShown = false;

  String get _saveKey => MinesweeperGameScreen.saveKeyFor(widget.difficulty);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_saveKey);
    if (saved != null) {
      try {
        _restoreFromJson(saved);
        _startClock();
        return;
      } on FormatException {
        await prefs.remove(_saveKey);
      } on TypeError {
        await prefs.remove(_saveKey);
      }
    }
    _startNewModel();
  }

  void _restoreFromJson(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    // The save embeds the difficulty; verify it matches the screen's
    // expected difficulty before re-hydrating.
    if (decoded['difficulty'] != widget.difficulty.name) {
      throw const FormatException('Save difficulty does not match screen');
    }
    final model = MinesweeperModel.fromJson(decoded);
    setState(() {
      _model = model;
      _outcomeShown = model.state is! MinesweeperPlaying;
    });
  }

  void _startNewModel() {
    setState(() {
      _model = MinesweeperModel.deal(difficulty: widget.difficulty);
      _outcomeShown = false;
    });
    _startClock();
    _saveNow();
  }

  void _onReset() {
    HapticService.onSelect();
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.remove(_saveKey);
    });
    _startNewModel();
  }

  void _onBoardChanged() {
    final model = _model;
    if (model == null) return;
    setState(() {});
    _saveNow();
    if (model.state is! MinesweeperPlaying && !_outcomeShown) {
      _outcomeShown = true;
      _clockTimer?.cancel();
      HapticService.onGameOver();
      _recordOutcomeAndClearSave();
      _showOutcomeDialog();
    }
  }

  Future<void> _recordOutcomeAndClearSave() async {
    final model = _model;
    if (model == null) return;
    if (model.state is MinesweeperWon) {
      await GameStats.instance.recordMinesweeperWin(widget.difficulty);
    } else if (model.state is MinesweeperLost) {
      await GameStats.instance.recordMinesweeperLoss(widget.difficulty);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  Future<void> _saveNow() async {
    final model = _model;
    if (model == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(model.toJson()));
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final model = _model;
      if (model == null) return;
      if (model.state is! MinesweeperPlaying) return;
      model.tick(1);
      if (mounted) setState(() {});
    });
  }

  IconData _faceIcon() {
    final model = _model;
    if (model == null) return Icons.face_rounded;
    final s = model.state;
    if (s is MinesweeperWon) return Icons.face_4_rounded;
    if (s is MinesweeperLost) return Icons.sentiment_very_dissatisfied;
    return Icons.face_rounded;
  }

  void _showOutcomeDialog() {
    final model = _model;
    if (model == null) return;
    final isWin = model.state is MinesweeperWon;
    final seconds = model.elapsedSeconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
              isWin
                  ? Icons.celebration_outlined
                  : Icons.sentiment_very_dissatisfied_outlined,
              size: 48,
              color: isWin ? colorScheme.primary : colorScheme.error,
            ),
            title: Text(
              isWin ? 'You won!' : 'Boom!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              isWin
                  ? 'Time: ${_formatTime(seconds)}'
                  : 'Time survived: ${_formatTime(seconds)}\n'
                        'Better luck next time.',
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
                  _onReset();
                },
                icon: const Icon(Icons.replay_rounded),
                label: const Text('New game'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return Scaffold(
      appBar: AppBar(
        title: Text('Minesweeper · ${widget.difficulty.label}'),
        actions: [
          IconButton(
            key: const ValueKey('minesweeper_reset'),
            tooltip: 'Reset board',
            icon: Icon(_faceIcon()),
            onPressed: model == null ? null : _onReset,
            // Material IconButton defaults to 48dp; this label lets
            // the screen reader announce the action verb explicitly.
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

  Widget _buildBody(BuildContext context, MinesweeperModel model) {
    return Column(
      children: [
        _StatusBar(model: model),
        const SizedBox(height: 8),
        Expanded(
          child: MinesweeperBoard(
            model: model,
            onModelChanged: (_) => _onBoardChanged(),
          ),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.model});

  final MinesweeperModel model;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final remaining = (model.totalMines - model.flagCount).clamp(0, 999);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _Pill(
            key: const ValueKey('minesweeper_mine_counter'),
            icon: Icons.warning_amber_rounded,
            label: '$remaining',
            semanticsLabel: 'Mines remaining: $remaining',
            color: colorScheme.error,
          ),
          const Spacer(),
          _Pill(
            key: const ValueKey('minesweeper_timer'),
            icon: Icons.timer_outlined,
            label: _formatTime(model.elapsedSeconds),
            semanticsLabel: 'Time: ${_formatTime(model.elapsedSeconds)}',
            color: colorScheme.primary,
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
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// Spoken-form label. When set, the pill is wrapped in a
  /// [Semantics] widget that announces this string instead of
  /// reading the inner `Text` + `Icon` separately.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel ?? label,
      excludeSemantics: semanticsLabel != null,
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
