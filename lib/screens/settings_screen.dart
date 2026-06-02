import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/screens/privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showMoveHints = true;
  bool _fastAi = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showMoveHints = prefs.getBool('show_move_hints') ?? true;
      _fastAi = prefs.getBool('fast_ai') ?? false;
    });
  }

  Future<void> _saveShowHints(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_move_hints', value);
    if (!mounted) return;
    setState(() => _showMoveHints = value);
  }

  Future<void> _saveFastAi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_ai', value);
    if (!mounted) return;
    setState(() => _fastAi = value);
  }

  Future<void> _clearStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Statistics?'),
        content: const Text(
            'This will reset all win/loss/draw records. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      // Remove only win/loss/draw keys — do NOT wipe gameplay preferences.
      final statKeys = prefs
          .getKeys()
          .where((k) =>
              k.endsWith('_wins') ||
              k.endsWith('_losses') ||
              k.endsWith('_draws'))
          .toList();
      for (final key in statKeys) {
        await prefs.remove(key);
      }
      if (!mounted) return;
      await _loadPrefs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Statistics cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(title: 'Gameplay'),
          SwitchListTile(
            title: const Text('Show move hints'),
            subtitle: const Text('Highlight valid moves on the board'),
            value: _showMoveHints,
            onChanged: _saveShowHints,
            secondary: Icon(Icons.lightbulb_outline, color: colorScheme.primary),
          ),
          SwitchListTile(
            title: const Text('Fast AI moves'),
            subtitle: const Text('Reduce AI thinking delay'),
            value: _fastAi,
            onChanged: _saveFastAi,
            secondary:
                Icon(Icons.speed_rounded, color: colorScheme.primary),
          ),
          const Divider(),
          const _SectionHeader(title: 'Data'),
          ListTile(
            leading:
                Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            title: const Text('Clear statistics'),
            subtitle: const Text('Reset all win/loss/draw records'),
            onTap: _clearStats,
          ),
          const Divider(),
          const _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Board Box'),
            subtitle: Text('Version 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
