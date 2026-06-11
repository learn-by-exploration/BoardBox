/// Value types for a Karuro (hybrid Kakuro/crossword) puzzle.
///
/// A puzzle is a rectangular grid of three cell kinds:
/// - **block** — a black cell, no entry.
/// - **clue** — a cell that may carry a down-clue (sum or word) and/or a
///   right-clue (sum or word). The clue's `entries` are the runs that start
///   at this cell.
/// - **entry** — a fillable cell that holds a single character (digit 1-9 or
///   letter A-Z).
///
/// Runs are first-class: an `entry` is either a `KaruroNumberEntry`
/// (digits 1-9, no repeats, sum equals the clue) or a `KaruroWordEntry`
/// (letters A-Z, spells the `answer`). The per-cell `solution` map bundled
/// with the puzzle is the source of truth for "show errors" — no runtime
/// solver is needed.
library;

/// Difficulty bucket used for the home screen tile and the setup screen.
enum KaruroDifficulty { easy, medium, hard }

/// Direction of a run.
enum KaruroDirection { across, down }

/// Sealed `KaruroEntry` — discriminated by `kind`.
sealed class KaruroEntry {
  const KaruroEntry({
    required this.id,
    required this.number,
    required this.direction,
    required this.startRow,
    required this.startCol,
    required this.length,
  });

  /// Stable id like "1A" or "2D" — used in the clue list and for tests.
  final String id;

  /// Numeric prefix used in the clue list (1, 2, 3, ...). Matches the
  /// crossword convention where the same number is shared by the across
  /// and down runs that start at the same cell.
  final int number;

  final KaruroDirection direction;
  final int startRow;
  final int startCol;
  final int length;

  /// 'number' or 'word' — discriminator for serialization.
  String get kind;

  /// Cells occupied by this entry (read-only view).
  List<(int, int)> get cells {
    final out = <(int, int)>[];
    final dr = direction == KaruroDirection.across ? 0 : 1;
    final dc = direction == KaruroDirection.across ? 1 : 0;
    for (int i = 0; i < length; i++) {
      out.add((startRow + dr * i, startCol + dc * i));
    }
    return List<(int, int)>.unmodifiable(out);
  }
}

/// A numeric-sum entry (Kakuro style). Digits 1-9, no repeats within the run,
/// sum equals `sum`.
final class KaruroNumberEntry extends KaruroEntry {
  const KaruroNumberEntry({
    required super.id,
    required super.number,
    required super.direction,
    required super.startRow,
    required super.startCol,
    required super.length,
    required this.sum,
  });

  @override
  String get kind => 'number';

  final int sum;
}

/// A word entry (crossword style). Letters A-Z, spells `answer`.
final class KaruroWordEntry extends KaruroEntry {
  const KaruroWordEntry({
    required super.id,
    required super.number,
    required super.direction,
    required super.startRow,
    required super.startCol,
    required super.length,
    required this.clue,
    required this.answer,
  });

  @override
  String get kind => 'word';

  final String clue;
  final String answer;
}

/// Cell kinds in the rendering grid.
sealed class KaruroCell {
  const KaruroCell();
}

/// A block (black) cell — not fillable.
final class KaruroBlockCell extends KaruroCell {
  const KaruroBlockCell();
}

/// An entry (fillable) cell.
final class KaruroEntryCell extends KaruroCell {
  const KaruroEntryCell();
}

/// Difficulty + metric annotations used by the picker and the test suite.
class KaruroMetrics {
  const KaruroMetrics({
    required this.maxNumericRunLength,
    required this.maxWordRunLength,
    required this.crossingsPerCell,
    required this.extremeSumShare,
  });

  /// Longest numeric run in the puzzle (in cells).
  final int maxNumericRunLength;

  /// Longest word run in the puzzle (in cells / letters).
  final int maxWordRunLength;

  /// Average number of runs that touch each entry cell. Always 2 in a
  /// standard Kakuro-style grid (one across, one down).
  final double crossingsPerCell;

  /// Fraction of numeric runs whose `sum` is at one of the easy extremes
  /// for its length (very high or very low), which is what makes easy
  /// puzzles "almost" arithmetic-only.
  final double extremeSumShare;

  factory KaruroMetrics.fromJson(Map<String, dynamic> json) {
    return KaruroMetrics(
      maxNumericRunLength: json['maxNumericRunLength'] as int,
      maxWordRunLength: json['maxWordRunLength'] as int,
      crossingsPerCell: (json['crossingsPerCell'] as num).toDouble(),
      extremeSumShare: (json['extremeSumShare'] as num).toDouble(),
    );
  }
}

/// An immutable Karuro puzzle — the bundle artifact.
class KaruroPuzzle {
  KaruroPuzzle({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.rows,
    required this.cols,
    required List<List<KaruroCell>> cells,
    required List<KaruroEntry> entries,
    required Map<String, String> solution,
    required this.metrics,
  }) : cells = List<List<KaruroCell>>.unmodifiable(
         cells.map(List<KaruroCell>.unmodifiable),
       ),
       entries = List<KaruroEntry>.unmodifiable(entries),
       solution = Map<String, String>.unmodifiable(solution) {
    _validate();
  }

  final String id;
  final String title;
  final KaruroDifficulty difficulty;
  final int rows;
  final int cols;
  final List<List<KaruroCell>> cells;
  final List<KaruroEntry> entries;
  final Map<String, String> solution;
  final KaruroMetrics metrics;

