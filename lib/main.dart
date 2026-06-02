import 'package:flutter/material.dart';

import 'package:common_games/screens/splash_screen.dart';
import 'package:common_games/services/game_stats.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameStats.instance.init();
  await SettingsService.instance.init();
  runApp(const CommonGamesApp());
}

class CommonGamesApp extends StatelessWidget {
  const CommonGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, _) => MaterialApp(
        title: 'Board Box',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: SettingsService.instance.themeMode,
        home: const SplashScreen(),
      ),
    );
  }
}
