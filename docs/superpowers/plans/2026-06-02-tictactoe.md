# Tic Tac Toe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Tic Tac Toe with selectable 3×3, 4×4, and 5×5 board sizes to the Board Box Flutter app, with full AI support at three difficulty levels.

**Architecture:** Two new files follow the existing game pattern: a pure-Dart `tictactoe_model.dart` (n×n board, k-in-a-row win detection, board evaluation heuristic) and `tictactoe_board.dart` (Flutter widget, CustomPaint rendering for X/O, minimax AI with alpha-beta for 4×4/5×5). `ModeSelectScreen` is converted to a `StatefulWidget` to host the size-chip selector shown only for TicTacToe. `GameScreen` gains an optional `boardSize` int parameter that routes to `TicTacToeBoard`.

**Tech Stack:** Flutter / Dart, no new pub dependencies. AI: pure minimax (3×3), alpha-beta depth 6 (4×4), alpha-beta depth 4 + heuristic (5×5). Win conditions: 3→3-in-a-row, 4→4-in-a-row, 5→4-in-a-row (standard per m,n,k-game theory).

**Project root:** `/home/shyam/common_games/board_box`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/games/tictactoe/tictactoe_model.dart` | **Create** | Pure Dart model: n×n board, k-in-a-row win, evaluate heuristic, toJson/fromJson |
| `lib/games/tictactoe/tictactoe_board.dart` | **Create** | Flutter board widget, X/O CustomPaint renderer, minimax/alpha-beta AI |
| `test/tictactoe_model_test.dart` | **Create** | Unit tests: win detection, draw, invalid moves, serialization |
| `lib/screens/home_screen.dart` | Modify | Add `tictactoe` to `GameType` enum and game card list |
| `lib/screens/mode_select_screen.dart` | Modify | Convert to StatefulWidget; add board-size chip row for TicTacToe |
| `lib/screens/game_screen.dart` | Modify | Add `boardSize` param; route to TicTacToeBoard; add `'x wins'` stat token |

---

## Task 1 — TicTacToe model (pure Dart)

**Files:**
- Create: `lib/games/tictactoe/tictactoe_model.dart`
- Test: `test/tictactoe_model_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/tictactoe_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/tictactoe/tictactoe_model.dart';

