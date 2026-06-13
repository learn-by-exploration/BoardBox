import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/minesweeper/minesweeper_board.dart';
import 'package:common_games/games/minesweeper/minesweeper_model.dart';
import 'package:common_games/screens/minesweeper/minesweeper_game_screen.dart';
import 'package:common_games/screens/minesweeper/minesweeper_setup_screen.dart';
import 'package:common_games/services/game_stats.dart';

void main() {
  group('MinesweeperBoard', () {
    testWidgets(
      'renders 81 cells for beginner, 256 for intermediate, 480 for expert',
      (tester) async {
        for (final (difficulty, expected) in <(MinesweeperDifficulty, int)>[
          (MinesweeperDifficulty.beginner, 81),
          (MinesweeperDifficulty.intermediate, 256),
          (MinesweeperDifficulty.expert, 480),
        ]) {
          final model = MinesweeperModel.deal(difficulty: difficulty, seed: 1);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 600,
                  child: MinesweeperBoard(model: model),
                ),
              ),
            ),
          );
          // Each cell is a GestureDetector with a Container child.
          final cellFinder = find.byType(GestureDetector);
          expect(cellFinder, findsNWidgets(expected));
          expect(model.state, isA<MinesweeperPlaying>());
        }
      },
    );

    testWidgets('tapping a hidden cell reveals it and stays in playing state', (
      tester,
    ) async {
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MinesweeperBoard(model: model),
            ),
          ),
        ),
      );
      // Tap the first cell (top-left).
      final firstCell = find.byType(GestureDetector).first;
      await tester.tap(firstCell);
      await tester.pump();
      // The minefield is now placed.
      expect(model.minesPlaced, isTrue);
      // The tapped cell is safe (first-tap safety) and revealed.
      expect(model.cellAt(0, 0).isMine, isFalse);
      expect(model.cellAt(0, 0).revealed, isTrue);
      expect(model.state, isA<MinesweeperPlaying>());
    });

    testWidgets('long-pressing a hidden cell sets a flag', (tester) async {
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MinesweeperBoard(model: model),
            ),
          ),
        ),
      );
      final firstCell = find.byType(GestureDetector).first;
      await tester.longPress(firstCell);
      await tester.pump();
      expect(model.cellAt(0, 0).flagged, isTrue);
      expect(model.flagCount, 1);
    });

    testWidgets('long-pressing a revealed cell is a no-op', (tester) async {
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      // Reveal a cell first by tapping it.
      model.reveal(0, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MinesweeperBoard(model: model),
            ),
          ),
        ),
      );
      // Find a revealed cell — (0, 0) is revealed. Long-press should
      // not set a flag.
      final revealedCell = find.byType(GestureDetector).first;
      await tester.longPress(revealedCell);
      await tester.pump();
      expect(model.cellAt(0, 0).flagged, isFalse);
    });

    testWidgets('tapping a mine flips state to Lost and renders all mines', (
      tester,
    ) async {
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      // First tap a safe cell to place the minefield.
      model.reveal(0, 0);
      // Find a known mine.
      final (mineRow, mineCol) = _firstMine(model);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MinesweeperBoard(model: model),
            ),
          ),
        ),
      );
      // Tap the mine.
      // Compute the cell index in the GridView: index = row * cols + col.
      final mineIndex = mineRow * model.cols + mineCol;
      final mineCell = find.byType(GestureDetector).at(mineIndex);
      await tester.tap(mineCell);
      await tester.pump();
      expect(model.state, isA<MinesweeperLost>());
      // At least one mine is now rendered (the board shows all mines
      // after a loss). We render a '*' character for mines, not an
      // Icons.bomb, so look for the text directly.
      expect(find.text('*'), findsWidgets);
    });

    testWidgets('onModelChanged fires after a tap', (tester) async {
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      var callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MinesweeperBoard(
                model: model,
                onModelChanged: (_) => callCount++,
              ),
            ),
          ),
        ),
      );
      final firstCell = find.byType(GestureDetector).first;
      await tester.tap(firstCell);
      await tester.pump();
      expect(callCount, 1);
    });
  });

  group('MinesweeperGameScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GameStats.instance.init();
    });

    testWidgets('renders the AppBar, status bar pills, and reset button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(414 * 3, 896 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: MinesweeperGameScreen(
            difficulty: MinesweeperDifficulty.beginner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The AppBar title and the reset (face-icon) button are present.
      expect(find.text('Minesweeper · Beginner'), findsOneWidget);
      expect(find.byKey(const ValueKey('minesweeper_reset')), findsOneWidget);
      // The mine counter pill is at the full mine count.
      expect(
        find.byKey(const ValueKey('minesweeper_mine_counter')),
        findsOneWidget,
      );
      // The timer pill starts at 00:00.
      expect(find.byKey(const ValueKey('minesweeper_timer')), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('tapping the reset button restarts the model', (tester) async {
      tester.view.physicalSize = const Size(414 * 3, 896 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Build a real model, mutate it (tap a cell to place the
      // minefield), and persist its full JSON. The screen should
      // restore that exact timer value.
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      model.reveal(0, 0);
      final saved = jsonEncode(model.toJson());
      SharedPreferences.setMockInitialValues({
        MinesweeperGameScreen.saveKeyFor(MinesweeperDifficulty.beginner): saved,
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: MinesweeperGameScreen(
            difficulty: MinesweeperDifficulty.beginner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The mine counter shows totalMines - flagCount = 10 (no flags yet).
      expect(
        find.byKey(const ValueKey('minesweeper_mine_counter')),
        findsOneWidget,
      );
      // Tapping the face-icon reset clears the save and re-deals.
      await tester.tap(find.byKey(const ValueKey('minesweeper_reset')));
      await tester.pumpAndSettle();
      // The timer was 0 and stays 0; the mine counter is back to 10.
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('tapping a known mine shows the loss dialog', (tester) async {
      tester.view.physicalSize = const Size(414 * 3, 896 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      model.reveal(0, 0); // place the minefield
      // Find a known mine.
      (int, int) mineAt = (0, 0);
      for (var r = 0; r < model.rows; r++) {
        for (var c = 0; c < model.cols; c++) {
          if (model.cellAt(r, c).isMine) {
            mineAt = (r, c);
            break;
          }
        }
      }
      final json = model.toJson();
      SharedPreferences.setMockInitialValues({
        MinesweeperGameScreen.saveKeyFor(MinesweeperDifficulty.beginner):
            jsonEncode(json),
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: MinesweeperGameScreen(
            difficulty: MinesweeperDifficulty.beginner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mineIndex = mineAt.$1 * model.cols + mineAt.$2;
      final cellFinder = find.byType(GestureDetector).at(mineIndex);
      await tester.tap(cellFinder);
      await tester.pumpAndSettle();
      expect(find.text('Boom!'), findsOneWidget);
    });

    testWidgets('cells expose Semantics labels for screen readers', (
      tester,
    ) async {
      final model = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MinesweeperBoard(model: model),
            ),
          ),
        ),
      );
      // Before any tap, every cell reads as "Hidden".
      expect(find.bySemanticsLabel('Hidden'), findsNWidgets(81));
      // Tap the first cell to place the minefield and cascade-reveal
      // connected cells. The tapped cell is now "Revealed, …" and the
      // rest that the cascade touched are too. The remaining hidden
      // cells are still "Hidden".
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      // Some hidden cells remain (we don't know the exact cascade
      // extent without re-implementing the model's logic) but the
      // count must be strictly less than the 81 we started with.
      final hiddenAfter = find.bySemanticsLabel('Hidden').evaluate().length;
      expect(hiddenAfter, lessThan(81));
      expect(
        find.bySemanticsLabel(RegExp(r'^Revealed, .* adjacent mines$')),
        findsAtLeast(1),
      );
      handle.dispose();
    });

    testWidgets('mine counter and timer pills have spoken-form labels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(414 * 3, 896 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: MinesweeperGameScreen(
            difficulty: MinesweeperDifficulty.beginner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Mine counter says "Mines remaining: 10" (Beginner, no flags).
      expect(find.bySemanticsLabel('Mines remaining: 10'), findsOneWidget);
      // Timer reads "Time: 00:00".
      expect(find.bySemanticsLabel('Time: 00:00'), findsOneWidget);
      // The reset (face-icon) button is at least 48dp tall — Material
      // IconButton guarantees this.
      final resetSize = tester.getSize(
        find.byKey(const ValueKey('minesweeper_reset')),
      );
      expect(resetSize.width, greaterThanOrEqualTo(48.0));
      expect(resetSize.height, greaterThanOrEqualTo(48.0));
      handle.dispose();
    });

    testWidgets('pausing the app cancels the clock timer', (tester) async {
      tester.view.physicalSize = const Size(414 * 3, 896 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: MinesweeperGameScreen(
            difficulty: MinesweeperDifficulty.beginner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The screen registers itself as a WidgetsBindingObserver, so the
      // pause lifecycle event must freeze the 1Hz clock.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // The 5s pump below would normally advance the clock by 5 ticks;
      // because the clock is paused, the elapsed value must not move.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('00:00'), findsOneWidget);
      // Resume and confirm the clock ticks again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('00:03'), findsOneWidget);
    });
  });

  group('MinesweeperSetupScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GameStats.instance.init();
    });

    testWidgets('renders three difficulty cards with play buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MinesweeperSetupScreen()),
      );
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Expert'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('minesweeper_new_game_beginner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('minesweeper_new_game_intermediate')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('minesweeper_new_game_expert')),
        findsOneWidget,
      );
    });

    testWidgets('shows the empty-state prompt when no games have been played', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MinesweeperSetupScreen()),
      );
      expect(
        find.text('Pick a difficulty to start your first game.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the per-difficulty record after a win', (tester) async {
      await GameStats.instance.recordMinesweeperWin(
        MinesweeperDifficulty.beginner,
      );
      await GameStats.instance.recordMinesweeperLoss(
        MinesweeperDifficulty.intermediate,
      );
      await tester.pumpWidget(
        const MaterialApp(home: MinesweeperSetupScreen()),
      );
      // The summary line mentions the beginner and intermediate counts.
      expect(find.textContaining('Beginner 1W/0L'), findsOneWidget);
      expect(find.textContaining('Intermediate 0W/1L'), findsOneWidget);
    });
  });
}

(int, int) _firstMine(MinesweeperModel m) {
  for (var r = 0; r < m.rows; r++) {
    for (var c = 0; c < m.cols; c++) {
      if (m.cellAt(r, c).isMine) return (r, c);
    }
  }
  throw StateError('No mine found');
}
