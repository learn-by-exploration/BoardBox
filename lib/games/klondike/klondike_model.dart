/// Pure-Dart Klondike Solitaire model. No Flutter imports — the visuals
/// and gesture layer live in `klondike_board.dart`. Save/restore is
/// versioned (`version: 1`).
library;

import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/cards/deck.dart';

sealed class KlondikeState {
  const KlondikeState();
}

final class KlondikePlaying extends KlondikeState {
  const KlondikePlaying();
}

final class KlondikeWon extends KlondikeState {
  const KlondikeWon();
}

/// A single card on a pile. `faceUp` is meaningful only for tableau cards;
/// stock/waste/ foundation cards are always face-up.
class PileCard {
  const PileCard({required this.card, required this.faceUp});

  final PlayingCard card;
  final bool faceUp;
}

/// A pile of cards. The tableau is 7 of these, the foundations 4, plus
/// stock and waste. We model them with the same type because the
/// operations are uniform (peek, push, pop, take-from-index).
class Pile {
  /// Mutable constructor — the model mutates `cards` in place. Tests that
  /// want a fresh empty pile can use `Pile(cards: <PileCard>[])`.
  Pile({List<PileCard>? cards}) : cards = cards ?? <PileCard>[];

  /// Convenience for tests and call sites that need a fresh empty pile.
  /// Each `empty` has its own backing list, so mutations don't bleed
  /// across piles.
  static Pile empty() => Pile();

  final List<PileCard> cards;

  int get length => cards.length;
  bool get isEmpty => cards.isEmpty;

  PileCard get top => cards.last;
}

/// Describes the currently-selected group. `fromCol` is the column index
/// in the tableau (0-6). `fromIdx` is the index of the *top card* of the
/// selection within the column. The selection extends down to the bottom
/// of the column (only the contiguous face-up descending-alternating tail
/// is selectable).
class KlondikeSelection {
  const KlondikeSelection({required this.fromCol, required this.fromIdx});
  final int fromCol;
  final int fromIdx;
}

class KlondikeModel {
  /// Build a model from an explicit initial layout. Used by tests and by
  /// `fromJson`. Most callers should use [KlondikeModel.deal] instead.
  ///
  /// The constructor takes its own copies of the input lists — the
  /// caller can pass `const` literals and we still hold mutable lists
  /// internally. `Pile` instances are shared with the input by
  /// reference; the model mutates their `cards` list in place.
  KlondikeModel({
    required List<Pile> tableau,
    required List<PileCard> stock,
    required List<PileCard> waste,
    required List<Pile> foundations,
    int? seed,
  }) : tableau = List<Pile>.of(tableau),
       stock = List<PileCard>.of(stock),
       waste = List<PileCard>.of(waste),
       foundations = List<Pile>.of(foundations),
       // ignore: prefer_initializing_formals
       _seed = seed,
       _history = <_Snapshot>[],
       state = const KlondikePlaying();

  /// Shuffle a fresh deck and lay it out the standard Klondike way.
  /// Pinned by [seed] for tests and save/restore.
  factory KlondikeModel.deal({int? seed}) {
    final deck = Deck.shuffled(seed: seed);
    final cards = deck.cards;
    var index = 0;
    final tableau = <Pile>[];
    for (var col = 0; col < 7; col++) {
      final colCards = <PileCard>[];
      for (var row = 0; row <= col; row++) {
        final isTop = row == col;
        colCards.add(PileCard(card: cards[index], faceUp: isTop));
        index++;
      }
      tableau.add(Pile(cards: colCards));
    }
    final stock = <PileCard>[
      for (var i = index; i < cards.length; i++)
        PileCard(card: cards[i], faceUp: true),
    ];
    return KlondikeModel(
      tableau: tableau,
      stock: stock,
      waste: const <PileCard>[],
      foundations: List<Pile>.generate(4, (_) => Pile.empty()),
      seed: seed,
    );
  }

  /// Public, read-only tableau.
  final List<Pile> tableau;

  /// Public, read-only stock pile.
  final List<PileCard> stock;

