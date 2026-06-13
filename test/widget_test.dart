import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/dots_and_boxes/dots_board.dart';
import 'package:common_games/games/gomoku/gomoku_board.dart';
import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/games/tictactoe/tictactoe_board.dart';
import 'package:common_games/main.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/screens/home_screen.dart';
import 'package:common_games/screens/mode_select_screen.dart';
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

  testWidgets('Tic Tac Toe highlights the AI last move', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TicTacToeBoard(
            mode: GameMode.singlePlayer,
            boardSize: 3,
            difficulty: AiDifficulty.easy,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Empty row 1 column 1'));
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.bySemanticsLabel(RegExp(r'^AI last move, O at row')),
      findsOneWidget,
    );
  });

  testWidgets('Home shows all-game and per-game scores', (tester) async {
    SharedPreferences.setMockInitialValues({
      'gomoku_easy_wins': 2,
      'gomoku_easy_losses': 1,
      'tictactoe_hard_draws': 3,
    });
    await GameStats.instance.init();

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('6 single-player matches completed'), findsOneWidget);
    expect(find.text('2 W  ·  0 D  ·  1 L'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('0 W  ·  3 D  ·  0 L'), findsOneWidget);
  });

  testWidgets('Home supports search and grid or list layouts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Board Box'), findsNothing);
    expect(find.byTooltip('Search games'), findsOneWidget);
    expect(find.byTooltip('Show list'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_search_button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('home_search_close_button')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'othello');
    await tester.pump();

    expect(find.text('1 game'), findsOneWidget);
    expect(find.text('Othello'), findsOneWidget);
    expect(find.text('Gomoku'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home_layout_button')));
    await tester.pump();
    expect(find.byTooltip('Show grid'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_layout_button')));
    await tester.pump();
    expect(find.byTooltip('Show list'), findsOneWidget);
  });

  testWidgets('Dots and Boxes supports selectable grid sizes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ModeSelectScreen(
          gameType: GameType.dotsAndBoxes,
          title: 'Dots & Boxes',
        ),
      ),
    );

    expect(find.text('4 × 4 boxes'), findsOneWidget);
    await tester.tap(find.text('6 × 6'));
    await tester.pump();
    expect(find.text('5 × 5 boxes'), findsOneWidget);

    await tester.tap(find.text('2 Players'));
    await tester.pumpAndSettle();
    expect(find.text('6×6 · 2 Players'), findsOneWidget);
  });

  testWidgets('Gomoku board announces the active player', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GomokuBoard(mode: GameMode.singlePlayer)),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'Gomoku board\..*Black to move')),
      findsOneWidget,
    );
  });

  testWidgets('Dots board announces the active player and score', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DotsBoard(mode: GameMode.singlePlayer)),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Dots and Boxes board\. Player 1 to move\.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home catalog includes the Sudoku tile', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Sudoku'), findsOneWidget);
    expect(find.text('Number Logic'), findsOneWidget);
  });

  testWidgets('Home catalog includes the Minesweeper tile', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Minesweeper is the last tile in the 2-column grid; scroll down
    // to find it on the default 800×600 test surface.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Minesweeper'), findsOneWidget);
    expect(find.text('Sweep the Board'), findsOneWidget);
    // No games played yet — the tile should show the empty-state label.
    expect(find.text('New game — pick a difficulty'), findsWidgets);
  });

  testWidgets('Minesweeper tile shows per-difficulty record after a win', (
    tester,
  ) async {
    await GameStats.instance.recordMinesweeperWin(
      MinesweeperDifficulty.beginner,
    );
    await GameStats.instance.recordMinesweeperWin(
      MinesweeperDifficulty.beginner,
    );
    await GameStats.instance.recordMinesweeperLoss(
      MinesweeperDifficulty.expert,
    );
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Scroll down to bring the Minesweeper tile into view.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    // Beginner 2W/0L and Expert 0W/1L — Intermediate is empty and
    // dropped from the summary.
    expect(find.textContaining('Beginner 2W/0L'), findsOneWidget);
    expect(find.textContaining('Expert 0W/1L'), findsOneWidget);
  });
}
