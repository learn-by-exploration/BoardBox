import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:common_games/games/sudoku/sudoku_board.dart';
import 'package:common_games/games/sudoku/sudoku_model.dart';
import 'package:common_games/games/sudoku/sudoku_puzzle.dart';
import 'package:common_games/screens/sudoku/sudoku_game_screen.dart';
import 'package:common_games/screens/sudoku/sudoku_setup_screen.dart';
import 'package:common_games/services/settings_service.dart';

const _solution = [
  5,
  3,
  4,
  6,
  7,
  8,
  9,
  1,
  2,
  6,
  7,
  2,
  1,
  9,
  5,
  3,
  4,
  8,
  1,
  9,
  8,
  3,
  4,
  2,
  5,
  6,
  7,
  8,
  5,
  9,
  7,
  6,
  1,
  4,
  2,
  3,
  4,
  2,
  6,
  8,
  5,
  3,
  7,
  9,
  1,
  7,
  1,
  3,
  9,
  2,
  4,
  8,
  5,
  6,
  9,
  6,
  1,
  5,
  3,
  7,
  2,
  8,
  4,
  2,
  8,
  7,
  4,
  1,
  9,
  6,
  3,
  5,
  3,
  4,
  5,
  2,
  8,
  6,
  1,
  7,
  9,
];

