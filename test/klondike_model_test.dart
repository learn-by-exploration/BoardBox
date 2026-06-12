import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/klondike/klondike_model.dart';

void main() {
  group('KlondikeModel — initial deal', () {
    test('column 1 has one card, columns 2-7 grow by one', () {
      final model = KlondikeModel.deal(seed: 1);
      expect(model.tableau.length, 7);
      expect(model.tableau[0].cards.length, 1);
      expect(model.tableau[1].cards.length, 2);
      expect(model.tableau[2].cards.length, 3);
      expect(model.tableau[3].cards.length, 4);
      expect(model.tableau[4].cards.length, 5);
      expect(model.tableau[5].cards.length, 6);
      expect(model.tableau[6].cards.length, 7);
    });

    test(
      'after deal, every column has exactly one face-up card at the top',
      () {
        final model = KlondikeModel.deal(seed: 1);
        for (var i = 0; i < 7; i++) {
          final col = model.tableau[i];
          // Count face-up entries in the column.
          final faceUp = col.cards.where((c) => c.faceUp).length;
          expect(
            faceUp,
            1,
            reason: 'column $i has $faceUp face-up cards, expected 1',
          );
          // The last entry (top) is face-up.
          expect(
            col.cards.last.faceUp,
            isTrue,
            reason: 'column $i top card is face-down',
          );
        }
      },
    );

    test(
      'after deal, stock has 24 cards, waste is empty, foundations empty',
      () {
        final model = KlondikeModel.deal(seed: 1);
        expect(model.stock.length, 24);
        expect(model.waste, isEmpty);
        for (final f in model.foundations) {
          expect(f, isEmpty);
        }
      },
    );

    test('initial state is KlondikePlaying', () {
      final model = KlondikeModel.deal(seed: 1);
      expect(model.state, isA<KlondikePlaying>());
    });
  });

  group('KlondikeModel — tableau moves', () {
    test('tap then tap moves a single card from tableau to tableau', () {
      // Build a deterministic small model: column 0 has a face-up King of
      // hearts on top of a face-down card, column 1 has a face-up 5 of
      // clubs (black), and columns 2-6 are empty. We tap the King and
      // then tap the empty column 2.
      final model = _smallModel();
      // Column 0 has [5c face-down, Kh face-up]. Select the King at idx 1.
      model.tapTableau(0, 1);
      expect(model.selectedPile, isNotNull);
      // Column 2 is empty.
      final ok = model.tapTableau(2, 0);
      expect(ok, isTrue);
      expect(model.tableau[0], hasLength(1));
      // The face-down 5 of clubs is now revealed (flipped face-up) because
      // the King that was covering it moved away.
      expect(model.tableau[0].cards.first.faceUp, isTrue);
      expect(model.tableau[2], hasLength(1));
      expect(
        model.tableau[2].cards.first.card,
        const PlayingCard(suit: Suit.hearts, rank: Rank.king),
      );
    });

    test('illegal tableau move is rejected', () {
      // Use a model where both columns have a single face-up card so the
      // index math is obvious: column 0 = King of hearts (red), column 1
      // = 5 of clubs (black). A black 5 cannot sit on a red King.
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.hearts, rank: Rank.king),
                faceUp: true,
              ),
            ],
          ),
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.clubs, rank: Rank.five),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
        stock: <PileCard>[],
        waste: <PileCard>[],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      model.tapTableau(0, 0);
      final ok = model.tapTableau(1, 0);
      expect(ok, isFalse);
      // Selection persists; the move did not happen.
      expect(model.selectedPile, isNotNull);
    });

    test('moving the top of a column reveals the next face-down card', () {
      // Column 0 has a face-down 5 of clubs with a face-up King on top.
      // Column 2 is empty. Move the King away → the 5 of clubs flips up.
      final model = _smallModel();
      model.tapTableau(0, 1);
      model.tapTableau(2, 0);
      // The face-down card in column 0 should now be face-up after
      // the move revealed it.
      expect(model.tableau[0].cards.first.faceUp, isTrue);
    });

    test('group move: a contiguous face-up descending-alternating sequence '
        'moves as a unit', () {
      // Build: column 0 has 4 of hearts (face-down) then [black 9, red 8,
      // black 7] (all face-up). Column 1 has a red 10 on top. The black 9
      // through black 7 group can move onto the red 10.
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.hearts, rank: Rank.four),
                faceUp: false,
              ),
              const PileCard(
                card: PlayingCard(suit: Suit.spades, rank: Rank.nine),
                faceUp: true,
              ),
              const PileCard(
                card: PlayingCard(suit: Suit.diamonds, rank: Rank.eight),
                faceUp: true,
              ),
              const PileCard(
                card: PlayingCard(suit: Suit.clubs, rank: Rank.seven),
                faceUp: true,
              ),
            ],
          ),
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.diamonds, rank: Rank.king),
                faceUp: false,
              ),
              const PileCard(
                card: PlayingCard(suit: Suit.hearts, rank: Rank.ten),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
        stock: const [],
        waste: const [],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      // Select the 9 (index 1 in column 0).
      model.tapTableau(0, 1);
      // Move to column 1.
      final ok = model.tapTableau(1, 1);
      expect(ok, isTrue);
      // Column 0 is down to the face-down 4; column 1 has King (face-down)
      // + ten + 9 (red diamonds? no — black spades 9) ...
      expect(model.tableau[0], hasLength(1));
      expect(
        model.tableau[0].cards.first.faceUp,
        isTrue,
        reason: 'revealed card should be face-up',
      );
      expect(
        model.tableau[1],
        hasLength(5),
        reason: 'group of 3 cards moved onto the existing 2',
      );
    });
  });

  group('KlondikeModel — foundations', () {
    test('an Ace moves to an empty foundation', () {
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.clubs, rank: Rank.ace),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
        stock: const [],
        waste: const [],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      model.tapTableau(0, 0);
      final ok = model.tapTableauToFoundation(0, 0, /*foundationIndex*/ 0);
      expect(ok, isTrue);
      expect(model.foundations[0], hasLength(1));
      expect(model.foundations[0].cards.first.card.rank, Rank.ace);
    });

    test('a 2 of the same suit moves onto an Ace foundation', () {
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.clubs, rank: Rank.two),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
        stock: const [],
        waste: const [],
        foundations: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.clubs, rank: Rank.ace),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
      );
      model.tapTableau(0, 0);
      final ok = model.tapTableauToFoundation(0, 0, /*foundationIndex*/ 0);
      expect(ok, isTrue);
      expect(model.foundations[0], hasLength(2));
    });

    test('a non-Ace cannot move to an empty foundation', () {
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.clubs, rank: Rank.three),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
        stock: const [],
        waste: const [],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      model.tapTableau(0, 0);
      final ok = model.tapTableauToFoundation(0, 0, 0);
      expect(ok, isFalse);
      expect(model.foundations[0], isEmpty);
    });

    test('a card of the wrong suit cannot move onto a foundation', () {
      // Foundation has a Queen of clubs. A King of hearts is the right
      // rank (next-up from Queen) but the wrong suit, so the move is
      // illegal.
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.hearts, rank: Rank.king),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
        stock: const [],
        waste: const [],
        foundations: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.clubs, rank: Rank.queen),
                faceUp: true,
              ),
            ],
          ),
          Pile.empty(),
          Pile.empty(),
          Pile.empty(),
        ],
      );
      model.tapTableau(0, 0);
      final ok = model.tapTableauToFoundation(0, 0, 0);
      expect(ok, isFalse);
      expect(model.foundations[0], hasLength(1));
    });
  });

  group('KlondikeModel — stock and waste', () {
    test('flipStock moves the top stock card to the waste', () {
      final model = KlondikeModel(
        tableau: List.generate(7, (_) => Pile.empty()),
        stock: [
          const PileCard(
            card: PlayingCard(suit: Suit.spades, rank: Rank.ace),
            faceUp: true,
          ),
          const PileCard(
            card: PlayingCard(suit: Suit.hearts, rank: Rank.king),
            faceUp: true,
          ),
        ],
        waste: const [],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      model.flipStock();
      expect(model.stock, hasLength(1));
      expect(model.waste, hasLength(1));
      expect(
        model.waste.first.card,
        const PlayingCard(suit: Suit.hearts, rank: Rank.king),
      );
    });

    test('flipStock when stock is empty recycles the waste into the stock', () {
      final model = KlondikeModel(
        tableau: List.generate(7, (_) => Pile.empty()),
        stock: const [],
        waste: [
          const PileCard(
            card: PlayingCard(suit: Suit.spades, rank: Rank.ace),
            faceUp: true,
          ),
          const PileCard(
            card: PlayingCard(suit: Suit.hearts, rank: Rank.king),
            faceUp: true,
          ),
        ],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      model.flipStock();
      expect(model.stock, hasLength(2));
      expect(model.waste, isEmpty);
    });
  });

  group('KlondikeModel — undo', () {
    test('undo restores the previous tableau state', () {
      final model = _smallModel();
      // Move the King of hearts from col 0 (idx 1, the face-up card)
      // to the empty column 2.
      model.tapTableau(0, 1);
      model.tapTableau(2, 0);
      expect(model.tableau[2], hasLength(1));
      // Undo.
      expect(model.undo(), isTrue);
      expect(model.tableau[2], isEmpty);
      expect(model.tableau[0], hasLength(2));
    });

    test('undo with empty history returns false and is a no-op', () {
      final model = _smallModel();
      expect(model.undo(), isFalse);
    });
  });

  group('KlondikeModel — win', () {
    test('state flips to KlondikeWon when all four foundations are full', () {
      // Build a near-won state: each foundation has 12 cards (ace through
      // queen in suit order). The 13th card (the King of the matching suit)
      // is on the tableau; moving it to its foundation should trigger
      // KlondikeWon.
      final model = KlondikeModel(
        tableau: List.generate(7, (_) => Pile.empty()),
        stock: const [],
        waste: const [],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      // Push 12 cards onto each foundation (ace through queen, by suit).
      for (int f = 0; f < 4; f++) {
        for (int r = 0; r < 12; r++) {
          model.debugPushForTest(
            f,
            PlayingCard(suit: Suit.values[f], rank: Rank.values[r]),
          );
        }
      }
      // Place a King on each of the first 4 columns — one per suit. Move
      // the King of clubs first; the test asserts win only after the final
      // King (spades) lands.
      for (int f = 0; f < 4; f++) {
        model.debugSetTableauForTest(f, [
          PileCard(
            card: PlayingCard(suit: Suit.values[f], rank: Rank.king),
            faceUp: true,
          ),
        ]);
      }
      for (int f = 0; f < 4; f++) {
        model.tapTableau(f, 0);
        model.tapTableauToFoundation(f, 0, f);
      }
      expect(model.state, isA<KlondikeWon>());
    });
  });

  group('KlondikeModel — save/restore round-trip', () {
    test('toJson and fromJson preserve the state', () {
      final original = KlondikeModel.deal(seed: 7);
      // Make a move so the history stack is non-empty.
      original.flipStock();
      final json = original.toJson();
      final restored = KlondikeModel.fromJson(json);
      // Compare every pile's cards and face-up mask.
      for (var i = 0; i < 7; i++) {
        expect(restored.tableau[i].length, original.tableau[i].length);
        for (var j = 0; j < original.tableau[i].length; j++) {
          expect(
            restored.tableau[i].cards[j].card,
            original.tableau[i].cards[j].card,
          );
          expect(
            restored.tableau[i].cards[j].faceUp,
            original.tableau[i].cards[j].faceUp,
          );
        }
      }
      expect(restored.stock.length, original.stock.length);
      expect(restored.waste.length, original.waste.length);
      for (var f = 0; f < 4; f++) {
        expect(restored.foundations[f].length, original.foundations[f].length);
      }
    });

    test('a corrupt save throws FormatException', () {
      expect(
        () => KlondikeModel.fromJson({'version': 99}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

/// Build a small two-column model: column 0 has a face-down 5 of clubs
/// with a face-up King of hearts on top; column 1 has a face-down 3 of
/// diamonds with a face-up 5 of clubs on top; rest empty.
KlondikeModel _smallModel() {
  return KlondikeModel(
    tableau: [
      Pile(
        cards: [
          const PileCard(
            card: PlayingCard(suit: Suit.clubs, rank: Rank.five),
            faceUp: false,
          ),
          const PileCard(
            card: PlayingCard(suit: Suit.hearts, rank: Rank.king),
            faceUp: true,
          ),
        ],
      ),
      Pile(
        cards: [
          const PileCard(
            card: PlayingCard(suit: Suit.diamonds, rank: Rank.three),
            faceUp: false,
          ),
          const PileCard(
            card: PlayingCard(suit: Suit.clubs, rank: Rank.five),
            faceUp: true,
          ),
        ],
      ),
      Pile.empty(),
      Pile.empty(),
      Pile.empty(),
      Pile.empty(),
      Pile.empty(),
    ],
    stock: const [],
    waste: const [],
    foundations: List.generate(4, (_) => Pile.empty()),
  );
}