void main() {
  group('TicTacToeModel — 3×3', () {
    test('starts with X, Playing, empty board', () {
      final m = TicTacToeModel(size: 3);
      expect(m.current, TicTacToePlayer.x);
      expect(m.state, isA<TicTacToePlaying>());
      expect(m.board.expand((r) => r).every((c) => c == null), isTrue);
    });

    test('play returns false on occupied cell', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      expect(m.play(0, 0), isFalse);
    });

    test('alternates turns', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0);
      expect(m.current, TicTacToePlayer.o);
      m.play(1, 1);
      expect(m.current, TicTacToePlayer.x);
    });

    test('detects row win for X', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(1, 0); // X, O
      m.play(0, 1); m.play(1, 1); // X, O
      m.play(0, 2); // X wins row 0
      expect(m.state, isA<TicTacToeWin>());
      expect((m.state as TicTacToeWin).winner, TicTacToePlayer.x);
    });

    test('detects column win', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(0, 1); // X, O
      m.play(1, 0); m.play(0, 2); // X, O
      m.play(2, 0); // X wins col 0
      expect(m.state, isA<TicTacToeWin>());
    });

    test('detects diagonal win', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(0, 1); // X, O
      m.play(1, 1); m.play(0, 2); // X, O
      m.play(2, 2); // X wins diagonal
      expect(m.state, isA<TicTacToeWin>());
    });

    test('detects draw', () {
      final m = TicTacToeModel(size: 3);
      // X O X
      // X X O
      // O X O  → draw
      m.play(0, 0); m.play(0, 1);
      m.play(0, 2); m.play(1, 2);
      m.play(1, 0); m.play(2, 0);
      m.play(1, 1); m.play(2, 2);
      m.play(2, 1);
      expect(m.state, isA<TicTacToeDraw>());
    });

    test('play returns false after game over', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); // X wins
      expect(m.play(2, 2), isFalse);
    });

    test('restart resets to initial state', () {
      final m = TicTacToeModel(size: 3);
      m.play(0, 0); m.play(0, 1); m.play(0, 2);
      m.play(1, 0); m.play(1, 1);
      m.play(1, 2);
      m.restart();
      expect(m.state, isA<TicTacToePlaying>());
      expect(m.current, TicTacToePlayer.x);
      expect(m.board.expand((r) => r).every((c) => c == null), isTrue);
    });
  });

  group('TicTacToeModel — 4×4', () {
    test('win length is 4', () {
      expect(TicTacToeModel.winLengthFor(4), 4);
    });

    test('3 in a row does NOT win on 4×4', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); // X has 3 in a row — should still be Playing
      expect(m.state, isA<TicTacToePlaying>());
    });

    test('4 in a row wins on 4×4', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); m.play(1, 2);
      m.play(0, 3); // X wins row 0
      expect(m.state, isA<TicTacToeWin>());
    });
  });

  group('TicTacToeModel — 5×5', () {
    test('win length is 4', () {
      expect(TicTacToeModel.winLengthFor(5), 4);
    });

    test('4 in a row wins on 5×5', () {
      final m = TicTacToeModel(size: 5);
      m.play(0, 0); m.play(1, 0);
      m.play(0, 1); m.play(1, 1);
      m.play(0, 2); m.play(1, 2);
      m.play(0, 3); // X has 4 in a row
      expect(m.state, isA<TicTacToeWin>());
    });
  });

  group('Serialization', () {
    test('toJson/fromJson round-trips correctly', () {
      final m = TicTacToeModel(size: 4);
      m.play(0, 0); m.play(1, 1); m.play(0, 1);
      final json = m.toJson();
      final restored = TicTacToeModel.fromJson(json);
      expect(restored.size, 4);
      expect(restored.current, m.current);
      expect(restored.board[0][0], TicTacToePlayer.x);
      expect(restored.board[1][1], TicTacToePlayer.o);
      expect(restored.board[0][1], TicTacToePlayer.x);
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm they all fail**

```
flutter test test/tictactoe_model_test.dart
```
Expected: compilation error (file doesn't exist yet).

- [ ] **Step 3: Create `lib/games/tictactoe/tictactoe_model.dart`**

```dart
import 'dart:collection';
import 'dart:math' as math;

enum TicTacToePlayer { x, o }

sealed class TicTacToeState {
  const TicTacToeState();
}

final class TicTacToePlaying extends TicTacToeState {
  const TicTacToePlaying();
}

final class TicTacToeWin extends TicTacToeState {
  const TicTacToeWin(this.winner);
  final TicTacToePlayer winner;
}

final class TicTacToeDraw extends TicTacToeState {
  const TicTacToeDraw();
}

class TicTacToeModel {
  /// Win length for a given board size:
  /// 3×3 → 3-in-a-row, 4×4 and 5×5 → 4-in-a-row.
  static int winLengthFor(int size) => size == 3 ? 3 : 4;

  final int size;
  final int winLength;

  List<List<TicTacToePlayer?>> _board;
  TicTacToePlayer current;
  TicTacToeState state;
  int? lastRow;
  int? lastCol;

  TicTacToeModel({required this.size})
      : winLength = winLengthFor(size),
        _board = List.generate(size, (_) => List.filled(size, null)),
        current = TicTacToePlayer.x,
        state = const TicTacToePlaying();

  List<UnmodifiableListView<TicTacToePlayer?>> get board =>
      _board.map(UnmodifiableListView<TicTacToePlayer?>.new).toList();

  List<(int, int)> get emptyCells {
    final cells = <(int, int)>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == null) cells.add((r, c));
      }
    }
    return cells;
  }

  void restart() {
    _board = List.generate(size, (_) => List.filled(size, null));
    current = TicTacToePlayer.x;
    state = const TicTacToePlaying();
    lastRow = null;
    lastCol = null;
  }

  bool play(int row, int col) {
    if (state is! TicTacToePlaying) return false;
    if (row < 0 || row >= size || col < 0 || col >= size) return false;
    if (_board[row][col] != null) return false;

    _board[row][col] = current;
    lastRow = row;
    lastCol = col;

    if (_checkWin(row, col, current)) {
      state = TicTacToeWin(current);
    } else if (emptyCells.isEmpty) {
      state = const TicTacToeDraw();
    } else {
      current = current == TicTacToePlayer.x
          ? TicTacToePlayer.o
          : TicTacToePlayer.x;
    }
    return true;
  }

  bool _checkWin(int row, int col, TicTacToePlayer player) {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (final d in dirs) {
      int count = 1;
      // Positive direction
      int r = row + d.$1, c = col + d.$2;
      while (r >= 0 && c >= 0 && r < size && c < size &&
          _board[r][c] == player) {
        count++;
        r += d.$1;
        c += d.$2;
      }
      // Negative direction
      r = row - d.$1;
      c = col - d.$2;
      while (r >= 0 && c >= 0 && r < size && c < size &&
          _board[r][c] == player) {
        count++;
        r -= d.$1;
        c -= d.$2;
      }
      if (count >= winLength) return true;
    }
    return false;
  }

  /// Heuristic board evaluation for non-terminal states.
  /// Returns a score > 0 when [forPlayer] is ahead, < 0 when behind.
  /// Uses the line-scan method: each unblocked line scores 10^(pieces_in_line).
  int evaluate(TicTacToePlayer forPlayer) {
    final s = state;
    if (s is TicTacToeWin) {
      return s.winner == forPlayer ? 1000000 : -1000000;
    }
    if (s is TicTacToeDraw) return 0;

    final opponent = forPlayer == TicTacToePlayer.x
        ? TicTacToePlayer.o
        : TicTacToePlayer.x;
    int score = 0;

    for (final line in _allLinesOfWinLength()) {
      int mine = 0, theirs = 0;
      for (final cell in line) {
        final v = _board[cell.$1][cell.$2];
        if (v == forPlayer) mine++;
        else if (v == opponent) theirs++;
      }
      if (mine > 0 && theirs == 0) score += math.pow(10, mine).toInt();
      if (theirs > 0 && mine == 0) score -= math.pow(10, theirs).toInt();
    }
    return score;
  }

  /// All sliding windows of exactly [winLength] cells across rows, cols,
  /// and both diagonals. Used by [evaluate].
  List<List<(int, int)>> _allLinesOfWinLength() {
    final lines = <List<(int, int)>>[];
    // Rows
    for (int r = 0; r < size; r++) {
      for (int c = 0; c <= size - winLength; c++) {
        lines.add(List.generate(winLength, (i) => (r, c + i)));
      }
    }
    // Columns
    for (int c = 0; c < size; c++) {
      for (int r = 0; r <= size - winLength; r++) {
        lines.add(List.generate(winLength, (i) => (r + i, c)));
      }
    }
    // Down-right diagonals
    for (int r = 0; r <= size - winLength; r++) {
      for (int c = 0; c <= size - winLength; c++) {
        lines.add(List.generate(winLength, (i) => (r + i, c + i)));
      }
    }
    // Down-left diagonals
    for (int r = 0; r <= size - winLength; r++) {
      for (int c = winLength - 1; c < size; c++) {
        lines.add(List.generate(winLength, (i) => (r + i, c - i)));
      }
    }
    return lines;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'size': size,
        'board': _board
            .map((row) => row.map((c) => c?.index).toList())
            .toList(),
        'current': current.index,
        'state': _stateToJson(state),
        'lastRow': lastRow,
        'lastCol': lastCol,
      };

  static Map<String, dynamic> _stateToJson(TicTacToeState s) {
    if (s is TicTacToeWin) return {'type': 'win', 'winner': s.winner.index};
    if (s is TicTacToeDraw) return {'type': 'draw'};
    return {'type': 'playing'};
  }

  static TicTacToeModel fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int;
    final model = TicTacToeModel(size: size);
    final board = json['board'] as List;
    for (int r = 0; r < size; r++) {
      final row = board[r] as List;
      for (int c = 0; c < size; c++) {
        model._board[r][c] =
            row[c] == null ? null : TicTacToePlayer.values[row[c] as int];
      }
    }
    model.current = TicTacToePlayer.values[json['current'] as int];
    model.state = _stateFromJson(json['state'] as Map<String, dynamic>);
    model.lastRow = json['lastRow'] as int?;
    model.lastCol = json['lastCol'] as int?;
    return model;
  }

  static TicTacToeState _stateFromJson(Map<String, dynamic> s) {
    switch (s['type'] as String) {
      case 'win':
        return TicTacToeWin(TicTacToePlayer.values[s['winner'] as int]);
      case 'draw':
        return const TicTacToeDraw();
      default:
        return const TicTacToePlaying();
    }
  }
}
```

- [ ] **Step 4: Run tests**

```
flutter test test/tictactoe_model_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/games/tictactoe/tictactoe_model.dart test/tictactoe_model_test.dart
git commit -m "feat(tictactoe): add TicTacToeModel with configurable n×n, k-in-a-row, heuristic eval"
```

---

## Task 2 — TicTacToe board widget + AI

**Files:**
- Create: `lib/games/tictactoe/tictactoe_board.dart`

The AI uses three strategies:
- **3×3 / Easy+Medium**: minimax, no depth limit, no alpha-beta (tree is tiny, at most 9 plies)
- **3×3 / Hard**: same minimax (already optimal)
- **4×4**: alpha-beta depth 6 with heuristic leaf evaluation
- **5×5**: alpha-beta depth 4 with heuristic leaf evaluation

All AI functions are top-level (not methods) to allow `compute()` if needed later.

- [ ] **Step 1: Create `lib/games/tictactoe/tictactoe_board.dart`**

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:common_games/games/tictactoe/tictactoe_model.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/services/haptic_service.dart';
import 'package:common_games/services/settings_service.dart';
import 'package:common_games/widgets/game_status_bar.dart';

class TicTacToeBoard extends StatefulWidget {
  const TicTacToeBoard({
    super.key,
    required this.mode,
    required this.boardSize,
    this.difficulty = AiDifficulty.medium,
    this.onGameOver,
    this.undoNotifier,
    this.stateNotifier,
    this.initialState,
  });

  final GameMode mode;
  final int boardSize;
  final AiDifficulty difficulty;
  final void Function(String result)? onGameOver;
  final ValueNotifier<VoidCallback?>? undoNotifier;
  final ValueNotifier<Map<String, dynamic>?>? stateNotifier;
  final Map<String, dynamic>? initialState;

  @override
  State<TicTacToeBoard> createState() => _TicTacToeBoardState();
}

class _TicTacToeBoardState extends State<TicTacToeBoard> {
  late TicTacToeModel _game;
  bool _aiThinking = false;
  final List<Map<String, dynamic>> _history = [];
  final Random _rng = Random();

  // O is always the AI in single-player
  bool get _isAiTurn =>
      widget.mode == GameMode.singlePlayer &&
      _game.current == TicTacToePlayer.o &&
      _game.state is TicTacToePlaying;

  String? get _overrideMessage {
    if (_aiThinking) return 'Computer thinking…';
    return switch (_game.state) {
      TicTacToePlaying() => null,
      TicTacToeWin(:final winner) =>
        '${winner == TicTacToePlayer.x ? "X" : "O"} wins!',
      TicTacToeDraw() => 'Draw!',
    };
  }

  @override
  void initState() {
    super.initState();
    _game = widget.initialState != null
        ? TicTacToeModel.fromJson(widget.initialState!)
        : TicTacToeModel(size: widget.boardSize);
    _updateUndoNotifier();
    _pushStateNotifier();
  }

  void _pushHistory() {
    _history.add(_game.toJson());
  }

  void _performUndo() {
    if (_history.isEmpty) return;
    if (widget.mode == GameMode.singlePlayer && _history.length >= 2) {
      _history.removeLast();
    }
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();
    setState(() {
      _game = TicTacToeModel.fromJson(snapshot);
      _aiThinking = false;
    });
    _updateUndoNotifier();
    _pushStateNotifier();
  }

  void _updateUndoNotifier() {
    widget.undoNotifier?.value =
        _history.isNotEmpty ? _performUndo : null;
  }

  void _pushStateNotifier() {
    widget.stateNotifier?.value = _game.toJson();
  }

  void _onTap(int row, int col) {
    if (_aiThinking || _game.state is! TicTacToePlaying) return;
    _pushHistory();
    final played = _game.play(row, col);
    if (!played) {
      _history.removeLast();
      return;
    }
    HapticService.onMove();
    setState(() {});
    _updateUndoNotifier();
    _pushStateNotifier();
    _checkGameOver();
    _scheduleAiMove();
  }

  void _scheduleAiMove() {
    if (!_isAiTurn) return;
    setState(() => _aiThinking = true);
    final delay = SettingsService.instance.fastAiMoves
        ? 150
        : switch (widget.difficulty) {
            AiDifficulty.easy => 600,
            AiDifficulty.medium => 400,
            AiDifficulty.hard => 200,
          };
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (!mounted || !_isAiTurn) return;
      _playAiMove();
    });
  }

  void _playAiMove() {
    if (!mounted) return;
    final board = _game.board
        .map((row) => List<TicTacToePlayer?>.from(row))
        .toList();
    final empty = _game.emptyCells;
    if (empty.isEmpty) return;

    (int, int) pick;

    switch (widget.difficulty) {
      case AiDifficulty.easy:
        // Random with 30% chance of a smart move
        if (_rng.nextDouble() < 0.3) {
          pick = _smartMove(board, empty);
        } else {
          pick = empty[_rng.nextInt(empty.length)];
        }

      case AiDifficulty.medium:
        // Block immediate wins, else random
        pick = _smartMove(board, empty);

      case AiDifficulty.hard:
        // Full minimax / alpha-beta
        final maxDepth = switch (widget.boardSize) {
          3 => 9,   // full minimax
          4 => 6,   // alpha-beta depth 6
          _ => 4,   // alpha-beta depth 4 (5×5)
        };
        pick = _bestMove(board, widget.boardSize, _game.winLength,
            TicTacToePlayer.o, maxDepth, _rng);
    }

    setState(() {
      _game.play(pick.$1, pick.$2);
      _aiThinking = false;
    });
    HapticService.onMove();
    _updateUndoNotifier();
    _pushStateNotifier();
    _checkGameOver();
  }

  /// Medium AI: wins immediately if possible, else blocks an immediate human win, else random.
  (int, int) _smartMove(
      List<List<TicTacToePlayer?>> board, List<(int, int)> empty) {
    // Try to win
    for (final cell in empty) {
      board[cell.$1][cell.$2] = TicTacToePlayer.o;
      final clone = TicTacToeModel.fromJson(_game.toJson());
      clone.play(cell.$1, cell.$2);
      board[cell.$1][cell.$2] = null;
      if (clone.state is TicTacToeWin) return cell;
    }
    // Try to block
    for (final cell in empty) {
      board[cell.$1][cell.$2] = TicTacToePlayer.x;
      final clone = TicTacToeModel.fromJson(_game.toJson()
        ..['current'] = TicTacToePlayer.x.index);
      // Simple check: would X win here?
      final testModel = TicTacToeModel.fromJson(_game.toJson());
      // Temporarily check if placing X here would win
      final tempBoard =
          _game.board.map((r) => List<TicTacToePlayer?>.from(r)).toList();
      tempBoard[cell.$1][cell.$2] = TicTacToePlayer.x;
      board[cell.$1][cell.$2] = null;
      if (_wouldWin(tempBoard, cell.$1, cell.$2, TicTacToePlayer.x,
          widget.boardSize, _game.winLength)) {
        return cell;
      }
    }
    // Random
    return empty[_rng.nextInt(empty.length)];
  }

  void _checkGameOver() {
    final s = _game.state;
    if (s is TicTacToeWin) {
      HapticService.onGameOver();
      final name = s.winner == TicTacToePlayer.x ? 'X' : 'O';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call('$name wins!');
      });
    } else if (s is TicTacToeDraw) {
      HapticService.onGameOver();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameOver?.call("It's a draw!");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isXTurn = _game.current == TicTacToePlayer.x;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        GameStatusBar(
          player1: PlayerInfo(label: 'X', color: colorScheme.primary),
          player2: PlayerInfo(label: 'O', color: colorScheme.tertiary),
          activePlayer: _game.state is TicTacToePlaying
              ? (isXTurn ? 1 : 2)
              : 0,
          message: _overrideMessage,
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.outlineVariant, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.boardSize,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: widget.boardSize * widget.boardSize,
                      itemBuilder: (ctx, index) {
                        final row = index ~/ widget.boardSize;
                        final col = index % widget.boardSize;
                        final piece = _game.board[row][col];
                        final isLastMove = _game.lastRow == row &&
                            _game.lastCol == col;
                        return _TicTacToeCell(
                          piece: piece,
                          isLastMove: isLastMove,
                          onTap: () => _onTap(row, col),
                          row: row,
                          col: col,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Cell widget ───────────────────────────────────────────────────────────────

class _TicTacToeCell extends StatelessWidget {
  const _TicTacToeCell({
    required this.piece,
    required this.isLastMove,
    required this.onTap,
    required this.row,
    required this.col,
  });

  final TicTacToePlayer? piece;
  final bool isLastMove;
  final VoidCallback onTap;
  final int row;
  final int col;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isLastMove && piece != null
        ? colorScheme.primaryContainer.withValues(alpha: 0.4)
        : colorScheme.surface;

    String label;
    if (piece == TicTacToePlayer.x) {
      label = 'X at row ${row + 1} column ${col + 1}';
    } else if (piece == TicTacToePlayer.o) {
      label = 'O at row ${row + 1} column ${col + 1}';
    } else {
      label = 'Empty row ${row + 1} column ${col + 1}';
    }

    return Semantics(
      label: label,
      button: piece == null,
      child: GestureDetector(
        onTap: piece == null ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: piece == null
              ? null
              : CustomPaint(
                  painter: _SymbolPainter(
                    player: piece!,
                    primaryColor: colorScheme.primary,
                    tertiaryColor: colorScheme.tertiary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SymbolPainter extends CustomPainter {
  final TicTacToePlayer player;
  final Color primaryColor;   // X colour
  final Color tertiaryColor;  // O colour

  const _SymbolPainter({
    required this.player,
    required this.primaryColor,
    required this.tertiaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = size.width * 0.2;
    final strokeWidth = size.width * 0.12;

    if (player == TicTacToePlayer.x) {
      final paint = Paint()
        ..color = primaryColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
          Offset(padding, padding),
          Offset(size.width - padding, size.height - padding),
          paint);
      canvas.drawLine(
          Offset(size.width - padding, padding),
          Offset(padding, size.height - padding),
          paint);
    } else {
      final paint = Paint()
        ..color = tertiaryColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      final center = Offset(size.width / 2, size.height / 2);
      final radius = (size.width / 2) - padding;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) =>
      old.player != player;
}

// ── AI functions (top-level for isolate compatibility) ────────────────────────

/// Returns true if placing [player] at (row, col) on [board] wins.
bool _wouldWin(List<List<TicTacToePlayer?>> board, int row, int col,
    TicTacToePlayer player, int size, int winLength) {
  const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
  for (final d in dirs) {
    int count = 1;
    int r = row + d.$1, c = col + d.$2;
    while (r >= 0 && c >= 0 && r < size && c < size &&
        board[r][c] == player) {
      count++;
      r += d.$1;
      c += d.$2;
    }
    r = row - d.$1; c = col - d.$2;
    while (r >= 0 && c >= 0 && r < size && c < size &&
        board[r][c] == player) {
      count++;
      r -= d.$1;
      c -= d.$2;
    }
    if (count >= winLength) return true;
  }
  return false;
}

/// Checks if the board is full (draw condition).
bool _isBoardFull(List<List<TicTacToePlayer?>> board, int size) {
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      if (board[r][c] == null) return false;
    }
  }
  return true;
}

/// Evaluates a board position for [forPlayer] using the line-scan heuristic.
int _evaluateBoard(List<List<TicTacToePlayer?>> board, int size,
    int winLength, TicTacToePlayer forPlayer) {
  final opponent = forPlayer == TicTacToePlayer.x
      ? TicTacToePlayer.o
      : TicTacToePlayer.x;
  int score = 0;

  void scanLine(List<(int, int)> cells) {
    int mine = 0, theirs = 0;
    for (final cell in cells) {
      final v = board[cell.$1][cell.$2];
      if (v == forPlayer) mine++;
      else if (v == opponent) theirs++;
    }
    if (mine > 0 && theirs == 0) {
      score += pow(10, mine).toInt();
    }
    if (theirs > 0 && mine == 0) {
      score -= pow(10, theirs).toInt();
    }
  }

  for (int r = 0; r < size; r++) {
    for (int c = 0; c <= size - winLength; c++) {
      scanLine(List.generate(winLength, (i) => (r, c + i)));
    }
  }
  for (int c = 0; c < size; c++) {
    for (int r = 0; r <= size - winLength; r++) {
      scanLine(List.generate(winLength, (i) => (r + i, c)));
    }
  }
  for (int r = 0; r <= size - winLength; r++) {
    for (int c = 0; c <= size - winLength; c++) {
      scanLine(List.generate(winLength, (i) => (r + i, c + i)));
    }
  }
  for (int r = 0; r <= size - winLength; r++) {
    for (int c = winLength - 1; c < size; c++) {
      scanLine(List.generate(winLength, (i) => (r + i, c - i)));
    }
  }
  return score;
}

/// Alpha-beta minimax. Returns the score for [aiPlayer].
int _alphabeta(
  List<List<TicTacToePlayer?>> board,
  int size,
  int winLength,
  TicTacToePlayer currentPlayer,
  TicTacToePlayer aiPlayer,
  int depth,
  bool isMaximizing,
  int alpha,
  int beta,
) {
  // Check terminal: did the previous move (opposite of current) win?
  final prevPlayer = currentPlayer == TicTacToePlayer.x
      ? TicTacToePlayer.o
      : TicTacToePlayer.x;

  // Quick win check — scan all cells for the previous player
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      if (board[r][c] == prevPlayer) {
        if (_wouldWin(board, r, c, prevPlayer, size, winLength) &&
            board[r][c] == prevPlayer) {
          // Check if this cell actually forms a win
          // We need to verify it's a real win, not just a cell
        }
      }
    }
  }

  // Actually for terminal check after a move we need a different approach:
  // terminal state was already checked before this call at root, and for
  // recursive calls we check after placing.
  if (depth == 0 || _isBoardFull(board, size)) {
    return _evaluateBoard(board, size, winLength, aiPlayer);
  }

  final cells = <(int, int)>[];
  // Move ordering: center first, then near-center
  final mid = size ~/ 2;
  final orderedCells = <(int, int)>[];
  if (board[mid][mid] == null) orderedCells.add((mid, mid));
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      if (board[r][c] == null && !(r == mid && c == mid)) {
        orderedCells.add((r, c));
      }
    }
  }

  if (isMaximizing) {
    int best = -1000000;
    for (final cell in orderedCells) {
      board[cell.$1][cell.$2] = currentPlayer;
      // Check for immediate win
      if (_wouldWin(board, cell.$1, cell.$2, currentPlayer, size, winLength)) {
        board[cell.$1][cell.$2] = null;
        return currentPlayer == aiPlayer ? 100000 + depth : -(100000 + depth);
      }
      final score = _alphabeta(board, size, winLength,
          currentPlayer == TicTacToePlayer.x
              ? TicTacToePlayer.o
              : TicTacToePlayer.x,
          aiPlayer, depth - 1, false, alpha, beta);
      board[cell.$1][cell.$2] = null;
      best = max(best, score);
      alpha = max(alpha, best);
      if (beta <= alpha) break;
    }
    return best;
  } else {
    int best = 1000000;
    for (final cell in orderedCells) {
      board[cell.$1][cell.$2] = currentPlayer;
      if (_wouldWin(board, cell.$1, cell.$2, currentPlayer, size, winLength)) {
        board[cell.$1][cell.$2] = null;
        return currentPlayer == aiPlayer ? 100000 + depth : -(100000 + depth);
      }
      final score = _alphabeta(board, size, winLength,
          currentPlayer == TicTacToePlayer.x
              ? TicTacToePlayer.o
              : TicTacToePlayer.x,
          aiPlayer, depth - 1, true, alpha, beta);
      board[cell.$1][cell.$2] = null;
      best = min(best, score);
      beta = min(beta, best);
      if (beta <= alpha) break;
    }
    return best;
  }
}

/// Finds the best move for [aiPlayer] on [board].
(int, int) _bestMove(
  List<List<TicTacToePlayer?>> board,
  int size,
  int winLength,
  TicTacToePlayer aiPlayer,
  int maxDepth,
  Random rng,
) {
  final mid = size ~/ 2;
  // Move ordering: center first
  final orderedCells = <(int, int)>[];
  if (board[mid][mid] == null) orderedCells.add((mid, mid));
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      if (board[r][c] == null && !(r == mid && c == mid)) {
        orderedCells.add((r, c));
      }
    }
  }

  if (orderedCells.isEmpty) return (0, 0);

  int bestScore = -1000001;
  final bestMoves = <(int, int)>[];

  for (final cell in orderedCells) {
    board[cell.$1][cell.$2] = aiPlayer;
    // Immediate win
    if (_wouldWin(board, cell.$1, cell.$2, aiPlayer, size, winLength)) {
      board[cell.$1][cell.$2] = null;
      return cell;
    }
    final score = _alphabeta(
      board, size, winLength,
      aiPlayer == TicTacToePlayer.x ? TicTacToePlayer.o : TicTacToePlayer.x,
      aiPlayer, maxDepth - 1, false, -1000001, 1000001,
    );
    board[cell.$1][cell.$2] = null;
    if (score > bestScore) {
      bestScore = score;
      bestMoves
        ..clear()
        ..add(cell);
    } else if (score == bestScore) {
      bestMoves.add(cell);
    }
  }

  return bestMoves[rng.nextInt(bestMoves.length)];
}
```

- [ ] **Step 2: Run analyze**

```
flutter analyze lib/games/tictactoe/
```
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
git add lib/games/tictactoe/tictactoe_board.dart
git commit -m "feat(tictactoe): add board widget with CustomPaint X/O, minimax AI, undo/haptics/settings"
```

---

## Task 3 — Register game: GameType, home tile, stats

**Files:**
- Modify: `lib/screens/home_screen.dart:5` — add `tictactoe` to `GameType` enum
- Modify: `lib/screens/home_screen.dart` — add game card entry
- Modify: `lib/screens/game_screen.dart` — add `'x wins'` stat token

- [ ] **Step 1: Add `tictactoe` to GameType enum in home_screen.dart**

Find:
```dart
enum GameType { gomoku, othello, checkers, dotsAndBoxes }
```
Replace with:
```dart
enum GameType { gomoku, othello, checkers, dotsAndBoxes, tictactoe }
```

- [ ] **Step 2: Add TicTacToe card to the `_games` list in home_screen.dart**

Add after the last `_GameInfo(...)`:
```dart
  _GameInfo(
    title: 'Tic Tac Toe',
    subtitle: 'X vs O',
    icon: Icons.grid_3x3_rounded,
    color: Color(0xFF7B61FF),
    gameType: GameType.tictactoe,
    description: 'Get 3 (or 4) in a row on a grid of your choice.',
  ),
```

- [ ] **Step 3: Fix compile errors from the new enum value**

The `_recordStat` switch in `game_screen.dart` is exhaustive — add the tictactoe case. Find:
```dart
    final humanWinToken = switch (widget.gameType) {
      GameType.gomoku => 'black wins',
      GameType.othello => 'black wins',
      GameType.checkers => 'red wins',
      GameType.dotsAndBoxes => 'player 1 wins',
    };
```
Replace with:
```dart
    final humanWinToken = switch (widget.gameType) {
      GameType.gomoku => 'black wins',
      GameType.othello => 'black wins',
      GameType.checkers => 'red wins',
      GameType.dotsAndBoxes => 'player 1 wins',
      GameType.tictactoe => 'x wins',
    };
```

- [ ] **Step 4: Run analyze**

```
flutter analyze
```
Expected: `No issues found`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart lib/screens/game_screen.dart
git commit -m "feat(tictactoe): register game in GameType enum and home screen"
```

---

## Task 4 — ModeSelectScreen: size selector + GameScreen: boardSize routing

**Files:**
- Modify: `lib/screens/mode_select_screen.dart` — convert to StatefulWidget, add board-size chip row, pass boardSize to GameScreen
- Modify: `lib/screens/game_screen.dart` — add `boardSize` param, route to TicTacToeBoard

- [ ] **Step 1: Add TicTacToe rules to mode_select_screen.dart**

In the `_rules` map, add (the switch will now need a case for tictactoe):
```dart
  GameType.tictactoe: _RulesData(
    objective: 'Get your symbols in a row before your opponent.',
    board: 'Choose 3×3, 4×4, or 5×5 — win length is 3 for 3×3, 4 for larger grids.',
    turns: 'X always goes first. Players alternate placing one symbol per turn.',
    tips: [
      'Take the centre on 3×3 — it\'s part of the most winning lines.',
      'On 4×4 and 5×5, look for fork setups (two threats at once).',
      'Block your opponent\'s three-in-a-row immediately on larger grids.',
    ],
  ),
```

- [ ] **Step 2: Convert ModeSelectScreen to StatefulWidget and add size state**

Replace the class definition with a StatefulWidget. Add `_boardSize` state (default 3, only shown for TicTacToe).

The full new ModeSelectScreen class:
```dart
class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({
    super.key,
    required this.gameType,
    required this.title,
  });

  final GameType gameType;
  final String title;

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  int _boardSize = 3;

  void _startGame(BuildContext context, GameMode mode,
      [AiDifficulty difficulty = AiDifficulty.medium]) {
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          gameType: widget.gameType,
          title: widget.title,
          mode: mode,
          difficulty: difficulty,
          boardSize: widget.gameType == GameType.tictactoe ? _boardSize : 3,
        ),
      ),
    );
  }

  void _showDifficultyPicker(BuildContext context) {
    showModalBottomSheet<AiDifficulty>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Difficulty',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ...AiDifficulty.values.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        d == AiDifficulty.easy
                            ? Icons.sentiment_satisfied_alt
                            : d == AiDifficulty.medium
                                ? Icons.psychology_outlined
                                : Icons.local_fire_department,
                        color: d == AiDifficulty.easy
                            ? Colors.green
                            : d == AiDifficulty.medium
                                ? colorScheme.primary
                                : Colors.redAccent,
                      ),
                      title: Text(d.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(d.description),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: colorScheme.surfaceContainerLow,
                      onTap: () => Navigator.pop(ctx, d),
                    ),
                  )),
            ],
          ),
        );
      },
    ).then((difficulty) {
      if (difficulty != null && context.mounted) {
        _startGame(context, GameMode.singlePlayer, difficulty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rules = _rules[widget.gameType]!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Board size selector (TicTacToe only) ──────────────────
              if (widget.gameType == GameType.tictactoe) ...[
                Text(
                  'Board Size',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 3, label: Text('3 × 3')),
                    ButtonSegment(value: 4, label: Text('4 × 4')),
                    ButtonSegment(value: 5, label: Text('5 × 5')),
                  ],
                  selected: {_boardSize},
                  onSelectionChanged: (s) =>
                      setState(() => _boardSize = s.first),
                ),
                const SizedBox(height: 24),
              ],

              // ── Mode buttons ──────────────────────────────────────────
              Text(
                'Choose Mode',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      icon: Icons.smart_toy_outlined,
                      label: '1 Player',
                      subtitle: 'vs Computer',
                      color: colorScheme.primary,
                      onTap: () => _showDifficultyPicker(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeButton(
                      icon: Icons.people_outline,
                      label: '2 Players',
                      subtitle: 'Local',
                      color: colorScheme.tertiary,
                      onTap: () => _startGame(context, GameMode.twoPlayer),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── How to play ───────────────────────────────────────────
              Text(
                'How to Play',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                  icon: Icons.flag_outlined,
                  title: 'Objective',
                  body: rules.objective),
              const SizedBox(height: 8),
              _InfoCard(
                  icon: Icons.grid_4x4,
                  title: 'Board',
                  body: rules.board),
              const SizedBox(height: 8),
              _InfoCard(
                  icon: Icons.swap_horiz,
                  title: 'Turns',
                  body: rules.turns),
              const SizedBox(height: 20),
              Text(
                'Tips',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...rules.tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(tip,
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Note: The `_ModeButton` and `_InfoCard` private widgets remain identical to the existing file — do not delete or change them.

- [ ] **Step 3: Add `boardSize` to GameScreen**

In `lib/screens/game_screen.dart`, update the `GameScreen` widget to add `boardSize`:

```dart
class GameScreen extends StatefulWidget {
  final GameType gameType;
  final String title;
  final GameMode mode;
  final AiDifficulty difficulty;
  final int boardSize;

  const GameScreen({
    super.key,
    required this.gameType,
    required this.title,
    required this.mode,
    this.difficulty = AiDifficulty.medium,
    this.boardSize = 3,
  });
  // ... rest unchanged
}
```

- [ ] **Step 4: Add TicTacToe case to `_buildBoard()` in game_screen.dart**

Add import at the top:
```dart
import 'package:common_games/games/tictactoe/tictactoe_board.dart';
```

In `_buildBoard()`, add the case:
```dart
      case GameType.tictactoe:
        return TicTacToeBoard(
            key: ValueKey(_boardKey),
            mode: widget.mode,
            boardSize: widget.boardSize,
            difficulty: widget.difficulty,
            onGameOver: _onGameOver,
            undoNotifier: _undoNotifier,
            stateNotifier: _stateNotifier,
            initialState: _savedState);
```

Also update `_saveKey` to incorporate board size for TicTacToe so 3×3 and 5×5 saves don't collide:
```dart
  static String _saveKey(GameType type, [int boardSize = 3]) =>
      type == GameType.tictactoe
          ? 'game_save_${type.name}_$boardSize'
          : 'game_save_${type.name}';
```
Update all three call sites (`_tryRestoreGame`, `_saveGame`, `_clearSave`) to pass `widget.boardSize`.

- [ ] **Step 5: Run analyze**

```
flutter analyze
```
Expected: `No issues found`

- [ ] **Step 6: Run all tests**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/mode_select_screen.dart lib/screens/game_screen.dart
git commit -m "feat(tictactoe): board size selector in ModeSelect, route TicTacToeBoard in GameScreen"
```

---

## Task 5 — Final build and device verification

- [ ] **Step 1: Build release APK**

```bash
flutter build apk --release
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 2: Install on device**

```bash
/home/shyam/Android/Sdk/platform-tools/adb uninstall com.boardbox.app
/home/shyam/Android/Sdk/platform-tools/adb install build/app/outputs/flutter-apk/app-release.apk
```
Expected: `Success`

- [ ] **Step 3: Smoke test on device**
  - Home screen shows 5 game cards including Tic Tac Toe
  - Tap Tic Tac Toe → ModeSelectScreen shows size chips (3×3 / 4×4 / 5×5)
  - Select 3×3, 2 Players → game starts, X goes first
  - Place moves, verify alternation, win detection, undo button works
  - Select 4×4, 1 Player Hard → AI moves within ~1s
  - Select 5×5, 1 Player Hard → AI moves within ~1s
  - Verify haptics fire on moves (if device supports it)
  - Verify "Show move hints" toggle has no effect on TicTacToe (correct — no hints feature)

- [ ] **Step 4: Build AAB for Play Store**

```bash
flutter build appbundle --release
```

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat(tictactoe): complete Tic Tac Toe implementation — 3×3/4×4/5×5, minimax AI, undo, haptics"
```
