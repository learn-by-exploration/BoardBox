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
