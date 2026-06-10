import 'package:common_games/games/sudoku/sudoku_puzzle.dart';

/// Top-level entrypoint used by [Isolate.run] to generate a puzzle on a
/// background thread. Pure function so the isolate doesn't capture any
/// Board Box state.
SudokuPuzzle generateSudokuPuzzleOnIsolate(SudokuDifficulty difficulty) {
  // We retry a few times: fludoku can return an invalid puzzle in rare cases,
  // and the UI's progress overlay should look responsive even if one attempt
  // is slow. The cap is small enough that the total worst-case latency
  // remains well below the user's patience threshold.
  for (int attempt = 0; attempt < 3; attempt++) {
    final puzzle = const SudokuPuzzleFactory().generate(difficulty);
    if (_isUsable(puzzle)) return puzzle;
  }
  // Final fallback: keep the last generated puzzle even if it failed the
  // sanity check — the model layer's fromJson will still reject a corrupted
  // puzzle, and the UI can surface a retry button.
  return const SudokuPuzzleFactory().generate(difficulty);
}

bool _isUsable(SudokuPuzzle puzzle) {
  // A freshly-generated Sudoku should have between 17 and 60 givens. The lower
  // bound is the proven minimum; the upper bound catches accidental
  // near-complete boards that the user wouldn't call a puzzle.
  var givenCount = 0;
  for (final value in puzzle.givens) {
    if (value != 0) givenCount++;
  }
  return givenCount >= 17 && givenCount <= 60;
}
