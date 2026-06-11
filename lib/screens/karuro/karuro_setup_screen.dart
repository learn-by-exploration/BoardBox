import 'package:flutter/material.dart';

import 'package:common_games/games/karuro/karuro_assets.dart';
import 'package:common_games/games/karuro/karuro_puzzle.dart';
import 'package:common_games/screens/karuro/karuro_game_screen.dart';

/// Pick a Karuro puzzle to play. The bundled library is grouped by
/// difficulty; each tile shows the puzzle's title and grid size. Tapping
/// a tile opens the game screen with that puzzle.
class KaruroSetupScreen extends StatefulWidget {
  const KaruroSetupScreen({super.key});

  static final KaruroAssets assets = KaruroAssets();

  @override
  State<KaruroSetupScreen> createState() => _KaruroSetupScreenState();
}

class _KaruroSetupScreenState extends State<KaruroSetupScreen> {
  late Future<List<KaruroPuzzle>> _puzzles;

  @override
  void initState() {
    super.initState();
    _puzzles = KaruroSetupScreen.assets.all();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karuro')),
      body: SafeArea(
        child: FutureBuilder<List<KaruroPuzzle>>(
          future: _puzzles,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(error: snapshot.error.toString());
            }
            final puzzles = snapshot.data ?? const <KaruroPuzzle>[];
            return _PuzzleList(puzzles: puzzles);
          },
        ),
      ),
    );
  }
}

class _PuzzleList extends StatelessWidget {
  const _PuzzleList({required this.puzzles});

  final List<KaruroPuzzle> puzzles;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (puzzles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No Karuro puzzles bundled yet.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final byDifficulty = <KaruroDifficulty, List<KaruroPuzzle>>{};
    for (final p in puzzles) {
      byDifficulty.putIfAbsent(p.difficulty, () => <KaruroPuzzle>[]).add(p);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final difficulty in KaruroDifficulty.values)
          if (byDifficulty[difficulty]?.isNotEmpty ?? false) ...[
            _SectionHeader(
              title: _difficultyTitle(difficulty),
              color: _colorFor(difficulty),
            ),
            const SizedBox(height: 8),
            for (final p in byDifficulty[difficulty]!) ...[
              _PuzzleTile(puzzle: p, color: _colorFor(difficulty)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  static String _difficultyTitle(KaruroDifficulty d) => switch (d) {
    KaruroDifficulty.easy => 'Easy',
    KaruroDifficulty.medium => 'Medium',
    KaruroDifficulty.hard => 'Hard',
  };

  static Color _colorFor(KaruroDifficulty d) => switch (d) {
    KaruroDifficulty.easy => const Color(0xFF2E7D32),
    KaruroDifficulty.medium => const Color(0xFFEF6C00),
    KaruroDifficulty.hard => const Color(0xFFC62828),
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({required this.puzzle, required this.color});

  final KaruroPuzzle puzzle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final numericRuns = puzzle.entries.whereType<KaruroNumberEntry>().length;
    final wordRuns = puzzle.entries.whereType<KaruroWordEntry>().length;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _open(context),
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
                child: Icon(Icons.grid_4x4_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      puzzle.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${puzzle.rows}×${puzzle.cols}  ·  '
                      '$numericRuns numeric, $wordRuns word',
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

  Future<void> _open(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => KaruroGameScreen(puzzle: puzzle)),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load Karuro puzzles.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
