import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:common_games/games/minesweeper/minesweeper_board.dart';
import 'package:common_games/games/minesweeper/minesweeper_model.dart';

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
}

(int, int) _firstMine(MinesweeperModel m) {
  for (var r = 0; r < m.rows; r++) {
    for (var c = 0; c < m.cols; c++) {
      if (m.cellAt(r, c).isMine) return (r, c);
    }
  }
  throw StateError('No mine found');
}
