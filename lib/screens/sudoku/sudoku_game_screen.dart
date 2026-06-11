import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/sudoku/sudoku_board.dart';
import 'package:common_games/games/sudoku/sudoku_controls.dart';
import 'package:common_games/games/sudoku/sudoku_isolate.dart';
import 'package:common_games/games/sudoku/sudoku_model.dart';
import 'package:common_games/games/sudoku/sudoku_puzzle.dart';
import 'package:common_games/services/haptic_service.dart';
import 'package:common_games/services/settings_service.dart';

/// Full Sudoku play loop: load or generate a puzzle, render the board, route
/// user actions through the model, and persist progress.
class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({
    super.key,
    required this.difficulty,
    required this.saveKey,
    this.initialJson,
  });

  final SudokuDifficulty difficulty;

  /// SharedPreferences key. The setup screen computes this from the
  /// difficulty; tests can pass any string.
  final String saveKey;

  /// When provided, skip generation and restore from this JSON. Used by
  /// the setup screen when the user has a save and the screen is
  /// recreated after a process restart.
  final String? initialJson;

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen>
    with WidgetsBindingObserver {
  SudokuModel? _model;
  int? _selectedIndex;
  bool _notesMode = false;
  final List<({List<int> values, List<Set<int>> notes})> _undoStack = [];
  bool _generating = false;
  String? _generationError;
  Timer? _autosaveDebounce;
  Timer? _clockTimer;
  bool _gameOverShown = false;
  bool _gameLostShown = false;

  /// Cells currently highlighted as "wrong" (entered a non-solution value).
  /// Cleared on correct overwrite, undo, or restart.
  final Set<int> _invalidIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveDebounce?.cancel();
    _clockTimer?.cancel();
    // Save synchronously on the way out. _autosave is best-effort and the
    // user is leaving the screen — don't risk losing progress.
    _saveNow();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The puzzle is effectively paused any time the app isn't foregrounded.
    // The model ticks a 1s timer; freezing it here is required by the spec.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      _setPaused(false);
    }
    // On pause, flush whatever is pending. The debounce timer is also
    // cancelled so we don't double-write.
    if (state == AppLifecycleState.paused) {
      _autosaveDebounce?.cancel();
      _saveNow();
    }
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(widget.saveKey);
    if (saved != null) {
      try {
        _restoreFromJson(saved);
        return;
      } on FormatException {
        await prefs.remove(widget.saveKey);
      } on TypeError {
        await prefs.remove(widget.saveKey);
      }
    }
    await _generatePuzzle();
  }

  void _restoreFromJson(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final model = SudokuModel.fromJson(decoded);
    _applySettingsTo(model);
    setState(() {
      _model = model;
      _generationError = null;
    });
    _startClock();
  }

  Future<void> _generatePuzzle() async {
    setState(() {
      _generating = true;
      _generationError = null;
    });
    try {
      // `Isolate.run` requires a top-level or static function. The wrapper
      // in [sudoku_isolate] handles retries and sanity checks.
      final puzzle = await Isolate.run(
        () => generateSudokuPuzzleOnIsolate(widget.difficulty),
      );
      if (!mounted) return;
      final model = SudokuModel(puzzle);
      _applySettingsTo(model);
      setState(() {
        _model = model;
        _generating = false;
      });
      _startClock();
      unawaited(_saveNow());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generationError = e.toString();
      });
    }
  }

  /// Pushes the current settings-service values onto the freshly created
  /// or restored model. Called by both the generate and restore paths.
  void _applySettingsTo(SudokuModel model) {
    final s = SettingsService.instance;
    model.mistakeChecking = s.sudokuMistakeChecking;
    model.mistakesLimit = s.sudokuMistakesLimit;
  }

  void _onCellSelected(int index) {
    final model = _model;
    if (model == null) return;
    if (model.state is! SudokuPlaying) return;
    if (model.puzzle.isGiven(index)) {
      // Tapping a fixed cell just deselects the current selection — the
      // fixed value is read-only.
      setState(() => _selectedIndex = null);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _pushUndo() {
    final model = _model;
    if (model == null) return;
    _undoStack.add((
      values: List<int>.from(model.values),
      notes: [for (final n in model.notes) Set<int>.from(n)],
    ));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  void _onNumber(int n) {
    final model = _model;
    final index = _selectedIndex;
    if (model == null || index == null) return;
    if (model.puzzle.isGiven(index)) return;
    if (model.state is! SudokuPlaying) return;

    final currentValue = model.values[index];
    final currentNotes = Set<int>.from(model.notes[index]);
    if (currentValue == n && !_notesMode) return;

    _pushUndo();
    if (_notesMode && currentValue == 0) {
      model.toggleNote(index, n);
    } else {
      model.enterValue(index, n);
    }
    _refreshInvalidFor(index);
    setState(() {});

    if (currentValue != model.values[index] ||
        !_setEquals(currentNotes, model.notes[index])) {
      _scheduleAutosave();
    }
    _checkCompletion();
    _checkLoss();
  }

  /// Recomputes whether [index] should be in [_invalidIndexes] after an
  /// edit. A cell is "invalid" when its current value is non-zero and
  /// doesn't match the solution. Erases, correct overwrites, and hint
  /// reveals clear the flag.
  void _refreshInvalidFor(int index) {
    final model = _model;
    if (model == null) {
      _invalidIndexes.remove(index);
      return;
    }
    final v = model.values[index];
    if (v == 0 || v == model.puzzle.solution[index]) {
      _invalidIndexes.remove(index);
    } else {
      _invalidIndexes.add(index);
    }
  }

  void _onErase() {
    final model = _model;
    final index = _selectedIndex;
    if (model == null || index == null) return;
    if (model.puzzle.isGiven(index)) return;
    if (model.state is! SudokuPlaying) return;

    final currentValue = model.values[index];
    if (currentValue == 0 && model.notes[index].isEmpty) return;

    _pushUndo();
    if (currentValue != 0) {
      model.enterValue(index, 0);
    } else {
      // Clear notes. Mutating via toggle.
      final toClear = List<int>.from(model.notes[index]);
      for (final n in toClear) {
        model.toggleNote(index, n);
      }
    }
    _refreshInvalidFor(index);
    setState(() {});
    _scheduleAutosave();
  }

  void _onToggleNotes() {
    setState(() => _notesMode = !_notesMode);
  }

  void _onUndo() {
    if (_undoStack.isEmpty) return;
    final snapshot = _undoStack.removeLast();
    final model = _model;
    if (model == null) return;
    model.restoreSnapshot(values: snapshot.values, notes: snapshot.notes);
    // Recompute invalid flags for every non-given cell. Restore may have
    // changed many values at once.
    for (int i = 0; i < SudokuPuzzle.cellCount; i++) {
      if (!model.puzzle.isGiven(i)) _refreshInvalidFor(i);
    }
    setState(() {});
    _scheduleAutosave();
    _checkCompletion();
  }

  void _onHint() {
    final model = _model;
    final index = _selectedIndex;
    if (model == null || index == null) return;
    if (model.puzzle.isGiven(index)) return;
    if (model.state is! SudokuPlaying) return;

    if (model.values[index] == model.puzzle.solution[index]) return;
    _pushUndo();
    model.revealHint(index);
    _refreshInvalidFor(index);
    setState(() {});
    _scheduleAutosave();
    _checkCompletion();
  }

  void _scheduleAutosave() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  Future<void> _saveNow() async {
    final model = _model;
    if (model == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.saveKey, jsonEncode(model.toJson()));
  }

  void _restart() {
    final model = _model;
    if (model == null) return;
    setState(() {
      model.values; // touch to keep analyzer quiet
    });
    // Wipe and re-generate. Keep the same difficulty.
    _undoStack.clear();
    _invalidIndexes.clear();
    _generationError = null;
    _autosaveDebounce?.cancel();
    _gameOverShown = false;
    _gameLostShown = false;
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.remove(widget.saveKey);
    });
    _generatePuzzle();
  }

  void _checkCompletion() {
    final model = _model;
    if (model == null) return;
    if (model.state is SudokuCompleted && !_gameOverShown) {
      _gameOverShown = true;
      HapticService.onGameOver();
      _autosaveDebounce?.cancel();
      _saveNow().then((_) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(widget.saveKey);
        if (!mounted) return;
        _showCompletionDialog();
      });
    }
  }

  void _checkLoss() {
    final model = _model;
    if (model == null) return;
    if (!model.isAtMistakeLimit || _gameLostShown) return;
    // Only count as "lost" when the model is still playing — a completed
    // puzzle that happens to have hit the limit isn't a loss.
    if (model.state is! SudokuPlaying) return;
    _gameLostShown = true;
    HapticService.onGameOver();
    _autosaveDebounce?.cancel();
    _saveNow().then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(widget.saveKey);
      if (!mounted) return;
      _showLossDialog();
    });
  }

  void _showLossDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final model = _model;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            Icons.sentiment_dissatisfied_outlined,
            size: 48,
            color: colorScheme.error,
          ),
          title: const Text(
            'Too many mistakes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            model == null
                ? 'Better luck on the next one.'
                : 'You hit the limit of '
                      '${model.mistakesLimit} mistakes.\n'
                      'Hints used: ${model.hintsUsed}',
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
                _restart();
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Try a new puzzle'),
            ),
          ],
        );
      },
    );
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final model = _model;
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
            'Puzzle solved!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            model == null
                ? 'Nicely done.'
                : 'Mistakes: ${model.mistakes}\n'
                      'Hints used: ${model.hintsUsed}',
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
                _restart();
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('New puzzle'),
            ),
          ],
        );
      },
    );
  }

  bool _setEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }

  void _startClock() {
    _clockTimer?.cancel();
    // Drive a 1Hz tick into the model. The model itself drops ticks when
    // paused or completed, so this is safe to leave running across the
    // full screen lifetime.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final model = _model;
      if (model == null) return;
      model.tick(1);
      if (mounted) setState(() {});
    });
  }

  void _setPaused(bool paused) {
    final model = _model;
    if (model == null) return;
    if (model.paused == paused) return;
    setState(() {
      model.paused = paused;
    });
  }

  void _togglePause() {
    final model = _model;
    if (model == null) return;
    if (model.state is! SudokuPlaying) return;
    setState(() {
      model.paused = !model.paused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return Scaffold(
      appBar: AppBar(
        title: Text('Sudoku · ${widget.difficulty.name}'),
        actions: [
          IconButton(
            key: const ValueKey('sudoku_pause_button'),
            icon: Icon(
              model?.paused == true
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
            ),
            tooltip: model?.paused == true ? 'Resume' : 'Pause',
            onPressed:
                model == null ||
                    model.state is! SudokuPlaying ||
                    model.isAtMistakeLimit
                ? null
                : _togglePause,
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Hint',
            onPressed:
                model == null ||
                    _selectedIndex == null ||
                    model.paused ||
                    model.isAtMistakeLimit
                ? null
                : _onHint,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Restart',
            onPressed: model == null ? null : _restart,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_model == null) {
      if (_generating) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating puzzle…'),
            ],
          ),
        );
      }
      if (_generationError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not generate a puzzle.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _generationError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _generatePuzzle,
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return _buildGame(context);
  }

  Widget _buildGame(BuildContext context) {
    final model = _model!;
    final canEdit = model.state is SudokuPlaying;
    final selected = _selectedIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        const padHorizontal = 16.0;
        final boardSize = constraints.maxWidth - padHorizontal * 2;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _StatPill(
                      icon: Icons.close,
                      label: 'Mistakes',
                      value: '${model.mistakes}',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  Flexible(
                    child: _StatPill(
                      key: const ValueKey('sudoku_timer_pill'),
                      icon: model.paused
                          ? Icons.pause_rounded
                          : Icons.timer_outlined,
                      label: model.paused ? 'Paused' : 'Time',
                      value: _formatElapsed(model.elapsedSeconds),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Flexible(
                    child: _StatPill(
                      icon: Icons.lightbulb_outline,
                      label: 'Hints',
                      value: '${model.hintsUsed}',
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: padHorizontal),
              child: SudokuBoard(
                model: model,
                selectedIndex: selected,
                notesMode: _notesMode,
                invalidIndexes: _invalidIndexes,
                onCellSelected: _onCellSelected,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: padHorizontal),
              child: SudokuControls(
                canEdit:
                    canEdit &&
                    selected != null &&
                    !model.puzzle.isGiven(selected) &&
                    !model.paused &&
                    !model.isAtMistakeLimit,
                notesMode: _notesMode,
                canUndo: _undoStack.isNotEmpty,
                onNumber: _onNumber,
                onErase: _onErase,
                onToggleNotes: _onToggleNotes,
                onUndo: _onUndo,
              ),
            ),
            // Reserve the minimum board height (used for layout on
            // small phones) so the board is exactly the available width.
            SizedBox(width: boardSize, height: 0),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

String _formatElapsed(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$label: $value',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
