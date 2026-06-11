import 'package:flutter/material.dart';

import 'package:common_games/screens/karuro/karuro_setup_screen.dart';
import 'package:common_games/screens/mode_select_screen.dart';
import 'package:common_games/screens/settings_screen.dart';
import 'package:common_games/screens/sudoku/sudoku_setup_screen.dart';
import 'package:common_games/services/game_stats.dart';

enum GameType { gomoku, othello, checkers, dotsAndBoxes, tictactoe }

class _GameInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final GameType? gameType;
  final String description;

  /// Custom route key. When set, the game opens via its own setup
  /// screen rather than the shared [ModeSelectScreen] / Sudoku flow.
  /// Currently: 'sudoku' and 'karuro'.
  final String? customRoute;

  const _GameInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gameType,
    required this.description,
    this.customRoute,
  });

  /// Sudoku bypasses [GameMode] and goes to its own setup screen.
  bool get isSudoku => customRoute == 'sudoku';

  /// Karuro has its own setup screen with bundled puzzles, like Sudoku.
  bool get isKaruro => customRoute == 'karuro';
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
    description:
        'Flip your opponent\'s discs by trapping them on an 8×8 board.',
  ),
  _GameInfo(
    title: 'Checkers',
    subtitle: 'English Draughts',
    icon: Icons.check_circle_outline,
    color: Color(0xFF769656),
    gameType: GameType.checkers,
    description:
        'Jump and capture all your opponent\'s pieces on an 8×8 board.',
  ),
  _GameInfo(
    title: 'Dots & Boxes',
    subtitle: 'Capture Boxes',
    icon: Icons.border_all,
    color: Color(0xFF607D8B),
    gameType: GameType.dotsAndBoxes,
    description: 'Draw lines and claim boxes on a 5×5, 6×6, or 7×7 grid.',
  ),
  _GameInfo(
    title: 'Tic Tac Toe',
    subtitle: 'X vs O',
    icon: Icons.grid_3x3_rounded,
    color: Color(0xFF7B61FF),
    gameType: GameType.tictactoe,
    description: 'Get 3 or 4 in a row — choose 3×3, 4×4, or 5×5 board.',
  ),
  _GameInfo(
    title: 'Sudoku',
    subtitle: 'Number Logic',
    icon: Icons.calculate_outlined,
    color: Color(0xFF1565C0),
    // Sudoku has its own setup screen (no GameType) — see [_openGame].
    gameType: null,
    customRoute: 'sudoku',
    description:
        'Fill the 9×9 grid so every row, column, and 3×3 box '
        'contains 1 through 9.',
  ),
  _GameInfo(
    title: 'Karuro',
    subtitle: 'Hybrid Puzzle',
    icon: Icons.extension_rounded,
    color: Color(0xFF8E24AA),
    // Karuro has its own setup screen with bundled puzzles.
    gameType: null,
    customRoute: 'karuro',
    description:
        'Cross sums and word clues on the same grid. '
        'Hand-picked puzzles from easy to hard.',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showGrid = true;
  String _query = '';

  List<_GameInfo> get _visibleGames {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _games;
    return _games
        .where(
          (game) =>
              game.title.toLowerCase().contains(query) ||
              game.subtitle.toLowerCase().contains(query) ||
              game.description.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _searchController.clear();
        _query = '';
      }
      _isSearching = !_isSearching;
    });
  }

  Future<void> _openGame(_GameInfo info) async {
    if (info.isSudoku) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SudokuSetupScreen()),
      );
      if (mounted) setState(() {});
      return;
    }
    if (info.isKaruro) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const KaruroSetupScreen()),
      );
      if (mounted) setState(() {});
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ModeSelectScreen(gameType: info.gameType!, title: info.title),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleGames = _visibleGames;

    return Scaffold(
      floatingActionButton: _isSearching
          ? SizedBox(
              width: 300,
              child: Material(
                elevation: 6,
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search games',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      key: const ValueKey('home_search_close_button'),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close search',
                      onPressed: _toggleSearch,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            )
          : FloatingActionButton(
              key: const ValueKey('home_search_button'),
              tooltip: 'Search games',
              onPressed: _toggleSearch,
              child: const Icon(Icons.search_rounded),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            actions: [
              IconButton(
                key: const ValueKey('home_layout_button'),
                icon: Icon(
                  _showGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                ),
                tooltip: _showGrid ? 'Show list' : 'Show grid',
                onPressed: () => setState(() => _showGrid = !_showGrid),
              ),
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
          SliverToBoxAdapter(child: _RecordSummary(stats: GameStats.instance)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Choose a game',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${visibleGames.length} '
                    '${visibleGames.length == 1 ? "game" : "games"}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (visibleGames.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 56),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No games found',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          else if (_showGrid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 900
                      ? 4
                      : constraints.crossAxisExtent >= 600
                      ? 3
                      : 2;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: columns == 2 ? 0.82 : 0.9,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _GameTile(
                        info: visibleGames[index],
                        onTap: () => _openGame(visibleGames[index]),
                      ),
                      childCount: visibleGames.length,
                    ),
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverList.separated(
                itemCount: visibleGames.length,
                itemBuilder: (context, index) => _GameListTile(
                  info: visibleGames[index],
                  onTap: () => _openGame(visibleGames[index]),
                ),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
              ),
            ),
          if (_showGrid && visibleGames.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 64)),
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
        Text(
          'Classic board games you can play alone against the '
          'computer or with a friend on the same device.',
        ),
      ],
    );
  }
}

