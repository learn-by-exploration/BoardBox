import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/sudoku/sudoku_isolate.dart';
import 'package:common_games/games/sudoku/sudoku_puzzle.dart';

void main() {
  test('isolate entrypoint generates a usable puzzle', () {
    final puzzle = generateSudokuPuzzleOnIsolate(SudokuDifficulty.easy);
    expect(puzzle.givens, hasLength(81));
    expect(puzzle.solution, hasLength(81));
    expect(puzzle.givens, contains(0));
    for (int index = 0; index < 81; index++) {
      if (puzzle.givens[index] != 0) {
        expect(puzzle.givens[index], puzzle.solution[index]);
      }
    }
  });
}
