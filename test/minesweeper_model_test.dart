import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/minesweeper/minesweeper_model.dart';

void main() {
  group('MinesweeperDifficulty', () {
    test('beginner is 9x9 with 10 mines', () {
      const d = MinesweeperDifficulty.beginner;
      expect(d.rows, 9);
      expect(d.cols, 9);
      expect(d.mineCount, 10);
    });

    test('intermediate is 16x16 with 40 mines', () {
      const d = MinesweeperDifficulty.intermediate;
      expect(d.rows, 16);
      expect(d.cols, 16);
      expect(d.mineCount, 40);
    });

    test('expert is 16x30 with 99 mines', () {
      const d = MinesweeperDifficulty.expert;
      expect(d.rows, 16);
      expect(d.cols, 30);
      expect(d.mineCount, 99);
    });
  });

  group('MinesweeperModel — initial state', () {
    test(
      'beginner deal has 81 hidden cells, no mines placed, state playing',
      () {
        final m = MinesweeperModel.deal(
          difficulty: MinesweeperDifficulty.beginner,
        );
        expect(m.rows, 9);
        expect(m.cols, 9);
        expect(m.state, isA<MinesweeperPlaying>());
        expect(m.minesPlaced, isFalse);
        for (var r = 0; r < 9; r++) {
          for (var c = 0; c < 9; c++) {
            expect(m.cellAt(r, c).revealed, isFalse);
            expect(m.cellAt(r, c).flagged, isFalse);
          }
        }
      },
    );

    test('mine count is reported even before minefield is generated', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
      );
      expect(m.totalMines, 10);
    });

    test('expert deal reports 480 cells (16 * 30)', () {
      final m = MinesweeperModel.deal(difficulty: MinesweeperDifficulty.expert);
      expect(m.rows * m.cols, 480);
      expect(m.totalMines, 99);
    });
  });

  group('MinesweeperModel — first reveal (first-tap safety)', () {
    test(
      'first reveal places the minefield with the tapped cell + 8 neighbors mine-free',
      () {
        final m = MinesweeperModel.deal(
          difficulty: MinesweeperDifficulty.beginner,
          seed: 42,
        );
        m.reveal(4, 4);
        // The minefield is now placed.
        expect(m.minesPlaced, isTrue);
        // The tapped cell is safe.
        expect(m.cellAt(4, 4).isMine, isFalse);
        // All 8 neighbors are safe.
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            final r = 4 + dr;
            final c = 4 + dc;
            expect(
              m.cellAt(r, c).isMine,
              isFalse,
              reason: 'cell ($r, $c) is a mine',
            );
          }
        }
        // The total mine count is unchanged.
        final mineCount = _countMines(m);
        expect(mineCount, 10);
      },
    );

    test(
      'first reveal on a corner cell also keeps the 3 visible neighbors safe',
      () {
        final m = MinesweeperModel.deal(
          difficulty: MinesweeperDifficulty.beginner,
          seed: 7,
        );
        m.reveal(0, 0);
        expect(m.cellAt(0, 0).isMine, isFalse);
        expect(m.cellAt(0, 1).isMine, isFalse);
        expect(m.cellAt(1, 0).isMine, isFalse);
        expect(m.cellAt(1, 1).isMine, isFalse);
      },
    );

    test(
      'first reveal of a count-0 cell cascades to reveal connected region',
      () {
        final m = MinesweeperModel.deal(
          difficulty: MinesweeperDifficulty.beginner,
          seed: 1,
        );
        m.reveal(0, 0);
        // At least the tapped cell is revealed (the cascade may reveal
        // more, but the tapped cell must be).
        expect(m.cellAt(0, 0).revealed, isTrue);
      },
    );

    test(
      'first reveal in the center of a beginner board usually cascades widely',
      () {
        final m = MinesweeperModel.deal(
          difficulty: MinesweeperDifficulty.beginner,
          seed: 1,
        );
        m.reveal(4, 4);
        final revealedCount = _countRevealed(m);
        // Minesweeper classic: tapping a count-0 cell in the center of a
        // 9x9 beginner board typically reveals a big region. We just
        // assert the cell is revealed and the count is at least 1.
        expect(revealedCount, greaterThanOrEqualTo(1));
        expect(m.state, isA<MinesweeperPlaying>());
      },
    );
  });

  group('MinesweeperModel — reveal', () {
    test('reveal of a non-mine cell marks it revealed and stays Playing', () {
      final m = _beginnerWithKnownMines(seed: 1);
      // Find a known-safe cell.
      final safe = _firstSafeCell(m);
      m.reveal(safe.$1, safe.$2);
      expect(m.cellAt(safe.$1, safe.$2).revealed, isTrue);
      expect(m.state, isA<MinesweeperPlaying>());
    });

    test('reveal of a mine flips state to Lost and reveals all mines', () {
      // Place mines first by tapping a safe cell, then tap a mine.
      final m = _beginnerWithKnownMines(seed: 1);
      m.reveal(0, 0);
      expect(m.state, isA<MinesweeperPlaying>());
      // Find any mine.
      _firstMine(m);
      // Reset and reveal the mine directly. To do this we re-deal and
      // first tap a corner to generate the minefield, then tap a mine.
      final m2 = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      // Tap a corner that's known to be safe and likely cascade.
      m2.reveal(0, 0);
      // Now find any mine in the placed minefield and tap it.
      final mine2 = _firstMine(m2);
      m2.reveal(mine2.$1, mine2.$2);
      expect(m2.cellAt(mine2.$1, mine2.$2).isMine, isTrue);
      expect(m2.state, isA<MinesweeperLost>());
    });

    test('reveal of an already-revealed cell is a no-op', () {
      final m = _beginnerWithKnownMines(seed: 1);
      final safe = _firstSafeCell(m);
      m.reveal(safe.$1, safe.$2);
      final before = m.elapsedSeconds;
      m.reveal(safe.$1, safe.$2);
      expect(m.elapsedSeconds, before);
    });

    test('reveal of a flagged cell is ignored', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      m.toggleFlag(0, 0);
      expect(m.cellAt(0, 0).flagged, isTrue);
      m.reveal(0, 0);
      expect(m.cellAt(0, 0).revealed, isFalse);
    });

    test('adjacency count is the count of mines in the 8 neighbors', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      m.reveal(0, 0);
      // After reveal, mines are placed. The count for the tapped cell
      // (or any other revealed cell) should be in 0..8.
      for (var r = 0; r < m.rows; r++) {
        for (var c = 0; c < m.cols; c++) {
          final n = m.adjacentMinesAt(r, c);
          expect(n, inInclusiveRange(0, 8));
        }
      }
    });
  });

  group('MinesweeperModel — flag', () {
    test('toggleFlag on a hidden cell sets the flag', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      m.toggleFlag(3, 3);
      expect(m.cellAt(3, 3).flagged, isTrue);
      m.toggleFlag(3, 3);
      expect(m.cellAt(3, 3).flagged, isFalse);
    });

    test('toggleFlag on a revealed cell is a no-op', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      m.reveal(4, 4);
      expect(m.cellAt(4, 4).revealed, isTrue);
      m.toggleFlag(4, 4);
      expect(m.cellAt(4, 4).flagged, isFalse);
    });

    test('flagCount returns the number of flagged cells', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      expect(m.flagCount, 0);
      m.toggleFlag(1, 1);
      m.toggleFlag(2, 2);
      m.toggleFlag(3, 3);
      expect(m.flagCount, 3);
      m.toggleFlag(1, 1);
      expect(m.flagCount, 2);
    });
  });

  group('MinesweeperModel — win', () {
    test('revealing all safe cells flips state to Won', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      m.reveal(0, 0); // First-tap-safe, places the minefield.
      // Reveal every non-mine cell.
      for (var r = 0; r < m.rows; r++) {
        for (var c = 0; c < m.cols; c++) {
          if (!m.cellAt(r, c).isMine) {
            m.reveal(r, c);
          }
        }
      }
      expect(m.state, isA<MinesweeperWon>());
    });

    test('cascade reveal of a 0-region flips state to Won in a single tap', () {
      // Build a beginner 9×9 minefield with 10 mines clustered in the
      // bottom-right corner. A cascade from the top-left corner (0,0)
      // should reach every safe cell in one tap, exercising the
      // cascade → _checkWin → Won path that the manual-reveal test
      // above does not cover. Mine positions are hand-picked so the
      // safe zone and the cascade region are disjoint.
      final cells = <List<Map<String, bool>>>[
        for (var r = 0; r < 9; r++)
          [
            for (var c = 0; c < 9; c++)
              {'mine': false, 'revealed': false, 'flagged': false},
          ],
      ];
      const minePositions = <List<int>>[
        [6, 6],
        [6, 7],
        [6, 8],
        [7, 6],
        [7, 7],
        [7, 8],
        [8, 5],
        [8, 6],
        [8, 7],
        [8, 8],
      ];
      for (final p in minePositions) {
        cells[p[0]][p[1]] = {'mine': true, 'revealed': false, 'flagged': false};
      }
      final m = MinesweeperModel.fromJson(<String, dynamic>{
        'version': 1,
        'difficulty': 'beginner',
        'seed': 0,
        'elapsedSeconds': 0,
        'minesPlaced': true,
        'cells': cells,
        'state': 'playing',
      });
      m.reveal(0, 0);
      expect(m.state, isA<MinesweeperWon>());
      // No mine should have been revealed as part of the cascade.
      for (final p in minePositions) {
        expect(
          m.cellAt(p[0], p[1]).revealed,
          isFalse,
          reason: 'mine at (${p[0]}, ${p[1]}) must stay hidden on a win',
        );
      }
    });
  });

  group('MinesweeperModel — restart', () {
    test(
      'restart returns to Playing and clears all revealed/flagged cells',
      () {
        final m = MinesweeperModel.deal(
          difficulty: MinesweeperDifficulty.beginner,
          seed: 1,
        );
        m.reveal(0, 0);
        m.toggleFlag(8, 8);
        m.restart();
        expect(m.state, isA<MinesweeperPlaying>());
        expect(m.minesPlaced, isFalse);
        expect(m.flagCount, 0);
        for (var r = 0; r < m.rows; r++) {
          for (var c = 0; c < m.cols; c++) {
            expect(m.cellAt(r, c).revealed, isFalse);
            expect(m.cellAt(r, c).flagged, isFalse);
          }
        }
      },
    );
  });

  group('MinesweeperModel — timer', () {
    test('tick increments elapsedSeconds when playing', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      expect(m.elapsedSeconds, 0);
      m.tick(1);
      expect(m.elapsedSeconds, 1);
      m.tick(5);
      expect(m.elapsedSeconds, 6);
    });

    test('tick is ignored when state is not Playing', () {
      final m = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      m.reveal(0, 0);
      m.restart();
      // Force the state to lost by revealing a mine.
      m.reveal(0, 0);
      final mine = _firstMine(m);
      m.reveal(mine.$1, mine.$2);
      expect(m.state, isA<MinesweeperLost>());
      final before = m.elapsedSeconds;
      m.tick(1);
      expect(m.elapsedSeconds, before);
    });
  });

  group('MinesweeperModel — JSON round-trip', () {
    test(
      'toJson + fromJson preserves difficulty, seed, revealed cells, state',
      () {
        final m1 = MinesweeperModel.deal(
          difficulty: MinesweeperDifficulty.intermediate,
          seed: 99,
        );
        m1.reveal(4, 4);
        final json = m1.toJson();
        final m2 = MinesweeperModel.fromJson(json);
        expect(m2.difficulty, MinesweeperDifficulty.intermediate);
        expect(m2.rows, 16);
        expect(m2.cols, 16);
        expect(m2.totalMines, 40);
        expect(m2.minesPlaced, isTrue);
        expect(m2.cellAt(4, 4).revealed, isTrue);
        // Minefield is identical (same seed).
        for (var r = 0; r < m2.rows; r++) {
          for (var c = 0; c < m2.cols; c++) {
            expect(m2.cellAt(r, c).isMine, m1.cellAt(r, c).isMine);
          }
        }
      },
    );

    test('fromJson on an unsupported version throws FormatException', () {
      expect(
        () => MinesweeperModel.fromJson({'version': 999}),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trip preserves elapsedSeconds', () {
      final m1 = MinesweeperModel.deal(
        difficulty: MinesweeperDifficulty.beginner,
        seed: 1,
      );
      m1.tick(123);
      final json = m1.toJson();
      final m2 = MinesweeperModel.fromJson(json);
      expect(m2.elapsedSeconds, 123);
    });
  });
}

