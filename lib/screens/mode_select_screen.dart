import 'package:flutter/material.dart';

import 'package:common_games/models/game_mode.dart';
import 'package:common_games/screens/game_screen.dart';
import 'package:common_games/screens/home_screen.dart';

const _rules = <GameType, _RulesData>{
  GameType.gomoku: _RulesData(
    objective: 'Get five of your stones in a row — '
        'horizontally, vertically, or diagonally.',
    board: '15 × 15 grid',
    turns: 'Players alternate placing one stone per turn.',
    tips: [
      'Control the center early.',
      'Watch for open threes — they lead to unstoppable fours.',
      'Block your opponent\'s four-in-a-row immediately.',
    ],
  ),
  GameType.othello: _RulesData(
    objective: 'Have the most discs of your colour when the board is full.',
    board: '8 × 8 grid, starts with 4 discs in the centre',
    turns: 'Place a disc to outflank opponent discs and flip them. '
        'If you can\'t move, your turn is skipped.',
    tips: [
      'Corners are the strongest positions — aim for them.',
      'Avoid giving your opponent corner access via edge squares.',
      'Don\'t focus on disc count early; control matters more.',
    ],
  ),
  GameType.checkers: _RulesData(
    objective: 'Capture all opponent pieces or block them so they can\'t move.',
    board: '8 × 8 board with pieces on dark squares',
    turns: 'Move diagonally forward. Captures are mandatory. '
        'Reach the far row to become a King (moves backward too).',
    tips: [
      'Keep your back row as long as possible.',
      'Try to get Kings early — they\'re much more powerful.',
      'Force multiple jumps when you can.',
    ],
  ),
  GameType.dotsAndBoxes: _RulesData(
    objective: 'Complete more boxes than your opponent.',
    board: '5 × 5 dot grid (4 × 4 boxes)',
    turns: 'Draw one line per turn between adjacent dots. '
        'Complete a box to claim it and take another turn.',
    tips: [
      'Avoid drawing the third side of a box unless you want to give it away.',
      'Build long chains and force your opponent to open them.',
      'Count carefully in the endgame — one mistake flips the result.',
    ],
  ),
};

class _RulesData {
  final String objective;
  final String board;
  final String turns;
  final List<String> tips;

  const _RulesData({
    required this.objective,
    required this.board,
    required this.turns,
    required this.tips,
  });
}

class ModeSelectScreen extends StatelessWidget {
  final GameType gameType;
  final String title;

  const ModeSelectScreen({
    super.key,
    required this.gameType,
    required this.title,
  });

  void _startGame(BuildContext context, GameMode mode,
      [AiDifficulty difficulty = AiDifficulty.medium]) {
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          gameType: gameType,
          title: title,
          mode: mode,
          difficulty: difficulty,
        ),
      ),
    );
  }

  void _showDifficultyPicker(BuildContext context) {
    showModalBottomSheet<AiDifficulty>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Difficulty',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ...AiDifficulty.values.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        d == AiDifficulty.easy
                            ? Icons.sentiment_satisfied_alt
                            : d == AiDifficulty.medium
                                ? Icons.psychology_outlined
                                : Icons.local_fire_department,
                        color: d == AiDifficulty.easy
                            ? Colors.green
                            : d == AiDifficulty.medium
                                ? colorScheme.primary
                                : Colors.redAccent,
                      ),
                      title: Text(d.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(d.description),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: colorScheme.surfaceContainerLow,
                      onTap: () => Navigator.pop(ctx, d),
                    ),
                  )),
            ],
          ),
        );
      },
    ).then((difficulty) {
      if (difficulty != null && context.mounted) {
        _startGame(context, GameMode.singlePlayer, difficulty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rules = _rules[gameType]!;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Mode buttons ──
              Text(
                'Choose Mode',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      icon: Icons.smart_toy_outlined,
                      label: '1 Player',
                      subtitle: 'vs Computer',
                      color: colorScheme.primary,
                      onTap: () => _showDifficultyPicker(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeButton(
                      icon: Icons.people_outline,
                      label: '2 Players',
                      subtitle: 'Local',
                      color: colorScheme.tertiary,
                      onTap: () => _startGame(context, GameMode.twoPlayer),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── How to play ──
              Text(
                'How to Play',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.flag_outlined,
                title: 'Objective',
                body: rules.objective,
              ),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.grid_4x4,
                title: 'Board',
                body: rules.board,
              ),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.swap_horiz,
                title: 'Turns',
                body: rules.turns,
              ),
              const SizedBox(height: 20),
              Text(
                'Tips',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...rules.tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tip,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(body, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
