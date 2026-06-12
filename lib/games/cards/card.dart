/// Pure-Dart value types for playing cards. No Flutter imports — the
/// card *visuals* live in `card_widget.dart`.
library;

enum Suit { clubs, diamonds, hearts, spades }

enum Rank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}

/// A single playing card. Immutable; value-equality is by (suit, rank) so
/// that `Set<PlayingCard>` works for "cards remaining in the deck" checks
/// and for testing.
class PlayingCard {
  const PlayingCard({required this.suit, required this.rank});

  final Suit suit;
  final Rank rank;

  /// True for hearts and diamonds, false for clubs and spades.
  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayingCard && other.suit == suit && other.rank == rank);

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => '${_rankName(rank)} of ${_suitName(suit)}';

  static String _rankName(Rank r) {
    return switch (r) {
      Rank.ace => 'Ace',
      Rank.two => '2',
      Rank.three => '3',
      Rank.four => '4',
      Rank.five => '5',
      Rank.six => '6',
      Rank.seven => '7',
      Rank.eight => '8',
      Rank.nine => '9',
      Rank.ten => '10',
      Rank.jack => 'Jack',
      Rank.queen => 'Queen',
      Rank.king => 'King',
    };
  }

  static String _suitName(Suit s) {
    return switch (s) {
      Suit.clubs => 'clubs',
      Suit.diamonds => 'diamonds',
      Suit.hearts => 'hearts',
      Suit.spades => 'spades',
    };
  }
}