  /// Public, read-only waste pile. Stored as a list, but only the *last*
  /// element (the top) is ever playable in standard Klondike.
  final List<PileCard> waste;

  /// Four foundation piles, indexed by suit *order* in [Suit.values]:
  /// 0=clubs, 1=diamonds, 2=hearts, 3=spades.
  final List<Pile> foundations;

  /// The currently-selected card group, if any. Null when nothing is
  /// selected. The board widget reads this to drive highlight states.
  KlondikeSelection? _selected;
  KlondikeSelection? get selectedPile => _selected;

  /// Game state. Flips to [KlondikeWon] when all four foundations are full.
  KlondikeState state;

  /// Seed used to build the deck. Saved so a `fromJson(toJson())` round
  /// trip is reproducible.
  int? _seed;
  int? get seed => _seed;

  final List<_Snapshot> _history;

  /// Number of user-driven moves made so far. Each mutation that pushes
  /// onto the history stack increments this; `undo()` decrements it.
  /// Surfaced in the game screen's status bar.
  int get moves => _history.length;

  /// True if at least one history snapshot exists, i.e. `undo()` will
  /// do something. Used by the screen to enable / disable the Undo
  /// button.
  bool get canUndo => _history.isNotEmpty;

  /// Seconds elapsed since the deal. Owned by the screen, not the
  /// model — the screen drives the timer and reads it for the status
  /// bar. Stored on the model only so it can survive save / restore.
  int elapsedSeconds = 0;

  /// Test-only helper: push [card] onto foundation [foundationIndex].
  /// Used by `klondike_model_test.dart` to construct near-won states
  /// without going through dozens of legal moves. Not part of the public
  /// runtime API — do not call from screens or widgets.
  void debugPushForTest(int foundationIndex, PlayingCard card) {
    foundations[foundationIndex].cards.add(PileCard(card: card, faceUp: true));
  }

  /// Test-only helper: replace column [col]'s cards with [cards]. Used
  /// by `klondike_model_test.dart` to set up specific tableaus without
  /// going through the deal. Not part of the public runtime API.
  void debugSetTableauForTest(int col, List<PileCard> cards) {
    tableau[col].cards
      ..clear()
      ..addAll(cards);
  }

  // ─── Stock / waste ──────────────────────────────────────────────────

  /// Flip the top card of the stock to the waste. If the stock is empty,
  /// recycle the waste into the stock (Klondike draw-1 has unlimited
  /// redeals).
  void flipStock() {
    if (state is! KlondikePlaying) return;
    if (stock.isNotEmpty) {
      _pushHistory();
      final card = stock.removeLast();
      waste.add(PileCard(card: card.card, faceUp: true));
    } else if (waste.isNotEmpty) {
      _pushHistory();
      // Recycle: waste becomes stock in reverse order. The card that was
      // on top of the waste is the new top of the stock.
      final reversed = waste.reversed.toList();
      stock
        ..clear()
        ..addAll(reversed);
      waste.clear();
    }
    _checkWin();
  }

  // ─── Tableau moves ─────────────────────────────────────────────────

  /// Tap a card on the tableau. Tapping the currently-selected card
  /// deselects it. Tapping a different card in the same column resizes
  /// the selection (if the new index is the start of a valid group).
  /// Tapping a card in another column attempts a move. Tapping an empty
  /// column is treated as "drop on the empty column" — a valid move
  /// when there is an active selection.
  ///
  /// Returns true if a move was applied. False if the tap was a no-op
  /// (e.g. tapped a face-down card, or attempted an illegal move and
  /// the selection persisted).
  bool tapTableau(int col, int idx) {
    if (state is! KlondikePlaying) return false;
    if (col < 0 || col >= 7) return false;
    final column = tableau[col];

    // Tapping an empty column is "drop here" — only valid if there is
    // an active selection.
    if (column.isEmpty) {
      final current = _selected;
      if (current == null) return false;
      return _moveTableauToTableau(current.fromCol, current.fromIdx, col);
    }

    if (idx < 0 || idx >= column.length) return false;

    final card = column.cards[idx];
    if (!card.faceUp) {
      // Tapping a face-down card: if it's the top of an empty selection
      // chain, we don't do anything (player must move the top card first).
      return false;
    }

    final current = _selected;
    if (current != null) {
      if (current.fromCol == col) {
        // Re-select within the same column. Pick the new starting index
        // for the group, but only if the new group is still a valid
        // descending-alternating sequence of face-up cards ending at
        // the bottom of the column.
        if (_isValidGroup(col, idx)) {
          _selected = KlondikeSelection(fromCol: col, fromIdx: idx);
          return false; // selection change is not a "move" but it's a state change
        }
        return false;
      }
      // Different column: try to move the selected group here.
      return _moveTableauToTableau(current.fromCol, current.fromIdx, col);
    }

    // No active selection. Start a new one.
    if (_isValidGroup(col, idx)) {
      _selected = KlondikeSelection(fromCol: col, fromIdx: idx);
      return false;
    }
    return false;
  }

