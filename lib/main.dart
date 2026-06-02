import 'package:flutter/material.dart';

import 'package:common_games/screens/splash_screen.dart';
import 'package:common_games/services/game_stats.dart';
import 'package:common_games/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameStats.instance.init();
  runApp(const CommonGamesApp());
}

class CommonGamesApp extends StatelessWidget {
  const CommonGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Board Box',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
