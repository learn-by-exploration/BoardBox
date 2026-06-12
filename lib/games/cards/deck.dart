import 'dart:math';

import 'package:common_games/games/cards/card.dart';

/// A 52-card deck in a fixed or shuffled order. Pure Dart — no Flutter.
class Deck {
  Deck._(this.cards);

  /// All 52 unique cards, ordered by suit then rank. The first card is the
  /// Ace of clubs, the last the King of spades.
  factory Deck.newDeck() {
    return Deck._([
      for (final suit in Suit.values)
        for (final rank in Rank.values) PlayingCard(suit: suit, rank: rank),
    ]);
  }

  /// Returns a freshly shuffled deck. When [seed] is provided the result is
  /// deterministic (used by tests and save/restore to pin a deal).
  factory Deck.shuffled({int? seed, Random? random}) {
    final cards = Deck.newDeck().cards;
    final rng = random ?? Random(seed);
    cards.shuffle(rng);
    return Deck._(cards);
  }

  /// The cards in deal order. Read-only by convention; mutations to this
  /// list would corrupt the deck, so callers should treat it as immutable.
  final List<PlayingCard> cards;

  @override
  String toString() => 'Deck(${cards.length} cards)';
}
