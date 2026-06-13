import 'package:flutter/material.dart';

import 'package:common_games/screens/klondike/klondike_game_screen.dart';
import 'package:common_games/services/game_stats.dart';

/// Klondike has only one mode (draw-1) and no difficulty knob in v1, so
/// the setup screen is a single hero card with a "New game" button. The
/// screen doubles as the home for the win counter so the user can see
/// their progress from the catalog.
class KlondikeSetupScreen extends StatefulWidget {
  const KlondikeSetupScreen({super.key});

  @override
  State<KlondikeSetupScreen> createState() => _KlondikeSetupScreenState();
}

class _KlondikeSetupScreenState extends State<KlondikeSetupScreen> {
  int _wins = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadWins();
  }

  Future<void> _loadWins() async {
    final w = await GameStats.instance.getKlondikeWins();
    if (!mounted) return;
    setState(() {
      _wins = w;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Klondike')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1B5E20).withValues(alpha: 0.10),
                      const Color(0xFF1B5E20).withValues(alpha: 0.20),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.style_outlined,
                        color: Color(0xFF1B5E20),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Klondike Solitaire',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Draw-1 · Classic · No redeal limit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('klondike_new_game_button'),
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const KlondikeGameScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('New game'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Show a placeholder while the read is in-flight so the first
              // frame doesn't paint the wrong total. The real value lands
              // on the same frame as the splash fades; see GameStats.ready.
              _WinsCard(wins: _loaded ? _wins : 0, dimmed: !_loaded),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinsCard extends StatelessWidget {
  const _WinsCard({required this.wins, this.dimmed = false});

  final int wins;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            Icon(Icons.emoji_events_outlined, color: colorScheme.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wins',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    wins == 0
                        ? 'No wins yet — flip your first card.'
                        : '$wins ${wins == 1 ? "win" : "wins"}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: dimmed
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