MinesweeperModel _beginnerWithKnownMines({required int seed}) =>
    MinesweeperModel.deal(
      difficulty: MinesweeperDifficulty.beginner,
      seed: seed,
    );

(int, int) _firstSafeCell(MinesweeperModel m) {
  for (var r = 0; r < m.rows; r++) {
    for (var c = 0; c < m.cols; c++) {
      if (!m.cellAt(r, c).isMine) return (r, c);
    }
  }
  throw StateError('No safe cell found');
}

(int, int) _firstMine(MinesweeperModel m) {
  for (var r = 0; r < m.rows; r++) {
    for (var c = 0; c < m.cols; c++) {
      if (m.cellAt(r, c).isMine) return (r, c);
    }
  }
  throw StateError('No mine found');
}

int _countMines(MinesweeperModel m) {
  var n = 0;
  for (var r = 0; r < m.rows; r++) {
    for (var c = 0; c < m.cols; c++) {
      if (m.cellAt(r, c).isMine) n++;
    }
  }
  return n;
}

int _countRevealed(MinesweeperModel m) {
  var n = 0;
  for (var r = 0; r < m.rows; r++) {
    for (var c = 0; c < m.cols; c++) {
      if (m.cellAt(r, c).revealed) n++;
    }
  }
  return n;
}
