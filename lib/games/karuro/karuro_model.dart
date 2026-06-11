import 'dart:collection';

import 'package:common_games/games/karuro/karuro_puzzle.dart';

/// Game state for a Karuro puzzle.
sealed class KaruroState {
  const KaruroState();
}

/// Player can still enter and erase values.
final class KaruroPlaying extends KaruroState {
  const KaruroPlaying();
}

/// Every cell in the puzzle's solution has been filled correctly.
final class KaruroWon extends KaruroState {
  const KaruroWon();
}

/// Pure-Dart game logic for Karuro (hybrid Kakuro/crossword).
///
/// The model takes a [KaruroPuzzle] at construction; the puzzle's per-cell
/// `solution` map is the source of truth for "show errors" and for win
/// detection. There is no runtime solver and no generation.
class KaruroModel {
  KaruroModel(this.puzzle)
    : _values = List<String?>.filled(puzzle.rows * puzzle.cols, null),
      _history = <_Mutation>[],
      state = const KaruroPlaying();

  /// The puzzle this model is bound to. The model never mutates the puzzle.
  final KaruroPuzzle puzzle;

  /// Flattened (row-major) value grid. `null` = empty cell.
  final List<String?> _values;

  /// Mutation history for undo. Each frame is a single cell write.
  final List<_Mutation> _history;

  KaruroState state;

  /// Read-only view of the current values.
  UnmodifiableListView<String?> get values =>
      UnmodifiableListView<String?>(_values);

  /// Look up the value at (row, col), or `null` if the cell is empty.
  String? valueAt(int row, int col) => _values[_index(row, col)];

  /// True when every cell in the puzzle's solution has been filled and
  /// matches. Empty cells outside the solution map (e.g. block cells) are
  /// ignored.
  bool get isWon {
    if (state is KaruroWon) return true;
    for (int r = 0; r < puzzle.rows; r++) {
      for (int c = 0; c < puzzle.cols; c++) {
        if (puzzle.cells[r][c] is! KaruroEntryCell) continue;
        final expected = puzzle.solutionAt(r, c);
        if (expected == null) continue;
        if (_values[_index(r, c)] != expected) return false;
      }
    }
    return true;
  }

  /// Flat index of (row, col) in [_values] (row-major).
  int _index(int row, int col) => row * puzzle.cols + col;

  /// Enter a character (digit 1-9 or letter A-Z) at (row, col).
  /// Throws [ArgumentError] if the cell is not an entry cell. Returns `true`
  /// if the value was applied, `false` if it matched the existing value (no
  /// change).
  bool enterValue(int row, int col, String value) {
    if (state is KaruroWon) return false;
    _assertEntryCell(row, col);
    final normalized = value.toUpperCase();
    final idx = _index(row, col);
    if (_values[idx] == normalized) return false;
    _history.add(_Mutation(idx, _values[idx]));
    _values[idx] = normalized;
    if (isWon) {
      state = const KaruroWon();
    }
    return true;
  }

  /// Clear the value at (row, col). Returns `true` if a value was removed.
  bool erase(int row, int col) {
    if (state is KaruroWon) return false;
    _assertEntryCell(row, col);
    final idx = _index(row, col);
    if (_values[idx] == null) return false;
    _history.add(_Mutation(idx, _values[idx]));
    _values[idx] = null;
    return true;
  }

  /// Revert the last mutation. Returns `true` if there was something to undo.
  bool undo() {
    if (_history.isEmpty) return false;
    final last = _history.removeLast();
    _values[last.index] = last.previous;
    if (state is KaruroWon) state = const KaruroPlaying();
    return true;
  }

  /// True when the model has any undo history.
  bool get canUndo => _history.isNotEmpty;

  /// Indices (in the flat value grid) of cells whose current value does not
  /// match the puzzle's solution. Cells that aren't in the solution are
  /// ignored. O(filled-cells).
  Set<int> wrongCells() {
    final wrong = <int>{};
    for (int r = 0; r < puzzle.rows; r++) {
      for (int c = 0; c < puzzle.cols; c++) {
        if (puzzle.cells[r][c] is! KaruroEntryCell) continue;
        final idx = _index(r, c);
        final v = _values[idx];
        if (v == null) continue;
        final expected = puzzle.solutionAt(r, c);
        if (expected == null) continue;
        if (v.toUpperCase() != expected.toUpperCase()) {
          wrong.add(idx);
        }
      }
    }
    return wrong;
  }

