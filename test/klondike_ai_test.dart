import 'package:flutter_test/flutter_test.dart';
import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/klondike/klondike_ai.dart';
import 'package:common_games/games/klondike/klondike_model.dart';

void main() {
  group('KlondikeHint.findValidMove', () {
    test('waste->foundation when the top of the waste is the next Ace', () {
      // Build a model where the waste has the 2 of clubs on top and the
      // clubs foundation has the Ace of clubs. The hint should suggest
      // moving 2c to foundation 0 (clubs).
      final model = KlondikeModel(
        tableau: List.generate(7, (_) => Pile.empty()),
        stock: const [],
        waste: [
          const PileCard(
            card: PlayingCard(suit: Suit.clubs, rank: Rank.two),
            faceUp: true,
          ),
        ],
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
      final move = KlondikeHint.findValidMove(model);
      expect(move, isNotNull);
      expect(move!.kind, KlondikeMoveKind.wasteToFoundation);
      expect(move.foundationIndex, 0);
    });

    test(
      'tableau->foundation when a top card is the next rank of its suit',
      () {
        // Column 0 has the 3 of hearts (face-up). The hearts foundation has
        // 2 of hearts. Hint should suggest moving 3h to foundation 2.
        final model = KlondikeModel(
          tableau: [
            Pile(
              cards: [
                const PileCard(
                  card: PlayingCard(suit: Suit.hearts, rank: Rank.three),
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
            Pile.empty(),
            Pile.empty(),
            Pile(
              cards: [
                const PileCard(
                  card: PlayingCard(suit: Suit.hearts, rank: Rank.two),
                  faceUp: true,
                ),
              ],
            ),
            Pile.empty(),
          ],
        );
        final move = KlondikeHint.findValidMove(model);
        expect(move, isNotNull);
        expect(move!.kind, KlondikeMoveKind.tableauToFoundation);
        expect(move.fromCol, 0);
        expect(move.foundationIndex, 2);
      },
    );

    test('flipStock when no other move applies and the stock is non-empty', () {
      // All tableau columns are empty, stock is non-empty, no foundations
      // are started. The hint should suggest flipping the stock.
      final model = KlondikeModel(
        tableau: List.generate(7, (_) => Pile.empty()),
        stock: [
          const PileCard(
            card: PlayingCard(suit: Suit.spades, rank: Rank.king),
            faceUp: true,
          ),
        ],
        waste: const [],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      final move = KlondikeHint.findValidMove(model);
      expect(move, isNotNull);
      expect(move!.kind, KlondikeMoveKind.flipStock);
    });

    test('returns null when the board is genuinely stuck', () {
      // Build a board with no legal moves:
      //   - Stock and waste are empty.
      //   - All tableau cards are face-down.
      //   - No column is empty.
      // (Even a 1-card face-up column with no move would be enough; this
      // is a cleaner "stuck" state because nothing is selectable.)
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.hearts, rank: Rank.three),
                faceUp: false,
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
      final move = KlondikeHint.findValidMove(model);
      expect(move, isNull);
    });
  });

  group('KlondikeAutoComplete.canAutoComplete', () {
    test('true when all tableau cards are face-up and stock/waste empty', () {
      // All cards face-up, stock empty, waste empty, and the runs in
      // each column are valid descending-alternating sequences.
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.spades, rank: Rank.queen),
                faceUp: true,
              ),
              const PileCard(
                card: PlayingCard(suit: Suit.hearts, rank: Rank.jack),
                faceUp: true,
              ),
            ],
          ),
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.diamonds, rank: Rank.ten),
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
      expect(KlondikeAutoComplete.canAutoComplete(model), isTrue);
    });

    test('false when a tableau card is face-down', () {
      final model = KlondikeModel(
        tableau: [
          Pile(
            cards: [
              const PileCard(
                card: PlayingCard(suit: Suit.spades, rank: Rank.queen),
                faceUp: false,
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
      expect(KlondikeAutoComplete.canAutoComplete(model), isFalse);
    });

    test('false when the stock is non-empty', () {
      final model = KlondikeModel(
        tableau: List.generate(7, (_) => Pile.empty()),
        stock: [
          const PileCard(
            card: PlayingCard(suit: Suit.spades, rank: Rank.king),
            faceUp: true,
          ),
        ],
        waste: const [],
        foundations: List.generate(4, (_) => Pile.empty()),
      );
      expect(KlondikeAutoComplete.canAutoComplete(model), isFalse);
    });
  });
}