  /// Deselect the current selection. No-op when nothing is selected.
  void deselect() {
    _selected = null;
  }

  /// Tap a card and route it to a foundation. The card at
  /// (col, idx) must be the top of its column, and must be the legal
  /// next card for [foundationIndex].
  bool tapTableauToFoundation(int col, int idx, int foundationIndex) {
    if (state is! KlondikePlaying) return false;
    if (foundationIndex < 0 || foundationIndex >= 4) return false;
    if (col < 0 || col >= 7) return false;
    final column = tableau[col];
    if (idx != column.length - 1) return false; // must be the top card
    final card = column.cards[idx].card;
    final foundation = foundations[foundationIndex];
    if (!_canMoveToFoundation(card, foundation)) return false;
    _pushHistory();
    column.cards.removeAt(idx);
    foundation.cards.add(PileCard(card: card, faceUp: true));
    _selected = null;
    _revealIfNeeded(col);
    _checkWin();
    return true;
  }

  /// Move the top card of the waste to a foundation. No-op if the
  /// waste is empty or the top card doesn't fit the foundation.
  bool tapWasteToFoundation(int foundationIndex) {
    if (state is! KlondikePlaying) return false;
    if (foundationIndex < 0 || foundationIndex >= 4) return false;
    if (waste.isEmpty) return false;
    final card = waste.last.card;
    final foundation = foundations[foundationIndex];
    if (!_canMoveToFoundation(card, foundation)) return false;
    _pushHistory();
    waste.removeLast();
    foundation.cards.add(PileCard(card: card, faceUp: true));
    _checkWin();
    return true;
  }

  /// Move the top card of the waste to a tableau column. Returns true on
  /// success. The destination column must accept the card by the standard
  /// rules (descending alternating color onto another card, or any
  /// card/group onto an empty column).
  bool tapWasteToTableau(int col) {
    if (state is! KlondikePlaying) return false;
    if (col < 0 || col >= 7) return false;
    if (waste.isEmpty) return false;
    final card = waste.last.card;
    final dest = tableau[col];
    if (!_canDropOnTableau(card, dest)) return false;
    _pushHistory();
    waste.removeLast();
    dest.cards.add(PileCard(card: card, faceUp: true));
    _checkWin();
    return true;
  }

  // ─── Undo ──────────────────────────────────────────────────────────

  /// Pop the most recent snapshot. Returns true if there was anything to
  /// undo; false when the history is empty.
  bool undo() {
    if (state is! KlondikePlaying) return false;
    if (_history.isEmpty) return false;
    final snap = _history.removeLast();
    // Restore the entire state from the snapshot.
    for (var i = 0; i < tableau.length; i++) {
      tableau[i].cards
        ..clear()
        ..addAll(snap.tableau[i]);
    }
    stock
      ..clear()
      ..addAll(snap.stock);
    waste
      ..clear()
      ..addAll(snap.waste);
    for (var i = 0; i < foundations.length; i++) {
      foundations[i].cards
        ..clear()
        ..addAll(snap.foundations[i]);
    }
    state = snap.state;
    return true;
  }