  /// Look up the solution value for a cell, or null if not in the solution.
  String? solutionAt(int row, int col) => solution[_cellKey(row, col)];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'difficulty': difficulty.name,
    'grid': {'rows': rows, 'cols': cols},
    'cells': cells
        .map(
          (row) => row
              .map(
                (c) => switch (c) {
                  KaruroBlockCell() => '#',
                  KaruroEntryCell() => ' ',
                },
              )
              .toList(),
        )
        .toList(),
    'entries': entries.map(_entryToJson).toList(),
    'solution': solution,
    'metrics': {
      'maxNumericRunLength': metrics.maxNumericRunLength,
      'maxWordRunLength': metrics.maxWordRunLength,
      'crossingsPerCell': metrics.crossingsPerCell,
      'extremeSumShare': metrics.extremeSumShare,
    },
  };

  static Map<String, dynamic> _entryToJson(KaruroEntry e) => {
    'id': e.id,
    'number': e.number,
    'direction': e.direction.name,
    'start': {'row': e.startRow, 'col': e.startCol},
    'length': e.length,
    'kind': e.kind,
    if (e is KaruroNumberEntry) 'sum': e.sum,
    if (e is KaruroWordEntry) ...{'clue': e.clue, 'answer': e.answer},
  };

  factory KaruroPuzzle.fromJson(Map<String, dynamic> json) {
    final grid = json['grid'] as Map<String, dynamic>;
    final rows = grid['rows'] as int;
    final cols = grid['cols'] as int;
    final rawCells = (json['cells'] as List).cast<List<dynamic>>();
    final cells = <List<KaruroCell>>[];
    for (int r = 0; r < rows; r++) {
      final row = rawCells[r].cast<dynamic>();
      final out = <KaruroCell>[];
      for (int c = 0; c < cols; c++) {
        final v = row[c];
        if (v is String && v.startsWith('#')) {
          out.add(const KaruroBlockCell());
        } else {
          out.add(const KaruroEntryCell());
        }
      }
      cells.add(out);
    }

    final entriesRaw = (json['entries'] as List).cast<Map<String, dynamic>>();
    final entries = <KaruroEntry>[];
    for (final e in entriesRaw) {
      final start = e['start'] as Map<String, dynamic>;
      entries.add(switch (e['kind'] as String) {
        'number' => KaruroNumberEntry(
          id: e['id'] as String,
          number: e['number'] as int,
          direction: KaruroDirection.values.byName(e['direction'] as String),
          startRow: start['row'] as int,
          startCol: start['col'] as int,
          length: e['length'] as int,
          sum: e['sum'] as int,
        ),
        'word' => KaruroWordEntry(
          id: e['id'] as String,
          number: e['number'] as int,
          direction: KaruroDirection.values.byName(e['direction'] as String),
          startRow: start['row'] as int,
          startCol: start['col'] as int,
          length: e['length'] as int,
          clue: e['clue'] as String,
          answer: e['answer'] as String,
        ),
        _ => throw FormatException('Unknown entry kind: ${e['kind']}'),
      });
    }

    final solutionRaw = (json['solution'] as Map).cast<String, dynamic>();
    final solution = <String, String>{
      for (final entry in solutionRaw.entries) entry.key: entry.value as String,
    };

    return KaruroPuzzle(
      id: json['id'] as String,
      title: json['title'] as String,
      difficulty: KaruroDifficulty.values.byName(json['difficulty'] as String),
      rows: rows,
      cols: cols,
      cells: cells,
      entries: entries,
      solution: solution,
      metrics: KaruroMetrics.fromJson(
        (json['metrics'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  /// Stable key used in the `solution` map.
  static String _cellKey(int row, int col) => '$row,$col';

  void _validate() {
    if (rows <= 0 || cols <= 0) {
      throw const FormatException('Karuro grid dimensions must be positive');
    }
    if (cells.length != rows || cells.any((r) => r.length != cols)) {
      throw const FormatException(
        'Karuro cells shape does not match declared grid size',
      );
    }
    for (final e in entries) {
      if (e.length < 1) {
        throw FormatException('Entry ${e.id} has length < 1');
      }
      final dr = e.direction == KaruroDirection.across ? 0 : 1;
      final dc = e.direction == KaruroDirection.across ? 1 : 0;
      for (int i = 0; i < e.length; i++) {
        final r = e.startRow + dr * i;
        final c = e.startCol + dc * i;
        if (r < 0 || r >= rows || c < 0 || c >= cols) {
          throw FormatException('Entry ${e.id} runs out of bounds at ($r, $c)');
        }
        if (cells[r][c] is! KaruroEntryCell) {
          throw FormatException(
            'Entry ${e.id} cell ($r, $c) is not a fillable cell',
          );
        }
      }
      if (e is KaruroWordEntry) {
        if (e.answer.length != e.length) {
          throw FormatException(
            'Word entry ${e.id} answer length ${e.answer.length} '
            'does not match run length ${e.length}',
          );
        }
        final expected = e.answer.toUpperCase();
        for (int i = 0; i < e.length; i++) {
          final r = e.startRow + dr * i;
          final c = e.startCol + dc * i;
          final v = solution[_cellKey(r, c)];
          if (v == null) {
            throw FormatException(
              'Word entry ${e.id} is missing solution at ($r, $c)',
            );
          }
          if (v.toUpperCase() != expected[i]) {
            throw FormatException(
              'Word entry ${e.id} solution at ($r, $c) is "$v", '
              'expected "${expected[i]}"',
            );
          }
        }
      } else if (e is KaruroNumberEntry) {
        for (int i = 0; i < e.length; i++) {
          final r = e.startRow + dr * i;
          final c = e.startCol + dc * i;
          final v = solution[_cellKey(r, c)];
          if (v == null) {
            throw FormatException(
              'Number entry ${e.id} is missing solution at ($r, $c)',
            );
          }
        }
      }
    }
  }
}
