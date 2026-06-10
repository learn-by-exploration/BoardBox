/// Validators used by every game's `*Model.fromJson` to throw a uniform
/// `FormatException` on corrupt or forward-incompatible save data.
///
/// Why this lives in one place: previously, every `fromJson` directly indexed
/// into `Enum.values[i]`, which throws `RangeError` — and the restore
/// pipeline in `GameScreen._tryRestoreGame` only catches `FormatException` and
/// `TypeError`. A single bad save (e.g. a forward-compatible enum value) was
/// crashing the entire game screen. These helpers close the gap.
library;

/// Reads a list-of-lists (the standard "board" JSON shape) and validates its
/// outer/inner lengths and cell values.
///
/// [expectedOuter] is the number of rows (and also the row width for a square
/// board). [expectedInner] is the column count (use the same value as
/// [expectedOuter] for square boards). [isValidCell] is invoked for each
/// non-null cell; if it returns `false`, throws `FormatException`.
///
/// On any failure, throws a `FormatException` with a descriptive message so
/// the caller can clear the bad save and start fresh.
List<List<T?>> readBoard<T>(
  Map<String, dynamic> json,
  String key, {
  required int expectedOuter,
  required int expectedInner,
  required bool Function(dynamic raw) isValidCell,
}) {
  final raw = json[key];
  if (raw is! List) {
    throw FormatException('Missing or invalid board list at "$key"');
  }
  if (raw.length != expectedOuter) {
    throw FormatException(
      '"$key" has ${raw.length} rows, expected $expectedOuter',
    );
  }
  final board = <List<T?>>[];
  for (int r = 0; r < expectedOuter; r++) {
    final row = raw[r];
    if (row is! List) {
      throw FormatException('"$key" row $r is not a list');
    }
    if (row.length != expectedInner) {
      throw FormatException(
        '"$key" row $r has ${row.length} cols, expected $expectedInner',
      );
    }
    final outRow = <T?>[];
    for (int c = 0; c < expectedInner; c++) {
      final cell = row[c];
      if (cell == null) {
        outRow.add(null);
      } else {
        if (!isValidCell(cell)) {
          throw FormatException('"$key" cell ($r, $c) is invalid: $cell');
        }
        outRow.add(cell as T);
      }
    }
    board.add(outRow);
  }
  return board;
}

/// Decodes an enum `index` field and throws `FormatException` (not
/// `RangeError`) if it is out of range.
T readEnumByIndex<T extends Enum>(
  List<T> values,
  Map<String, dynamic> json,
  String key, {
  String? enumName,
}) {
  final raw = json[key];
  if (raw is! int) {
    throw FormatException('"$key" is not an int: $raw');
  }
  if (raw < 0 || raw >= values.length) {
    throw FormatException(
      '"$key" $raw is out of range for ${enumName ?? T.toString()} '
      '(valid: 0..${values.length - 1})',
    );
  }
  return values[raw];
}

/// Decodes a state-type discriminator. Throws if the type is unknown, instead
/// of silently falling back to "playing" (which would freeze the game).
T readStateType<T>({
  required Map<String, dynamic> stateJson,
  required Map<String, T Function(Map<String, dynamic>)> cases,
}) {
  final type = stateJson['type'];
  if (type is! String || !cases.containsKey(type)) {
    throw FormatException('Unknown state type: $type');
  }
  return cases[type]!(stateJson);
}
