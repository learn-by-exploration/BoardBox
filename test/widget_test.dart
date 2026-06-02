import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/tictactoe/tictactoe_board.dart';
import 'package:common_games/main.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/services/game_stats.dart';
import 'package:common_games/services/settings_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameStats.instance.init();
    await SettingsService.instance.init();
  });

  testWidgets('App renders splash then navigates to home', (tester) async {
    await tester.pumpWidget(const CommonGamesApp());
    // Splash screen shows app name immediately.
    expect(find.text('Board Box'), findsOneWidget);

    // After the splash delay + transition, we land on home screen.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // At least the first game tile is visible in the grid.
    expect(find.text('Gomoku'), findsOneWidget);
  });

  testWidgets('Tic Tac Toe board accepts two-player taps', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TicTacToeBoard(mode: GameMode.twoPlayer, boardSize: 3),
        ),
      ),
    );

    expect(find.text("X's turn"), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Empty row 1 column 1'));
    await tester.pumpAndSettle();
    expect(find.text("O's turn"), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Empty row 1 column 2'));
    await tester.pumpAndSettle();
    expect(find.text("X's turn"), findsOneWidget);
    expect(find.bySemanticsLabel('X at row 1 column 1'), findsOneWidget);
    expect(find.bySemanticsLabel('O at row 1 column 2'), findsOneWidget);
  });
}
