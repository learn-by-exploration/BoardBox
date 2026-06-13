/// Pure-Dart Minesweeper model. No Flutter imports — the visuals and
/// gesture layer live in `minesweeper_board.dart`. Save/restore is
/// versioned (`version: 1`).
///
/// **First-tap safety:** the minefield is generated lazily on the first
/// reveal, with the tapped cell *and* its 8 neighbors guaranteed
/// mine-free. This is the classic Microsoft-Minesweeper behavior — a
/// satisfied first tap is the entire point of the puzzle. Tests in
/// `test/minesweeper_model_test.dart` enforce this invariant.
///
/// **Cascade reveal:** revealing a cell with 0 adjacent mines reveals
/// all 8 neighbors and recursively reveals any of those with 0. The
/// cascade is bounded by the minefield, so a fully-isolated corner can
/// cascade to the entire board in a single tap.
///
/// **No undo, no chord-reveal in v1.** Once a mine is revealed the
/// game is decided; the face-icon reset is the "start over" gesture.
/// Chord-reveal (tapping a revealed number cell to cascade-reveal
/// neighbors when the flag count matches) is a v2 follow-on.
library;

import 'dart:math';

/// The three classic Minesweeper difficulty presets. The Microsoft
/// defaults — 9×9 / 10 mines, 16×16 / 40 mines, 16×30 / 99 mines —
/// are the only "difficulty" knob in v1.
enum MinesweeperDifficulty {
  beginner(rows: 9, cols: 9, mineCount: 10),
  intermediate(rows: 16, cols: 16, mineCount: 40),
  expert(rows: 16, cols: 30, mineCount: 99);

  const MinesweeperDifficulty({
    required this.rows,
    required this.cols,
    required this.mineCount,
  });

  final int rows;
  final int cols;
  final int mineCount;

  String get label => switch (this) {
    MinesweeperDifficulty.beginner => 'Beginner',
    MinesweeperDifficulty.intermediate => 'Intermediate',
    MinesweeperDifficulty.expert => 'Expert',
  };
}

sealed class MinesweeperState {
  const MinesweeperState();
}

final class MinesweeperPlaying extends MinesweeperState {
  const MinesweeperPlaying();
}

final class MinesweeperWon extends MinesweeperState {
  const MinesweeperWon();
}

final class MinesweeperLost extends MinesweeperState {
  /// The mine that ended the game. `null` for state-rehydration from
  /// save (we don't track the specific mine across saves).
  final (int, int)? triggeredAt;

  const MinesweeperLost({this.triggeredAt});

  const MinesweeperLost.triggered(this.triggeredAt);
}

/// A single cell on the board. `isMine` is meaningful only after
/// [MinesweeperModel.minesPlaced] is true. `revealed` and `flagged`
/// are user-driven state. A flagged cell is never revealed (the
/// model refuses the reveal).
class MinesweeperCell {
  const MinesweeperCell({
    this.isMine = false,
    this.revealed = false,
    this.flagged = false,
  });

  final bool isMine;
  final bool revealed;
  final bool flagged;

  MinesweeperCell copyWith({bool? isMine, bool? revealed, bool? flagged}) =>
      MinesweeperCell(
        isMine: isMine ?? this.isMine,
        revealed: revealed ?? this.revealed,
        flagged: flagged ?? this.flagged,
      );
}

class MinesweeperModel {
  /// Build a model with a known difficulty. The minefield is *not*
  /// generated at construction — it is built lazily on the first
  /// reveal so the tapped cell + 8 neighbors are guaranteed safe.
  /// Pinned by [seed] for tests and save/restore.
  MinesweeperModel({required this.difficulty, this.seed})
    : _rows = List.generate(
        difficulty.rows,
        (_) => List<MinesweeperCell>.generate(
          difficulty.cols,
          (_) => const MinesweeperCell(),
        ),
      ),
      _state = const MinesweeperPlaying(),
      elapsedSeconds = 0;

  /// Convenience factory for "new game" buttons and tests.
  factory MinesweeperModel.deal({
    required MinesweeperDifficulty difficulty,
    int? seed,
  }) {
    return MinesweeperModel(difficulty: difficulty, seed: seed);
  }

  final MinesweeperDifficulty difficulty;
  final int? seed;

  /// Public, read-only accessor for tests and the home screen.
  int get rows => difficulty.rows;
  int get cols => difficulty.cols;
  int get totalMines => difficulty.mineCount;

  /// 2D grid of cells. Indexed `_rows[row][col]`. Mutated in place.
  final List<List<MinesweeperCell>> _rows;