  /// Indices of cells in numeric runs that violate the rule constraints
  /// (duplicate digit within a run, or sum not equal to the clue once the
  /// run is fully filled). Cells in word runs are not included. Distinct
  /// from [wrongCells]: a cell can be "rule-error" (duplicate in its
  /// numeric run) without being "wrong" (matching the per-cell solution
  /// key) if the puzzle was authored loosely. The solution key is the
  /// source of truth — this is convenience feedback.
  Set<int> runRuleErrorCells() {
    final out = <int>{};
    for (final entry in puzzle.entries) {
      if (entry is! KaruroNumberEntry) continue;
      final seen = <String, int>{};
      int sum = 0;
      bool allFilled = true;
      final cells = entry.cells;
      for (final cell in cells) {
        final v = _values[_index(cell.$1, cell.$2)];
        if (v == null) {
          allFilled = false;
          continue;
        }
        sum += int.parse(v);
        final prior = seen[v];
        if (prior != null) {
          out.add(_index(cell.$1, cell.$2));
          out.add(prior);
        } else {
          seen[v] = _index(cell.$1, cell.$2);
        }
      }
      if (allFilled && sum != entry.sum) {
        for (final cell in cells) {
          out.add(_index(cell.$1, cell.$2));
        }
      }
    }
    return out;
  }

  void _assertEntryCell(int row, int col) {
    if (row < 0 || row >= puzzle.rows || col < 0 || col >= puzzle.cols) {
      throw ArgumentError('Cell ($row, $col) is out of bounds');
    }
    if (puzzle.cells[row][col] is! KaruroEntryCell) {
      throw ArgumentError('Cell ($row, $col) is not a fillable cell');
    }
  }

  /// Versioned save payload. Bump [saveVersion] when the shape changes.
  static const int saveVersion = 1;

  Map<String, dynamic> toJson() => {
    'version': saveVersion,
    'puzzleId': puzzle.id,
    'state': _stateToJson(state),
    'values': _values.map((v) => v).toList(growable: false),
    'history': _history.map((m) => m.toJson()).toList(growable: false),
  };

  static Map<String, dynamic> _stateToJson(KaruroState s) {
    if (s is KaruroWon) return {'type': 'won'};
    return {'type': 'playing'};
  }

  static KaruroState _stateFromJson(Map<String, dynamic> j) {
    final type = j['type'];
    if (type == 'won') return const KaruroWon();
    if (type == 'playing') return const KaruroPlaying();
    throw FormatException('Unknown Karuro state type: $type');
  }

  /// Restore a save. Throws [FormatException] if the save's puzzleId is not
  /// present in the bundle; that is treated as a corrupt save (the caller
  /// can catch and clear the bad save to start fresh).
  static KaruroModel fromJson(
    Map<String, dynamic> json,
    KaruroPuzzle? Function(String id) lookup,
  ) {
    final version = json['version'];
    if (version != saveVersion) {
      throw FormatException(
        'Karuro save version mismatch: got $version, expected $saveVersion',
      );
    }
    final puzzleId = json['puzzleId'] as String;
    final puzzle = lookup(puzzleId);
    if (puzzle == null) {
      throw FormatException('Karuro save references unknown puzzle: $puzzleId');
    }

    final model = KaruroModel(puzzle);
    final valuesRaw = (json['values'] as List).cast<String?>();
    if (valuesRaw.length != model._values.length) {
      throw FormatException(
        'Karuro save has ${valuesRaw.length} values, '
        'expected ${model._values.length}',
      );
    }
    for (int i = 0; i < valuesRaw.length; i++) {
      model._values[i] = valuesRaw[i];
    }
    model.state = _stateFromJson(
      (json['state'] as Map).cast<String, dynamic>(),
    );
    final historyRaw = (json['history'] as List).cast<Map<String, dynamic>>();
    for (final entry in historyRaw) {
      model._history.add(_Mutation.fromJson(entry));
    }
    return model;
  }
}

/// A single cell-write frame for the undo stack.
class _Mutation {
  const _Mutation(this.index, this.previous);

  final int index;
  final String? previous;

  Map<String, dynamic> toJson() => {'index': index, 'previous': previous};

  static _Mutation fromJson(Map<String, dynamic> j) =>
      _Mutation(j['index'] as int, j['previous'] as String?);
}
