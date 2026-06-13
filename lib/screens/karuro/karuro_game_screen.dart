import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/karuro/karuro_board.dart';
import 'package:common_games/games/karuro/karuro_model.dart';
import 'package:common_games/games/karuro/karuro_puzzle.dart';
import 'package:common_games/services/game_stats.dart';
import 'package:common_games/services/haptic_service.dart';

/// Full Karuro play loop. Loads a puzzle, renders the board, routes user
/// actions through the model, and persists progress.
///
/// The puzzle is passed in by the setup screen. Save/restore uses a
/// SharedPreferences key derived from the puzzle id so backgrounding the
/// app mid-puzzle restores the in-progress values on return.
class KaruroGameScreen extends StatefulWidget {
  const KaruroGameScreen({super.key, required this.puzzle});

  final KaruroPuzzle puzzle;

  /// The save key for a given puzzle id.
  static String saveKey(String puzzleId) => 'karuro_save_$puzzleId';

  @override
  State<KaruroGameScreen> createState() => _KaruroGameScreenState();
}

class _KaruroGameScreenState extends State<KaruroGameScreen> {
  /// Characters the user can enter, in display order. Digits first
  /// (1-9), then letters (A-Z). Erase is rendered separately.
  static const List<String> _alphabet = <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  KaruroModel? _model;
  int? _selectedIndex;
  bool _showErrors = true;
  bool _wonShown = false;

  /// Keys for the palette. Defined as statics so the tests can target
  /// them by key without relying on order.
  static const String _toggleErrorsKey = 'karuro_toggle_errors';
  static const String _resetKey = 'karuro_reset';
  static const String _undoKey = 'karuro_undo';
  static const String _backKey = 'karuro_back';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  String get _saveKey => KaruroGameScreen.saveKey(widget.puzzle.id);

