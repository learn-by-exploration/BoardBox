import 'package:flutter/material.dart';

import 'package:common_games/screens/mode_select_screen.dart';
import 'package:common_games/screens/settings_screen.dart';

enum GameType { gomoku, othello, checkers, dotsAndBoxes, tictactoe }

class _GameInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final GameType gameType;
  final String description;

  const _GameInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gameType,
    required this.description,
  });
}

const _games = [
  _GameInfo(
    title: 'Gomoku',
    subtitle: 'Five in a Row',
    icon: Icons.grid_on,
    color: Color(0xFFDEB887),
    gameType: GameType.gomoku,
    description: 'Place stones to get five in a row on a 15×15 board.',
  ),
  _GameInfo(
    title: 'Othello',
    subtitle: 'Reversi',
    icon: Icons.circle,
    color: Color(0xFF2E7D32),
    gameType: GameType.othello,
    description: 'Flip your opponent\'s discs by trapping them on an 8×8 board.',
  ),
  _GameInfo(
    title: 'Checkers',
    subtitle: 'English Draughts',
    icon: Icons.check_circle_outline,
    color: Color(0xFF769656),
    gameType: GameType.checkers,
    description: 'Jump and capture all your opponent\'s pieces on an 8×8 board.',
  ),
  _GameInfo(
    title: 'Dots & Boxes',
    subtitle: 'Capture Boxes',
    icon: Icons.border_all,
    color: Color(0xFF607D8B),
    gameType: GameType.dotsAndBoxes,
    description: 'Draw lines between dots to complete boxes on a 5×5 grid.',
  ),
  _GameInfo(
    title: 'Tic Tac Toe',
    subtitle: 'X vs O',
    icon: Icons.grid_3x3_rounded,
    color: Color(0xFF7B61FF),
    gameType: GameType.tictactoe,
    description: 'Get 3 or 4 in a row — choose 3×3, 4×4, or 5×5 board.',
  ),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Board Box'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: 'About',
                onPressed: () => _showAbout(context),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _GameTile(info: _games[index]),
                childCount: _games.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: Text(
                  'Tap a game to start playing',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Board Box',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.games_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      children: const [
        Text('Classic board games you can play alone against the '
            'computer or with a friend on the same device.'),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  final _GameInfo info;

  const _GameTile({required this.info});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: info.color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  ModeSelectScreen(gameType: info.gameType, title: info.title),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                info.color.withValues(alpha: 0.05),
                info.color.withValues(alpha: 0.12),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: info.color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(info.icon, color: info.color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                info.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                info.subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: info.color,
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                info.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
