import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/klondike/klondike_model.dart';

/// What kind of move to apply. The [KlondikeMove] data class carries the
/// parameters for whichever kind is in play.
enum KlondikeMoveKind {
  /// Move a single card from the top of a tableau column to a foundation.
  tableauToFoundation,

  /// Move the top card of the waste to a foundation.
  wasteToFoundation,

  /// Move the top card of the waste onto a tableau column.
  wasteToTableau,

  /// Move a (possibly multi-card) group from one tableau column to another.
  tableauToTableau,

  /// Flip the top of the stock to the waste.
  flipStock,
}

/// A single legal move the hint engine has decided to recommend, or that
/// the auto-complete driver wants to apply next. Field meanings depend on
/// [kind] — see the comments on each constructor.
class KlondikeMove {
  const KlondikeMove._({
    required this.kind,
    this.fromCol = 0,
    this.fromIdx = 0,
    this.toCol = 0,
    this.foundationIndex = 0,
  });

  /// Tableau -> Foundation. `fromCol` / `fromIdx` identify the top of the
  /// group in the source column (only ever the top in this case);
  /// `foundationIndex` is the destination foundation (0=clubs, 1=diamonds,
  /// 2=hearts, 3=spades).
  const KlondikeMove.tableauToFoundation({
    required int fromCol,
    required int fromIdx,
    required int foundationIndex,
  }) : this._(
         kind: KlondikeMoveKind.tableauToFoundation,
         fromCol: fromCol,
         fromIdx: fromIdx,
         foundationIndex: foundationIndex,
       );

  /// Waste -> Foundation. `foundationIndex` is the destination.
  const KlondikeMove.wasteToFoundation({required int foundationIndex})
    : this._(
        kind: KlondikeMoveKind.wasteToFoundation,
        foundationIndex: foundationIndex,
      );

  /// Waste -> Tableau. `toCol` is the destination column.
  const KlondikeMove.wasteToTableau({required int toCol})
    : this._(kind: KlondikeMoveKind.wasteToTableau, toCol: toCol);

  /// Tableau -> Tableau. `fromCol` / `fromIdx` identify the start of the
  /// group in the source column; `toCol` is the destination column.
  const KlondikeMove.tableauToTableau({
    required int fromCol,
    required int fromIdx,
    required int toCol,
  }) : this._(
         kind: KlondikeMoveKind.tableauToTableau,
         fromCol: fromCol,
         fromIdx: fromIdx,
         toCol: toCol,
       );

  /// Flip the stock.
  const KlondikeMove.flipStock() : this._(kind: KlondikeMoveKind.flipStock);

  final KlondikeMoveKind kind;
  final int fromCol;
  final int fromIdx;
  final int toCol;
  final int foundationIndex;

  @override
  String toString() => switch (kind) {
    KlondikeMoveKind.tableauToFoundation =>
      'tableau($fromCol,$fromIdx) -> foundation $foundationIndex',
    KlondikeMoveKind.wasteToFoundation =>
      'waste -> foundation $foundationIndex',
    KlondikeMoveKind.wasteToTableau => 'waste -> tableau $toCol',
    KlondikeMoveKind.tableauToTableau =>
      'tableau($fromCol,$fromIdx) -> tableau $toCol',
    KlondikeMoveKind.flipStock => 'flipStock',
  };
}

/// Apply [move] to [model]. Returns true if the model mutated (i.e. the
/// move was legal). Used by the auto-complete driver and by tests; the
/// hint engine itself only *finds* moves, it never applies them.
bool applyKlondikeMove(KlondikeModel model, KlondikeMove move) {
  switch (move.kind) {
    case KlondikeMoveKind.tableauToFoundation:
      return model.tapTableauToFoundation(
        move.fromCol,
        move.fromIdx,
        move.foundationIndex,
      );
    case KlondikeMoveKind.wasteToFoundation:
      return model.tapWasteToFoundation(move.foundationIndex);
    case KlondikeMoveKind.wasteToTableau:
      return model.tapWasteToTableau(move.toCol);
    case KlondikeMoveKind.tableauToTableau:
      // The model's `tapTableau(toCol, 0)` only completes the move if
      // the source group is already selected. So we need to call
      // `tapTableau(fromCol, fromIdx)` first to establish the
      // selection, then `tapTableau(toCol, 0)` to drop it.
      model.tapTableau(move.fromCol, move.fromIdx);
      return model.tapTableau(move.toCol, 0);
    case KlondikeMoveKind.flipStock:
      model.flipStock();
      return true;
  }
}

/// Hint solver. Scans the current [KlondikeModel] state and returns a
/// single legal move it would recommend, or `null` when the board is
/// stuck (no legal moves remain).
///
/// Strategy (greedy, by priority):
/// 1. Move the top of the waste to a foundation if it fits.
/// 2. Move any tableau top card to a foundation if it fits.
/// 3. Flip the stock if it's non-empty and no other move applies.
/// 4. Move the top of the waste to a tableau column if it fits.
/// 5. Move a tableau group (any valid descending-alternating face-up
///    sequence starting above the top) onto another tableau column.
class KlondikeHint {
  const KlondikeHint._();

