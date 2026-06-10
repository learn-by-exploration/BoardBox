import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/sudoku/sudoku_puzzle.dart';
import 'package:common_games/screens/sudoku/sudoku_game_screen.dart';

/// Pick a difficulty and either resume a saved puzzle or start a new one.
/// The save key matches the one in [SudokuGameScreen].
class SudokuSetupScreen extends StatelessWidget {
  const SudokuSetupScreen({super.key});

  static const _saveKeyPrefix = 'sudoku_save_';

  static String _saveKey(SudokuDifficulty d) => '$_saveKeyPrefix${d.name}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick a difficulty',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Engine-rated puzzles. Each save slot holds one in-progress '
                'puzzle per difficulty.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: SudokuDifficulty.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final difficulty = SudokuDifficulty.values[index];
                    return _DifficultyTile(
                      difficulty: difficulty,
                      saveKey: _saveKey(difficulty),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({required this.difficulty, required this.saveKey});

  final SudokuDifficulty difficulty;
  final String saveKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _colorFor(difficulty);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _open(context, newGame: true),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(difficulty), color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty.name[0].toUpperCase() +
                          difficulty.name.substring(1),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _description(difficulty),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  static Color _colorFor(SudokuDifficulty d) => switch (d) {
    SudokuDifficulty.easy => const Color(0xFF2E7D32),
    SudokuDifficulty.medium => const Color(0xFFEF6C00),
    SudokuDifficulty.hard => const Color(0xFFC62828),
  };

  static IconData _iconFor(SudokuDifficulty d) => switch (d) {
    SudokuDifficulty.easy => Icons.sentiment_very_satisfied_outlined,
    SudokuDifficulty.medium => Icons.bolt_outlined,
    SudokuDifficulty.hard => Icons.local_fire_department_outlined,
  };

  static String _description(SudokuDifficulty d) => switch (d) {
    SudokuDifficulty.easy => 'Lots of givens. Good warm-up.',
    SudokuDifficulty.medium => 'A balanced challenge.',
    SudokuDifficulty.hard => 'Fewer givens. Sharp focus required.',
  };

  Future<void> _open(BuildContext context, {required bool newGame}) async {
    if (!newGame) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(saveKey) == null) return;
      if (!context.mounted) return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SudokuGameScreen(difficulty: difficulty, saveKey: saveKey),
      ),
    );
  }
}