SudokuPuzzle _puzzleWithBlanks(Iterable<int> blanks) {
  final givens = List<int>.from(_solution);
  for (final index in blanks) {
    givens[index] = 0;
  }
  return SudokuPuzzle(
    givens: givens,
    solution: _solution,
    difficulty: SudokuDifficulty.easy,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, height: 400, child: child)),
    ),
  );

  testWidgets('board builds 81 cells, givens appear as text', (tester) async {
    // Puzzle with only index 0 blank. The board should render the value 3
    // (the given at row 1, col 1) somewhere in the tree.
    final model = SudokuModel(_puzzleWithBlanks([0]));
    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: 0,
          notesMode: false,
          onCellSelected: (_) {},
        ),
      ),
    );

    // 81 values total. The givens appear as Text widgets; the blank cell
    // doesn't. Count the rendered Text widgets for the digits 1..9.
    var textCount = 0;
    for (final value in model.values) {
      if (value != 0) textCount++;
    }
    expect(textCount, 80);

    // Find the '3' given at row 1, col 1.
    expect(
      find.descendant(of: find.byType(SudokuBoard), matching: find.text('3')),
      findsWidgets,
    );
  });

  testWidgets('board invokes onCellSelected when an empty cell is tapped', (
    tester,
  ) async {
    // Blank two cells: index 0 (row 0, col 0) and index 45 (row 5, col 0).
    final model = SudokuModel(_puzzleWithBlanks([0, 45]));
    int? selected;
    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: null,
          notesMode: false,
          onCellSelected: (i) => selected = i,
        ),
      ),
    );

    // Tap the cell at row 5, col 0 (index 45).
    final boardFinder = find.byType(SudokuBoard);
    final boardRect = tester.getRect(boardFinder);
    final cell50 = Offset(
      boardRect.left + boardRect.width / 18,
      boardRect.top + boardRect.height * 11 / 18,
    );
    await tester.tapAt(cell50);
    await tester.pump();
    expect(selected, 45);
  });

  testWidgets('board ignores taps on fixed cells', (tester) async {
    final model = SudokuModel(_puzzleWithBlanks([0]));
    int? selected;
    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: null,
          notesMode: false,
          onCellSelected: (i) => selected = i,
        ),
      ),
    );

    // Tap the fixed cell at row 0, col 1 (index 1, value 3). It should
    // NOT fire onCellSelected.
    final boardFinder = find.byType(SudokuBoard);
    final boardRect = tester.getRect(boardFinder);
    final cell01 = Offset(
      boardRect.left + boardRect.width * 3 / 18,
      boardRect.top + boardRect.height / 18,
    );
    await tester.tapAt(cell01);
    await tester.pump();
    expect(selected, isNull);
  });

  testWidgets('notes mode renders pending notes as small digits', (
    tester,
  ) async {
    final model = SudokuModel(_puzzleWithBlanks([0, 1]));
    // Place notes only in the first (empty) cell. Givens elsewhere will
    // *also* contain digits 2, 3, 4, 5, 6, 8, 9, etc., so we look for the
    // notes-specific font size (11.0) rather than the value text size.
    model.toggleNote(0, 2);
    model.toggleNote(0, 5);

    await tester.pumpWidget(
      wrap(
        SudokuBoard(
          model: model,
          selectedIndex: 0,
          notesMode: true,
          onCellSelected: (_) {},
        ),
      ),
    );

    // Notes text is 11.0 size; given values are 26.0 size. Filter to just
    // the note-sized Text widgets so we don't catch the givens.
    final noteTexts = find.descendant(
      of: find.byType(SudokuBoard),
      matching: find.byWidgetPredicate((w) {
        if (w is! Text) return false;
        if (w.data != '2' && w.data != '5') return false;
        final style = w.style;
        return style?.fontSize == 11.0;
      }),
    );
    expect(noteTexts, findsNWidgets(2));
  });

  testWidgets('setup screen lists all three difficulties', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SudokuSetupScreen())),
    );
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
  });

  testWidgets('timer pill advances while playing and freezes on pause', (
    tester,
  ) async {
    // Resize to a phone-shaped surface so the board + controls fit.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pre-seed a save so the screen restores instead of running the isolate.
    final seedModel = SudokuModel(_puzzleWithBlanks([0]));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sudoku_save_easy', jsonEncode(seedModel.toJson()));

    await tester.pumpWidget(
      const MaterialApp(
        home: SudokuGameScreen(
          difficulty: SudokuDifficulty.easy,
          saveKey: 'sudoku_save_easy',
        ),
      ),
    );
    // Let bootstrap and _startClock settle.
    await tester.pumpAndSettle();

    // Initial timer reads 00:00.
    expect(find.text('Time: 00:00'), findsOneWidget);

    // Advance two seconds via the periodic timer.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Time: 00:02'), findsOneWidget);

    // Tap the pause button and pump; the timer should stop advancing.
    await tester.tap(find.byKey(const ValueKey('sudoku_pause_button')));
    await tester.pump();
    expect(find.text('Paused: 00:02'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('Paused: 00:02'),
      findsOneWidget,
      reason: 'paused timer must not advance',
    );
  });

  testWidgets(
    'timer pauses when the app is backgrounded and resumes on foreground',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final seedModel = SudokuModel(_puzzleWithBlanks([0]));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sudoku_save_easy', jsonEncode(seedModel.toJson()));

      await tester.pumpWidget(
        const MaterialApp(
          home: SudokuGameScreen(
            difficulty: SudokuDifficulty.easy,
            saveKey: 'sudoku_save_easy',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      // The clock pill should read 00:02 here. Use a relaxed matcher since
      // text wrapping on a 360dp-wide surface can ellipsize part of it.
      expect(find.textContaining('00:02'), findsWidgets);

      // App goes to background. The model's `paused` flag should flip to
      // true. We can't directly inspect the model from outside the screen,
      // but we can verify the *behaviour*: while paused, the periodic timer
      // continues to fire (it's still scheduled) but `model.tick` becomes a
      // no-op, so `elapsedSeconds` must not advance. The pause also
      // disables the scheduler's frame pipeline, so the next `pump()` may
      // not re-render — we don't assert on UI labels during the paused
      // window, only on the model state after resume.
      final binding = WidgetsBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // Pump 3 simulated seconds while the app is backgrounded. If the
      // screen's lifecycle handler did NOT set `paused = true`, the model
      // would tick forward to 5 by now. The assertion below (after resume)
      // will catch that — `elapsedSeconds` must be 4 (2 pre-pause + 2
      // post-resume), not 7.
      await tester.pump(const Duration(seconds: 3));

      // App returns to foreground. Frame scheduling re-enables, and the
      // dirty widget from `_setPaused(true)` finally rebuilds; subsequent
      // pumps run the periodic timer normally.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final resumedPill = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('sudoku_timer_pill')),
          matching: find.byType(Text),
        ),
      );
      expect(
        resumedPill.data,
        contains('Time'),
        reason: 'timer pill should switch back to "Time" label',
      );
      expect(
        resumedPill.data,
        contains('00:04'),
        reason:
            'elapsed seconds must freeze during background and advance '
            'after foreground (2 pre-pause + 3 paused + 2 resumed = 4, not 7)',
      );
    },
  );

  testWidgets(
    'hitting the mistake limit shows the loss dialog and blocks further input',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pre-set the limit to 1, mistake checking on, and seed a save with
      // two blank cells so we can land on a wrong value and a correct
      // follow-up.
      await SettingsService.instance.setSudokuMistakeChecking(true);
      await SettingsService.instance.setSudokuMistakesLimit(1);

      final seedModel = SudokuModel(_puzzleWithBlanks([45, 46]));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sudoku_save_easy', jsonEncode(seedModel.toJson()));

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: SudokuGameScreen(
            difficulty: SudokuDifficulty.easy,
            saveKey: 'sudoku_save_easy',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the cell at (row 5, col 0) — index 45 — by its Semantics label
      // and tap it. Using Semantics avoids coordinate math across surface
      // sizes and works regardless of how the device pixel ratio scales
      // the board.
      final cellFinder = find.bySemanticsLabel(
        RegExp(r'Row 6 column 1, empty'),
      );
      expect(cellFinder, findsOneWidget);
      await tester.tap(cellFinder.first, warnIfMissed: false);
      await tester.pump();
      handle.dispose();

      // Enter a wrong value (the solution at index 45 is 1, so 4 is wrong).
      // Tapping the "4" number-pad button. We find it by its key.
      await tester.tap(find.byKey(const ValueKey('sudoku_pad_4')));
      await tester.pumpAndSettle();

      // The loss dialog must appear.
      expect(find.text('Too many mistakes'), findsOneWidget);

      // The wrong value is on the board.
      expect(find.text('4'), findsWidgets);
    },
  );

  testWidgets('mistake checking off lets the user keep entering wrong values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await SettingsService.instance.setSudokuMistakeChecking(false);
    await SettingsService.instance.setSudokuMistakesLimit(1);

    final seedModel = SudokuModel(_puzzleWithBlanks([0]));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sudoku_save_easy', jsonEncode(seedModel.toJson()));

    await tester.pumpWidget(
      const MaterialApp(
        home: SudokuGameScreen(
          difficulty: SudokuDifficulty.easy,
          saveKey: 'sudoku_save_easy',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the empty cell at (row 0, col 0) — index 0.
    final boardFinder = find.byType(SudokuBoard);
    final boardRect = tester.getRect(boardFinder);
    final cell00 = Offset(
      boardRect.left + boardRect.width / 18,
      boardRect.top + boardRect.height / 18,
    );
    await tester.tapAt(cell00);
    await tester.pump();

    // Enter a wrong value (the solution at 0 is 5, so 4 is wrong).
    await tester.tap(find.byKey(const ValueKey('sudoku_pad_4')));
    await tester.pumpAndSettle();

    // The loss dialog must NOT appear.
    expect(find.text('Too many mistakes'), findsNothing);

    // The wrong value is on the board.
    expect(find.text('4'), findsWidgets);
  });

  testWidgets(
    'wrong entries highlight the cell and erase clears the highlight',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Reset the mistake check + limit so we can enter a single wrong
      // value without triggering the loss dialog.
      await SettingsService.instance.setSudokuMistakeChecking(true);
      await SettingsService.instance.setSudokuMistakesLimit(3);

      final seedModel = SudokuModel(_puzzleWithBlanks([45]));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sudoku_save_easy', jsonEncode(seedModel.toJson()));

      await tester.pumpWidget(
        const MaterialApp(
          home: SudokuGameScreen(
            difficulty: SudokuDifficulty.easy,
            saveKey: 'sudoku_save_easy',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the empty cell at (row 5, col 0) — index 45.
      final cellFinder = find.bySemanticsLabel(
        RegExp(r'Row 6 column 1, empty'),
      );
      await tester.tap(cellFinder.first, warnIfMissed: false);
      await tester.pump();

      // Enter a wrong value (solution is 1, so 4 is wrong). The cell
      // should be highlighted with the error-container background.
      await tester.tap(find.byKey(const ValueKey('sudoku_pad_4')));
      await tester.pumpAndSettle();

      // Find the Container holding the wrong cell and check its
      // background colour. The cell uses `decoration: BoxDecoration(color:
      // ...)` so we have to look at `decoration?.color`.
      final errorContainer = Theme.of(
        tester.element(find.byType(SudokuGameScreen)),
      ).colorScheme.errorContainer;
      final hasInvalidBackground = find.descendant(
        of: find.byType(SudokuBoard),
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final deco = w.decoration;
          return deco is BoxDecoration && deco.color == errorContainer;
        }),
      );
      expect(
        hasInvalidBackground,
        findsWidgets,
        reason: 'wrong entry should paint the cell with errorContainer',
      );

      // Now erase the cell and the highlight should disappear.
      await tester.tap(find.byKey(const ValueKey('sudoku_pad_erase')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SudokuBoard),
          matching: find.byWidgetPredicate((w) {
            if (w is! Container) return false;
            final deco = w.decoration;
            return deco is BoxDecoration && deco.color == errorContainer;
          }),
        ),
        findsNothing,
        reason: 'erasing the cell clears the error highlight',
      );
    },
  );
}