  // ─── Save / restore ────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'version': 1,
    'seed': _seed,
    'elapsedSeconds': elapsedSeconds,
    'tableau': [
      for (final col in tableau)
        [
          for (final pc in col.cards)
            {
              'card': '${_rankChar(pc.card.rank)}${_suitChar(pc.card.suit)}',
              'faceUp': pc.faceUp,
            },
        ],
    ],
    'stock': [for (final pc in stock) _serializePileCard(pc)],
    'waste': [for (final pc in waste) _serializePileCard(pc)],
    'foundations': [
      for (final f in foundations)
        [for (final pc in f.cards) _serializePileCard(pc)],
    ],
    'state': state is KlondikeWon ? 'won' : 'playing',
  };

  factory KlondikeModel.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int || version != 1) {
      throw const FormatException('Unsupported Klondike save version');
    }
    final seed = json['seed'] as int?;
    final elapsed = json['elapsedSeconds'] as int? ?? 0;
    final tableauJson = json['tableau'] as List;
    if (tableauJson.length != 7) {
      throw const FormatException(
        'Klondike save must have exactly 7 tableau columns',
      );
    }
    final tableau = <Pile>[];
    for (final colJson in tableauJson) {
      final cards = <PileCard>[];
      for (final entry in colJson as List) {
        cards.add(_deserializePileCard(entry as Map<String, dynamic>));
      }
      tableau.add(Pile(cards: cards));
    }
    final stockJson = json['stock'] as List;
    final stock = <PileCard>[
      for (final entry in stockJson)
        _deserializePileCard(entry as Map<String, dynamic>),
    ];
    final wasteJson = json['waste'] as List;
    final waste = <PileCard>[
      for (final entry in wasteJson)
        _deserializePileCard(entry as Map<String, dynamic>),
    ];
    final foundationsJson = json['foundations'] as List;
    if (foundationsJson.length != 4) {
      throw const FormatException(
        'Klondike save must have exactly 4 foundations',
      );
    }
    final foundations = <Pile>[];
    for (final fJson in foundationsJson) {
      final cards = <PileCard>[
        for (final entry in fJson as List)
          _deserializePileCard(entry as Map<String, dynamic>),
      ];
      foundations.add(Pile(cards: cards));
    }
    final stateStr = json['state'] as String? ?? 'playing';
    final state = stateStr == 'won'
        ? const KlondikeWon()
        : const KlondikePlaying();

    final model =
        KlondikeModel(
            tableau: tableau,
            stock: stock,
            waste: waste,
            foundations: foundations,
            seed: seed,
          )
          ..state = state
          ..elapsedSeconds = elapsed;
    return model;
  }

  // ─── Private helpers ───────────────────────────────────────────────

  bool _moveTableauToTableau(int fromCol, int fromIdx, int toCol) {
    if (fromCol == toCol) return false;
    final from = tableau[fromCol];
    final to = tableau[toCol];
    if (fromIdx < 0 || fromIdx >= from.length) return false;
    if (!_isValidGroup(fromCol, fromIdx)) return false;
    final top = from.cards[fromIdx].card;
    if (!_canDropOnTableau(top, to)) return false;
    _pushHistory();
    final moving = from.cards.sublist(fromIdx);
    from.cards.removeRange(fromIdx, from.length);
    to.cards.addAll(moving);
    _selected = null;
    _revealIfNeeded(fromCol);
    _checkWin();
    return true;
  }

  bool _isValidGroup(int col, int idx) {
    final column = tableau[col];
    if (idx < 0 || idx >= column.length) return false;
    if (!column.cards[idx].faceUp) return false;
    for (var i = idx; i < column.length - 1; i++) {
      final a = column.cards[i].card;
      final b = column.cards[i + 1].card;
      if (!_isDescendingAlternating(a, b)) return false;
    }
    return true;
  }

  bool _isDescendingAlternating(PlayingCard higher, PlayingCard lower) {
    if (higher.isRed == lower.isRed) return false;
    if (higher.rank.index != lower.rank.index + 1) return false;
    return true;
  }

  bool _canDropOnTableau(PlayingCard card, Pile dest) {
    if (dest.isEmpty) return true; // empty column accepts anything
    final top = dest.top.card;
    return _isDescendingAlternating(top, card);
  }

  bool _canMoveToFoundation(PlayingCard card, Pile foundation) {
    if (foundation.isEmpty) return card.rank == Rank.ace;
    final top = foundation.top.card;
    return top.suit == card.suit && card.rank.index == top.rank.index + 1;
  }

  void _revealIfNeeded(int col) {
    final column = tableau[col];
    if (column.isEmpty) return;
    final top = column.cards.last;
    if (!top.faceUp) {
      column.cards[column.length - 1] = PileCard(card: top.card, faceUp: true);
    }
  }

  void _checkWin() {
    if (state is KlondikeWon) return;
    final allFull = foundations.every((f) => f.length == 13);
    if (allFull) state = const KlondikeWon();
  }

  void _pushHistory() {
    _history.add(
      _Snapshot(
        tableau: [for (final col in tableau) col.cards.toList()],
        stock: stock.toList(),
        waste: waste.toList(),
        foundations: [for (final f in foundations) f.cards.toList()],
        state: state,
      ),
    );
  }

  static Map<String, dynamic> _serializePileCard(PileCard pc) {
    return {
      'rank': pc.card.rank.index,
      'suit': pc.card.suit.index,
      'faceUp': pc.faceUp,
    };
  }

  static PileCard _deserializePileCard(Map<String, dynamic> json) {
    // Accepts the compact 2-char form (used for tableau entries) or the
    // full { rank, suit, faceUp } form (used for stock / waste / foundations).
    if (json.containsKey('card')) {
      // Compact form: "AH", "10C", "KS"... `faceUp` is the explicit
      // boolean field that may also be present.
      final s = json['card'] as String;
      if (s.length < 2) {
        throw FormatException('Invalid card string: $s');
      }
      // Rank char(s) at the front, suit char at the end.
      final suitChar = s[s.length - 1];
      final rankStr = s.substring(0, s.length - 1);
      final rank = _rankFromString(rankStr);
      final suit = _suitFromChar(suitChar);
      final faceUp = json['faceUp'] as bool? ?? true;
      return PileCard(
        card: PlayingCard(suit: suit, rank: rank),
        faceUp: faceUp,
      );
    }
    // Full form: { rank, suit, faceUp }.
    final rankIdx = json['rank'] as int;
    final suitIdx = json['suit'] as int;
    final faceUp = json['faceUp'] as bool? ?? true;
    if (rankIdx < 0 || rankIdx >= Rank.values.length) {
      throw FormatException('Invalid rank index: $rankIdx');
    }
    if (suitIdx < 0 || suitIdx >= Suit.values.length) {
      throw FormatException('Invalid suit index: $suitIdx');
    }
    return PileCard(
      card: PlayingCard(suit: Suit.values[suitIdx], rank: Rank.values[rankIdx]),
      faceUp: faceUp,
    );
  }

  static String _rankChar(Rank r) {
    return switch (r) {
      Rank.ace => 'A',
      Rank.jack => 'J',
      Rank.queen => 'Q',
      Rank.king => 'K',
      _ => '${r.index + 1}',
    };
  }

  static String _suitChar(Suit s) {
    return switch (s) {
      Suit.clubs => 'C',
      Suit.diamonds => 'D',
      Suit.hearts => 'H',
      Suit.spades => 'S',
    };
  }

  static Rank _rankFromString(String s) {
    return switch (s) {
      'A' => Rank.ace,
      'J' => Rank.jack,
      'Q' => Rank.queen,
      'K' => Rank.king,
      _ => Rank.values[int.parse(s) - 1],
    };
  }

  static Suit _suitFromChar(String c) {
    return switch (c) {
      'C' => Suit.clubs,
      'D' => Suit.diamonds,
      'H' => Suit.hearts,
      'S' => Suit.spades,
      _ => throw FormatException('Invalid suit char: $c'),
    };
  }
}

class _Snapshot {
  _Snapshot({
    required this.tableau,
    required this.stock,
    required this.waste,
    required this.foundations,
    required this.state,
  });

  final List<List<PileCard>> tableau;
  final List<PileCard> stock;
  final List<PileCard> waste;
  final List<List<PileCard>> foundations;
  final KlondikeState state;
}
