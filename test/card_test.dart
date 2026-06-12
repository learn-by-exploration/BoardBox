import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/cards/card_widget.dart';
import 'package:common_games/games/cards/deck.dart';

void main() {
  group('PlayingCard', () {
    test('equality and hashCode make a Set work', () {
      const a = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const b = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const c = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      // Two distinct values (spades vs hearts), three inserts. A Set must
      // collapse `a` and `b` to one entry. Use a list literal that we then
      // convert to a Set, since a set literal would trigger the
      // "equal_elements_in_set" lint on the intentionally-duplicate `a, b`.
      final list = [a, b, c];
      expect(list.toSet(), hasLength(2));
    });

    test('isRed is true for hearts and diamonds, false otherwise', () {
      const hearts = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      const diamonds = PlayingCard(suit: Suit.diamonds, rank: Rank.king);
      const spades = PlayingCard(suit: Suit.spades, rank: Rank.king);
      const clubs = PlayingCard(suit: Suit.clubs, rank: Rank.king);
      expect(hearts.isRed, isTrue);
      expect(diamonds.isRed, isTrue);
      expect(spades.isRed, isFalse);
      expect(clubs.isRed, isFalse);
    });

    test('toString includes rank and suit', () {
      const c = PlayingCard(suit: Suit.hearts, rank: Rank.queen);
      expect(c.toString(), contains('Queen'));
      expect(c.toString(), contains('hearts'));
    });
  });

  group('Deck', () {
    test('newDeck returns 52 unique cards in a fixed order', () {
      final deck = Deck.newDeck();
      expect(deck.cards, hasLength(52));
      expect(
        deck.cards.toSet(),
        hasLength(52),
        reason: 'all 52 must be unique',
      );
      // First card is conventionally Ace of clubs (the lowest suit+rank).
      expect(deck.cards.first.suit, Suit.clubs);
      expect(deck.cards.first.rank, Rank.ace);
    });

    test('shuffled(seed: ...) is deterministic', () {
      final a = Deck.shuffled(seed: 1);
      final b = Deck.shuffled(seed: 1);
      final c = Deck.shuffled(seed: 2);
      expect(
        a.cards,
        equals(b.cards),
        reason: 'same seed must yield same order',
      );
      expect(a.cards, isNot(equals(c.cards)), reason: 'different seeds differ');
      // Still 52 unique cards.
      expect(a.cards.toSet(), hasLength(52));
    });
  });

  group('CardView', () {
    testWidgets('renders face-up card with rank and suit text', (tester) async {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.queen);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60,
                height: 90,
                child: CardView(card: card),
              ),
            ),
          ),
        ),
      );
      // 2 rank corners (top-left, rotated bottom-right) + 3 suit glyphs
      // (top-left, center, rotated bottom-right) = the standard playing-card layout.
      expect(find.text('Q'), findsNWidgets(2));
      expect(find.text('♥'), findsNWidgets(3));
    });

    testWidgets('face-down renders the back pattern, not rank', (tester) async {
      const card = PlayingCard(suit: Suit.spades, rank: Rank.king);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60,
                height: 90,
                child: CardView(card: card, faceDown: true),
              ),
            ),
          ),
        ),
      );
      // The corner rank/suit are not rendered when face down.
      expect(find.text('K'), findsNothing);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);
    });
  });
}