class _GameRecord {
  const _GameRecord({
    required this.wins,
    required this.draws,
    required this.losses,
  });

  final int wins;
  final int draws;
  final int losses;

  int get played => wins + draws + losses;

  String get label =>
      played == 0 ? 'No matches yet' : '$wins W  ·  $draws D  ·  $losses L';

  static _GameRecord? read(_GameInfo info) {
    if (info.isKaruro) {
      final wins = GameStats.instance.getKaruroWins();
      return _GameRecord(wins: wins, draws: 0, losses: 0);
    }
    final gameType = info.gameType;
    if (gameType == null) return null;
    final stats = GameStats.instance;
    return _GameRecord(
      wins: stats.getTotalWins(gameType),
      draws: stats.getTotalDraws(gameType),
      losses: stats.getTotalLosses(gameType),
    );
  }
}

class _GameListTile extends StatelessWidget {
  const _GameListTile({required this.info, required this.onTap});

  final _GameInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final record = _GameRecord.read(info);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(info.icon, color: info.color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record?.label ?? 'New game — pick a difficulty',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: record == null || record.played == 0
                            ? colorScheme.onSurfaceVariant
                            : info.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: info.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordSummary extends StatelessWidget {
  const _RecordSummary({required this.stats});

  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wins = stats.getAllGamesWins();
    final losses = stats.getAllGamesLosses();
    final draws = stats.getAllGamesDraws();
    final played = wins + losses + draws;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sports_esports_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your board game collection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      played == 0
                          ? 'Pick a game and start your first match'
                          : '$played single-player matches completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _RecordValue(
                  label: 'Wins',
                  value: wins,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              Expanded(
                child: _RecordValue(
                  label: 'Draws',
                  value: draws,
                  color: colorScheme.tertiary,
                ),
              ),
              Expanded(
                child: _RecordValue(
                  label: 'Losses',
                  value: losses,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  final _GameInfo info;
  final VoidCallback onTap;

  const _GameTile({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final record = _GameRecord.read(info);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: info.color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(info.icon, color: info.color, size: 27),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: info.color,
                    size: 20,
                  ),
                ],
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  info.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  info.subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: info.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                info.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  record?.label ?? 'New game — pick a difficulty',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: record == null || record.played == 0
                        ? colorScheme.onSurfaceVariant
                        : info.color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
