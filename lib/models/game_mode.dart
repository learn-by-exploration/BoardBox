/// Shared game mode used by all board games.
enum GameMode {
  /// Two players take turns on the same device.
  twoPlayer,

  /// One player vs the computer.
  singlePlayer,
}

/// AI difficulty levels for single-player mode.
enum AiDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
    AiDifficulty.easy => 'Easy',
    AiDifficulty.medium => 'Medium',
    AiDifficulty.hard => 'Hard',
  };

  String get description => switch (this) {
    AiDifficulty.easy => 'Random moves — great for learning',
    AiDifficulty.medium => 'Basic strategy — a fair challenge',
    AiDifficulty.hard => 'Advanced tactics — very tough',
  };
}

/// The 5 single-player / two-player board games that share a win/loss
/// record. Single-player games without an AI opponent (Karuro,
/// Klondike, Minesweeper) live outside this enum and have their own
/// per-key counters on [GameStats].
enum GameType { gomoku, othello, checkers, dotsAndBoxes, tictactoe }