  /// Current game state. Flips to [MinesweeperLost] when a mine is
  /// revealed, [MinesweeperWon] when all safe cells are revealed.
  MinesweeperState _state;
  MinesweeperState get state => _state;

  /// Seconds elapsed since the deal. The screen drives the timer and
  /// reads it for the status bar. Stored on the model so it can
  /// survive save / restore.
  int elapsedSeconds;

  /// True once the minefield has been generated. Always false after
  /// construction; flips to true on the first [reveal] call.
  bool get minesPlaced => _minesPlaced;
  bool _minesPlaced = false;

  /// Number of flagged cells. Surfaced for the mine counter pill.
  int get flagCount {
    var n = 0;
    for (final row in _rows) {
      for (final cell in row) {
        if (cell.flagged) n++;
      }
    }
    return n;
  }

  /// Read a cell. Returns a default cell for out-of-bounds queries
  /// (so callers don't have to bounds-check before computing the
  /// neighbor count for a corner).
  MinesweeperCell cellAt(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      return const MinesweeperCell();
    }
    return _rows[row][col];
  }

  /// Count of mines in the 8 neighbors of (row, col). Out-of-bounds
  /// neighbors are treated as non-mines, so a corner cell returns the
  /// count of mines in its 3 neighbors.
  int adjacentMinesAt(int row, int col) {
    var n = 0;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        if (cellAt(row + dr, col + dc).isMine) n++;
      }
    }
    return n;
  }

  /// Reveal a cell. If this is the first reveal, the minefield is
  /// generated first with the tapped cell + 8 neighbors guaranteed
  /// safe. Reveal of a 0-adjacency cell cascades to all reachable
  /// 0-cells and their number-neighbors. Reveal of a mine flips
  /// state to [MinesweeperLost]. Reveal of the last safe cell
  /// flips state to [MinesweeperWon].
  ///
  /// Flagged cells are not revealed (the user must remove the flag
  /// first). Already-revealed cells are a no-op.
  void reveal(int row, int col) {
    if (_state is! MinesweeperPlaying) return;
    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    final cell = _rows[row][col];
    if (cell.revealed || cell.flagged) return;

    if (!_minesPlaced) {
      _placeMines(row, col);
    }

    if (_rows[row][col].isMine) {
      _rows[row][col] = cell.copyWith(revealed: true);
      _state = MinesweeperLost.triggered((row, col));
      return;
    }

    _cascadeReveal(row, col);
    _checkWin();
  }

  /// Toggle a flag on a hidden cell. No-op on a revealed cell.
  void toggleFlag(int row, int col) {
    if (_state is! MinesweeperPlaying) return;
    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    final cell = _rows[row][col];
    if (cell.revealed) return;
    _rows[row][col] = cell.copyWith(flagged: !cell.flagged);
  }

  /// Reset the board. Clears all cells, discards the minefield, and
  /// returns to [MinesweeperPlaying]. The next reveal will generate
  /// a fresh minefield.
  void restart() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        _rows[r][c] = const MinesweeperCell();
      }
    }
    _minesPlaced = false;
    _state = const MinesweeperPlaying();
  }

  /// Increment the elapsed timer. Called by the screen's 1Hz
  /// `Timer.periodic`. Ignored when the game is not in
  /// [MinesweeperPlaying].
  void tick(int seconds) {
    if (seconds <= 0) return;
    if (_state is! MinesweeperPlaying) return;
    elapsedSeconds += seconds;
  }

  // ─── Mine placement ────────────────────────────────────────────────

  /// Generate the minefield. Mines are placed uniformly at random
  /// across all cells *except* the safe zone (the tapped cell + 8
  /// neighbors). The total mine count is unchanged.
  void _placeMines(int safeRow, int safeCol) {
    final total = rows * cols;
    final safeZone = <int>{};
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = safeRow + dr;
        final c = safeCol + dc;
        if (r >= 0 && r < rows && c >= 0 && c < cols) {
          safeZone.add(r * cols + c);
        }
      }
    }
    final available = total - safeZone.length;
    if (difficulty.mineCount > available) {
      throw StateError(
        'Difficulty $difficulty asks for ${difficulty.mineCount} mines '
        'but only $available non-safe cells are available',
      );
    }

    final rng = Random(seed);
    final mineIndices = _pickRandomIndices(
      count: difficulty.mineCount,
      maxExclusive: total,
      exclude: safeZone,
      rng: rng,
    );

    for (final idx in mineIndices) {
      final r = idx ~/ cols;
      final c = idx % cols;
      _rows[r][c] = _rows[r][c].copyWith(isMine: true);
    }
    _minesPlaced = true;
  }

  /// Pick `count` distinct random integers in `[0, maxExclusive)`,
  /// excluding any index in `exclude`. Uses Floyd's algorithm for
  /// small `count / maxExclusive` ratios; falls back to a shuffle
  /// for tighter ratios.
  Set<int> _pickRandomIndices({
    required int count,
    required int maxExclusive,
    required Set<int> exclude,
    required Random rng,
  }) {
    if (count < 0 || count > maxExclusive - exclude.length) {
      throw StateError('Cannot pick $count indices from $maxExclusive');
    }
    final picked = <int>{};
    if (count.toDouble() < (maxExclusive - exclude.length) * 0.3) {
      // Floyd's algorithm — O(count) for small counts.
      while (picked.length < count) {
        final candidate = rng.nextInt(maxExclusive);
        if (exclude.contains(candidate)) continue;
        picked.add(candidate);
      }
    } else {
      // Shuffle and take — O(maxExclusive).
      final pool = [
        for (var i = 0; i < maxExclusive; i++)
          if (!exclude.contains(i)) i,
      ]..shuffle(rng);
      picked.addAll(pool.take(count));
    }
    return picked;
  }

  // ─── Cascade reveal ────────────────────────────────────────────────

  /// Reveal a 0-adjacency cell and all reachable 0-cells (and their
  /// number-neighbors). Uses an explicit stack to avoid recursion
  /// blowing the stack on a 16×30 board with a huge empty region.
  void _cascadeReveal(int startRow, int startCol) {
    final stack = <(int, int)>[(startRow, startCol)];
    while (stack.isNotEmpty) {
      final (r, c) = stack.removeLast();
      final cell = _rows[r][c];
      if (cell.revealed || cell.flagged) continue;
      _rows[r][c] = cell.copyWith(revealed: true);
      if (adjacentMinesAt(r, c) == 0) {
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            final neighbor = _rows[nr][nc];
            if (neighbor.revealed || neighbor.flagged) continue;
            if (neighbor.isMine) continue;
            stack.add((nr, nc));
          }
        }
      }
    }
  }

  /// Win when every non-mine cell is revealed.
  void _checkWin() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = _rows[r][c];
        if (!cell.isMine && !cell.revealed) return;
      }
    }
    _state = const MinesweeperWon();
  }

  // ─── Save / restore ────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'version': 1,
    'difficulty': difficulty.name,
    'seed': seed,
    'elapsedSeconds': elapsedSeconds,
    'minesPlaced': _minesPlaced,
    'cells': [
      for (final row in _rows)
        [
          for (final cell in row)
            {
              'mine': cell.isMine,
              'revealed': cell.revealed,
              'flagged': cell.flagged,
            },
        ],
    ],
    'state': switch (_state) {
      MinesweeperPlaying() => 'playing',
      MinesweeperWon() => 'won',
      MinesweeperLost() => 'lost',
    },
  };

  factory MinesweeperModel.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int || version != 1) {
      throw const FormatException('Unsupported Minesweeper save version');
    }
    final diffName = json['difficulty'] as String?;
    final difficulty = MinesweeperDifficulty.values.firstWhere(
      (d) => d.name == diffName,
      orElse: () =>
          throw const FormatException('Unknown Minesweeper difficulty in save'),
    );
    final model = MinesweeperModel(
      difficulty: difficulty,
      seed: json['seed'] as int?,
    );
    final cellsJson = json['cells'] as List?;
    if (cellsJson != null) {
      if (cellsJson.length != difficulty.rows) {
        throw const FormatException(
          'Minesweeper save cell rows do not match difficulty',
        );
      }
      for (var r = 0; r < difficulty.rows; r++) {
        final rowJson = cellsJson[r] as List;
        if (rowJson.length != difficulty.cols) {
          throw const FormatException(
            'Minesweeper save cell columns do not match difficulty',
          );
        }
        for (var c = 0; c < difficulty.cols; c++) {
          final entry = rowJson[c] as Map<String, dynamic>;
          model._rows[r][c] = MinesweeperCell(
            isMine: entry['mine'] as bool? ?? false,
            revealed: entry['revealed'] as bool? ?? false,
            flagged: entry['flagged'] as bool? ?? false,
          );
        }
      }
      model._minesPlaced = json['minesPlaced'] as bool? ?? false;
    }
    model.elapsedSeconds = json['elapsedSeconds'] as int? ?? 0;
    final stateName = json['state'] as String? ?? 'playing';
    model._state = switch (stateName) {
      'won' => const MinesweeperWon(),
      'lost' => const MinesweeperLost(),
      _ => const MinesweeperPlaying(),
    };
    return model;
  }
}