  static KlondikeMove? findValidMove(KlondikeModel model) {
    if (model.state is! KlondikePlaying) return null;

    // 1. Waste -> Foundation.
    if (model.waste.isNotEmpty) {
      final card = model.waste.last.card;
      for (var f = 0; f < 4; f++) {
        if (_canMoveToFoundation(card, model.foundations[f])) {
          return KlondikeMove.wasteToFoundation(foundationIndex: f);
        }
      }
    }

    // 2. Tableau top -> Foundation.
    for (var c = 0; c < 7; c++) {
      final pile = model.tableau[c];
      if (pile.isEmpty) continue;
      final top = pile.top.card;
      for (var f = 0; f < 4; f++) {
        if (_canMoveToFoundation(top, model.foundations[f])) {
          return KlondikeMove.tableauToFoundation(
            fromCol: c,
            fromIdx: pile.length - 1,
            foundationIndex: f,
          );
        }
      }
    }

    // 3. Stock flip — only if no other move applies *and* the stock
    //    has cards (or the waste can be recycled).
    if (model.stock.isNotEmpty) {
      return const KlondikeMove.flipStock();
    }

    // 4. Waste -> Tableau.
    if (model.waste.isNotEmpty) {
      final card = model.waste.last.card;
      for (var c = 0; c < 7; c++) {
        if (_canDropOnTableau(card, model.tableau[c])) {
          return KlondikeMove.wasteToTableau(toCol: c);
        }
      }
    }

    // 5. Tableau group -> Tableau. For each column, find any face-up
    //    valid group whose top is not the column's last card and which
    //    can drop onto another column. This is the most expensive check;
    //    we put it last so common cases (1-3) shortcut.
    for (var c = 0; c < 7; c++) {
      final pile = model.tableau[c];
      if (pile.length < 2) continue;
      for (var i = 0; i < pile.length - 1; i++) {
        if (!_isValidGroupAt(model, c, i)) continue;
        final moving = pile.cards[i].card;
        for (var d = 0; d < 7; d++) {
          if (d == c) continue;
          if (_canDropOnTableau(moving, model.tableau[d])) {
            return KlondikeMove.tableauToTableau(
              fromCol: c,
              fromIdx: i,
              toCol: d,
            );
          }
        }
      }
    }

    // 6. No legal move. If the stock is empty and the waste is
    //    non-empty, recycling is legal but unhelpful — the hint returns
    //    a flipStock-equivalent that will re-deal.
    if (model.stock.isEmpty && model.waste.isNotEmpty) {
      return const KlondikeMove.flipStock();
    }

    return null;
  }
}

/// Auto-complete detector. Returns true when the model is in a state
/// where every remaining move is "obvious" — play the top of a column to
/// its foundation, or play a card from a longer in-suit descending run
/// to its foundation. The screen uses this to drive the auto-play loop.
class KlondikeAutoComplete {
  const KlondikeAutoComplete._();

  /// Two conditions must hold:
  /// 1. Every tableau card is face-up.
  /// 2. In every column, the face-up cards form a single valid
  ///    descending-alternating sequence.
  /// Stock and waste must be empty (we can't auto-play from the waste
  /// without making a choice that isn't obviously correct).
  static bool canAutoComplete(KlondikeModel model) {
    if (model.state is! KlondikePlaying) return false;
    if (model.stock.isNotEmpty) return false;
    if (model.waste.isNotEmpty) return false;
    for (var c = 0; c < 7; c++) {
      final pile = model.tableau[c];
      for (final pc in pile.cards) {
        if (!pc.faceUp) return false;
      }
      for (var i = 0; i < pile.length - 1; i++) {
        final a = pile.cards[i].card;
        final b = pile.cards[i + 1].card;
        if (a.isRed == b.isRed) return false;
        if (a.rank.index != b.rank.index + 1) return false;
      }
    }
    return true;
  }
}

bool _canMoveToFoundation(PlayingCard card, Pile foundation) {
  if (foundation.isEmpty) return card.rank == Rank.ace;
  final top = foundation.top.card;
  return top.suit == card.suit && card.rank.index == top.rank.index + 1;
}

bool _canDropOnTableau(PlayingCard card, Pile dest) {
  if (dest.isEmpty) return true;
  final top = dest.top.card;
  if (top.isRed == card.isRed) return false;
  if (top.rank.index != card.rank.index + 1) return false;
  return true;
}

bool _isValidGroupAt(KlondikeModel model, int col, int idx) {
  final pile = model.tableau[col];
  if (idx < 0 || idx >= pile.length) return false;
  if (!pile.cards[idx].faceUp) return false;
  for (var i = idx; i < pile.length - 1; i++) {
    final a = pile.cards[i].card;
    final b = pile.cards[i + 1].card;
    if (a.isRed == b.isRed) return false;
    if (a.rank.index != b.rank.index + 1) return false;
  }
  return true;
}
