import 'package:flutter/material.dart';

import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/screens/minesweeper/minesweeper_game_screen.dart';
import 'package:common_games/services/game_stats.dart';

/// Pick a Minesweeper difficulty. Three hero cards, one per preset
/// (Beginner / Intermediate / Expert). Each card has a Play button
/// that opens the game screen. Below the cards, a stats summary
/// shows per-difficulty wins + losses from [GameStats].
class MinesweeperSetupScreen extends StatelessWidget {
  const MinesweeperSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minesweeper')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            for (final d in MinesweeperDifficulty.values) ...[
              _DifficultyCard(difficulty: d),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            const _StatsCard(key: _StatsCard.widgetKey),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({required this.difficulty});

  final MinesweeperDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(difficulty);
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle =
        '${difficulty.rows}×${difficulty.cols}  ·  '
        '${difficulty.mineCount} mines';
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(difficulty), color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: ValueKey('minesweeper_new_game_${difficulty.name}'),
                onPressed: () => _open(context),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text('Play ${difficulty.label}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MinesweeperGameScreen(difficulty: difficulty),
      ),
    );
  }
}

class _StatsCard extends StatefulWidget {
  const _StatsCard({super.key});

  @override
  State<_StatsCard> createState() => _StatsCardState();

  /// Pre-built key for tests to find the widget instance. Tests
  /// use `find.byKey(StatsCardAccess.widgetKey)` to look up the
  /// [State] of the rendered card.
  @visibleForTesting
  static const Key widgetKey = ValueKey('minesweeper_stats_card');
}

/// Public type alias of the private [_StatsCard] widget for tests. The
/// alias preserves the binding to [_StatsCard.cardKey] without making
/// the implementation class part of the public API.
@visibleForTesting
typedef StatsCardAccess = _StatsCard;

/// Public type alias of the private [_StatsCardState] for tests. The
/// alias preserves the name binding without leaking the implementation
/// class — anything outside this file that does
/// `tester.state<StatsCardStateAccess>(...)` is using the alias.
@visibleForTesting
typedef StatsCardStateAccess = _StatsCardState;

class _StatsCardState extends State<_StatsCard> {
  /// Two parallel maps keyed by [MinesweeperDifficulty]. `null` means
  /// "not yet read from SharedPreferences"; the card paints a placeholder
  /// while the read is in-flight so the first frame doesn't claim "0W/0L"
  /// for a difficulty the user has actually played.
  final Map<MinesweeperDifficulty, int> _wins = {};
  final Map<MinesweeperDifficulty, int> _losses = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Returns a [Future] that completes once the SharedPreferences read
  /// initiated in [initState] has settled (and the state has been
  /// rebuilt with the result). Tests step into [runAsync] and await
  /// this so the assertion below sees the post-load widget tree.
  @visibleForTesting
  Future<void> loadFuture() => _loadStats();

  Future<void> _loadStats() async {
    final stats = GameStats.instance;
    final w = <MinesweeperDifficulty, int>{};
    final l = <MinesweeperDifficulty, int>{};
    for (final d in MinesweeperDifficulty.values) {
      w[d] = await stats.getMinesweeperWins(d);
      l[d] = await stats.getMinesweeperLosses(d);
    }
    if (!mounted) return;
    setState(() {
      _wins
        ..clear()
        ..addAll(w);
      _losses
        ..clear()
        ..addAll(l);
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = <String>[];
    for (final d in MinesweeperDifficulty.values) {
      final wins = _wins[d] ?? 0;
      final losses = _losses[d] ?? 0;
      if (wins == 0 && losses == 0) {
        parts.add('${d.label} –');
      } else {
        parts.add('${d.label} ${wins}W/${losses}L');
      }
    }
    final hasAny = parts.any((p) => !p.endsWith('–') && !p.endsWith(' 0W/0L'));
    final body = hasAny
        ? parts.join('  ·  ')
        : 'Pick a difficulty to start your first game.';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _loaded
                      ? null
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(MinesweeperDifficulty d) => switch (d) {
  MinesweeperDifficulty.beginner => Icons.grid_on_rounded,
  MinesweeperDifficulty.intermediate => Icons.grid_4x4_rounded,
  MinesweeperDifficulty.expert => Icons.warning_amber_rounded,
};

Color _colorFor(MinesweeperDifficulty d) => switch (d) {
  MinesweeperDifficulty.beginner => const Color(0xFF2E7D32),
  MinesweeperDifficulty.intermediate => const Color(0xFFEF6C00),
  MinesweeperDifficulty.expert => const Color(0xFFC62828),
};
