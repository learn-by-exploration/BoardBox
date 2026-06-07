import 'package:fludoku/fludoku.dart';

enum SudokuDifficulty { easy, medium, hard }

class SudokuPuzzle {
  static const int cellCount = 81;

  SudokuPuzzle({
    required List<int> givens,
    required List<int> solution,
    required this.difficulty,
  }) : givens = List<int>.unmodifiable(givens),
       solution = List<int>.unmodifiable(solution) {
    _validate(this.givens, this.solution);
  }

  final List<int> givens;
  final List<int> solution;
  final SudokuDifficulty difficulty;

  bool isGiven(int index) => givens[index] != 0;

  Map<String, dynamic> toJson() => {
    'givens': givens,
    'solution': solution,
    'difficulty': difficulty.name,
  };

  factory SudokuPuzzle.fromJson(Map<String, dynamic> json) {
    final givens = (json['givens'] as List).cast<int>();
    final solution = (json['solution'] as List).cast<int>();
    return SudokuPuzzle(
      givens: givens,
      solution: solution,
      difficulty: SudokuDifficulty.values.byName(json['difficulty'] as String),
    );
  }

  static void _validate(List<int> givens, List<int> solution) {
    if (givens.length != cellCount || solution.length != cellCount) {
      throw const FormatException('Sudoku puzzles must contain 81 cells');
    }
    if (givens.any((value) => value < 0 || value > 9) ||
        solution.any((value) => value < 1 || value > 9)) {
      throw const FormatException('Sudoku cell values are out of range');
    }
    for (int index = 0; index < cellCount; index++) {
      if (givens[index] != 0 && givens[index] != solution[index]) {
        throw const FormatException('A given does not match the solution');
      }
    }
    if (!Board.withValues(_toRows(solution)).isComplete) {
      throw const FormatException('Sudoku solution is invalid');
    }
    final givenBoard = Board.withValues(_toRows(givens));
    if (!givenBoard.isValid || givenBoard.isComplete) {
      throw const FormatException('Sudoku givens are invalid');
    }
  }

  static List<List<int>> _toRows(List<int> cells) => List.generate(
    9,
    (row) => cells.sublist(row * 9, row * 9 + 9),
    growable: false,
  );
}

class SudokuPuzzleFactory {
  const SudokuPuzzleFactory();

  SudokuPuzzle generate(SudokuDifficulty difficulty, {int timeoutSeconds = 5}) {
    final (board, error) = generateSudokuPuzzle(
      level: switch (difficulty) {
        SudokuDifficulty.easy => PuzzleDifficulty.easy,
        SudokuDifficulty.medium => PuzzleDifficulty.medium,
        SudokuDifficulty.hard => PuzzleDifficulty.hard,
      },
      timeoutSecs: timeoutSeconds,
    );
    if (board == null) {
      throw StateError(error ?? 'Sudoku generation failed');
    }

    final solutions = findSolutions(board, maxSolutions: 2);
    if (solutions.length != 1) {
      throw StateError('Generated Sudoku puzzle is not uniquely solvable');
    }

    return SudokuPuzzle(
      givens: board.values.expand((row) => row).toList(growable: false),
      solution: solutions.single.values
          .expand((row) => row)
          .toList(growable: false),
      difficulty: difficulty,
    );
  }
}
