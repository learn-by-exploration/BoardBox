import 'dart:collection';

import 'package:common_games/games/sudoku/sudoku_puzzle.dart';

sealed class SudokuState {
  const SudokuState();
}

final class SudokuPlaying extends SudokuState {
  const SudokuPlaying();
}

final class SudokuCompleted extends SudokuState {
  const SudokuCompleted();
}

class SudokuModel {
  SudokuModel(this.puzzle)
    : _values = List<int>.from(puzzle.givens),
      _notes = List.generate(SudokuPuzzle.cellCount, (_) => <int>{}),
      state = const SudokuPlaying();

  final SudokuPuzzle puzzle;
  List<int> _values;
  List<Set<int>> _notes;
  SudokuState state;
  int mistakes = 0;
  int hintsUsed = 0;

  UnmodifiableListView<int> get values => UnmodifiableListView(_values);

  List<UnmodifiableSetView<int>> get notes =>
      _notes.map(UnmodifiableSetView<int>.new).toList(growable: false);

  bool enterValue(int index, int value) {
    _checkIndex(index);
    if (state is! SudokuPlaying ||
        puzzle.isGiven(index) ||
        value < 0 ||
        value > 9) {
      return false;
    }

    _values[index] = value;
    _notes[index].clear();
    if (value != 0 && value != puzzle.solution[index]) mistakes++;

    if (_values.indexed.every((cell) => cell.$2 == puzzle.solution[cell.$1])) {
      state = const SudokuCompleted();
    }
    return true;
  }

  bool toggleNote(int index, int value) {
    _checkIndex(index);
    if (state is! SudokuPlaying ||
        puzzle.isGiven(index) ||
        _values[index] != 0 ||
        value < 1 ||
        value > 9) {
      return false;
    }
    if (!_notes[index].add(value)) _notes[index].remove(value);
    return true;
  }

  bool revealHint(int index) {
    _checkIndex(index);
    if (state is! SudokuPlaying || puzzle.isGiven(index)) return false;
    final changed = _values[index] != puzzle.solution[index];
    _values[index] = puzzle.solution[index];
    _notes[index].clear();
    if (changed) hintsUsed++;
    if (_values.indexed.every((cell) => cell.$2 == puzzle.solution[cell.$1])) {
      state = const SudokuCompleted();
    }
    return changed;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'puzzle': puzzle.toJson(),
    'values': _values,
    'notes': _notes.map((notes) => notes.toList()..sort()).toList(),
    'mistakes': mistakes,
    'hintsUsed': hintsUsed,
    'completed': state is SudokuCompleted,
  };

  factory SudokuModel.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported Sudoku save version');
    }
    final puzzle = SudokuPuzzle.fromJson(
      (json['puzzle'] as Map).cast<String, dynamic>(),
    );
    final values = (json['values'] as List).cast<int>();
    final noteRows = json['notes'] as List;
    final mistakes = json['mistakes'] as int;
    final hintsUsed = json['hintsUsed'] as int;
    if (values.length != SudokuPuzzle.cellCount ||
        noteRows.length != SudokuPuzzle.cellCount ||
        values.any((value) => value < 0 || value > 9) ||
        mistakes < 0 ||
        hintsUsed < 0) {
      throw const FormatException('Invalid Sudoku save data');
    }

    final parsedNotes = <Set<int>>[];
    for (final notes in noteRows) {
      final values = (notes as List).cast<int>();
      if (values.any((value) => value < 1 || value > 9)) {
        throw const FormatException('Invalid Sudoku note value');
      }
      parsedNotes.add(values.toSet());
    }

    final model = SudokuModel(puzzle)
      .._values = List<int>.from(values)
      .._notes = parsedNotes
      ..mistakes = mistakes
      ..hintsUsed = hintsUsed;

    for (int index = 0; index < SudokuPuzzle.cellCount; index++) {
      if (puzzle.isGiven(index) &&
          model._values[index] != puzzle.givens[index]) {
        throw const FormatException('A fixed Sudoku cell was modified');
      }
      if (model._values[index] != 0) model._notes[index].clear();
    }
    final isComplete = model._values.indexed.every(
      (cell) => cell.$2 == puzzle.solution[cell.$1],
    );
    if ((json['completed'] as bool) != isComplete) {
      throw const FormatException('Sudoku completion state is inconsistent');
    }
    model.state = isComplete ? const SudokuCompleted() : const SudokuPlaying();
    return model;
  }

  void _checkIndex(int index) {
    if (index < 0 || index >= SudokuPuzzle.cellCount) {
      throw RangeError.index(index, _values, 'index');
    }
  }
}