  /// Clear the persisted Karuro save. Awaited so the in-flight
  /// `prefs.remove` cannot lose to a subsequent `_saveNow()` triggered
  /// by the new puzzle starting in `_onReset`.
  Future<void> _clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_saveKey);
    if (saved != null) {
      try {
        _restoreFromJson(saved);
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
    final model = KaruroModel.fromJson(decoded, (id) {
      if (id == widget.puzzle.id) return widget.puzzle;
      return null;
    });
    setState(() {
      _model = model;
      _wonShown = model.isWon;
    });
  }

  void _startNewModel() {
    setState(() {
      _model = KaruroModel(widget.puzzle);
      _selectedIndex = null;
      _wonShown = false;
    });
  }

  void _onCellSelected(int index) {
    final model = _model;
    if (model == null) return;
    if (model.state is! KaruroPlaying) return;
    setState(() => _selectedIndex = index);
  }

  void _onEnterChar(String value) {
    final model = _model;
    final index = _selectedIndex;
    if (model == null || index == null) return;
    if (model.state is! KaruroPlaying) return;
    final flatRow = index ~/ widget.puzzle.cols;
    final flatCol = index % widget.puzzle.cols;
    if (model.enterValue(flatRow, flatCol, value)) {
      HapticService.onMove();
      _maybeFlagError(model, flatRow, flatCol, value);
      _saveNow();
    }
    // The model's value is mutated in place; the screen needs to
    // rebuild so the board picks up the new value and the won-state
    // (if any) flows through `_checkWin`.
    setState(() {});
    _checkWin();
  }

  void _onErase() {
    final model = _model;
    final index = _selectedIndex;
    if (model == null || index == null) return;
    if (model.state is! KaruroPlaying) return;
    final flatRow = index ~/ widget.puzzle.cols;
    final flatCol = index % widget.puzzle.cols;
    if (model.erase(flatRow, flatCol)) {
      HapticService.onMove();
      _saveNow();
    }
    setState(() {});
  }

  void _onUndo() {
    final model = _model;
    if (model == null) return;
    if (model.state is! KaruroPlaying) return;
    if (model.undo()) {
      HapticService.onMove();
      _saveNow();
    }
    setState(() {});
  }

  void _onReset() {
    setState(() {
      _selectedIndex = null;
    });
    unawaited(_clearSave());
    _startNewModel();
  }

  void _onBackToList() {
    Navigator.of(context).pop();
  }

  void _onToggleShowErrors() {
    setState(() => _showErrors = !_showErrors);
  }

  void _maybeFlagError(KaruroModel model, int row, int col, String value) {
    if (!_showErrors) return;
    final expected = model.puzzle.solutionAt(row, col);
    if (expected == null) return;
    if (value.toUpperCase() != expected.toUpperCase()) {
      HapticService.onError();
    }
  }

  Future<void> _saveNow() async {
    final model = _model;
    if (model == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(model.toJson()));
  }

  void _checkWin() {
    final model = _model;
    if (model == null) return;
    if (model.isWon && !_wonShown) {
      _wonShown = true;
      HapticService.onGameOver();
      // Record the win for the home-screen counter.
      GameStats.instance.recordKaruroWin();
      // Clear the save on completion so a fresh "new puzzle" starts
      // from a known-empty state. Awaited via [_clearSave] so the
      // remove is bound to a future the screen can't outrun.
      unawaited(_clearSave());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWinDialog();
      });
    }
  }

  void _showWinDialog() {
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
            'Puzzle solved!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '${widget.puzzle.title}\n'
            'Difficulty: ${widget.puzzle.difficulty.name}',
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
              label: const Text('New puzzle'),
            ),
          ],
        );
      },
    );
  }

  /// Indices to tint with the error-container background. Only includes
  /// currently-filled cells that don't match the solution, and only when
  /// the user has "show errors" on.
  Set<int> _invalidIndexes() {
    if (!_showErrors) return const <int>{};
    final model = _model;
    if (model == null) return const <int>{};
    return model.wrongCells();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return Scaffold(
      appBar: AppBar(
        title: Text(model == null ? 'Karuro' : widget.puzzle.title),
        actions: [
          IconButton(
            key: const ValueKey(_toggleErrorsKey),
            icon: Icon(
              _showErrors
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            tooltip: _showErrors ? 'Hide errors' : 'Show errors',
            onPressed: model == null ? null : _onToggleShowErrors,
          ),
          IconButton(
            key: const ValueKey(_resetKey),
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset',
            onPressed: model == null ? null : _onReset,
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

  Widget _buildBody(BuildContext context, KaruroModel model) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          _StatusPill(difficulty: widget.puzzle.difficulty, state: model.state),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: KaruroBoard(
                  model: model,
                  selectedIndex: _selectedIndex,
                  invalidIndexes: _invalidIndexes(),
                  onCellSelected: _onCellSelected,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _InputPalette(
            canEdit: model.state is KaruroPlaying && _selectedIndex != null,
            canUndo: model.canUndo,
            alphabet: _alphabet,
            onChar: _onEnterChar,
            onErase: _onErase,
            onUndo: _onUndo,
            undoKey: _undoKey,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey(_backKey),
              onPressed: _onBackToList,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to puzzles'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.difficulty, required this.state});

  final KaruroDifficulty difficulty;
  final KaruroState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty) {
      KaruroDifficulty.easy => const Color(0xFF2E7D32),
      KaruroDifficulty.medium => const Color(0xFFEF6C00),
      KaruroDifficulty.hard => const Color(0xFFC62828),
    };
    final label = switch (state) {
      KaruroPlaying() => 'Playing',
      KaruroWon() => 'Solved',
    };
    return Semantics(
      container: true,
      label: 'Difficulty: ${difficulty.name}, status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_4x4_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '${difficulty.name[0].toUpperCase()}${difficulty.name.substring(1)}  ·  $label',
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

class _InputPalette extends StatelessWidget {
  const _InputPalette({
    required this.canEdit,
    required this.canUndo,
    required this.alphabet,
    required this.onChar,
    required this.onErase,
    required this.onUndo,
    required this.undoKey,
  });

  final bool canEdit;
  final bool canUndo;
  final List<String> alphabet;
  final ValueChanged<String> onChar;
  final VoidCallback onErase;
  final VoidCallback onUndo;
  final String undoKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final c in alphabet)
              _CharChip(char: c, onTap: canEdit ? () => onChar(c) : null),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PaletteButton(
              icon: Icons.backspace_outlined,
              label: 'Erase',
              onTap: canEdit ? onErase : null,
            ),
            const SizedBox(width: 8),
            _PaletteButton(
              key: ValueKey<String>(undoKey),
              icon: Icons.undo_rounded,
              label: 'Undo',
              onTap: canEdit && canUndo ? onUndo : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _CharChip extends StatelessWidget {
  const _CharChip({required this.char, required this.onTap});

  final String char;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: 'Enter $char',
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: disabled
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                char,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: 96,
        height: 48,
        child: Material(
          color: disabled
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurface),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
