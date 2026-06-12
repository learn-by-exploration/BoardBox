import 'package:flutter/material.dart';

import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/cards/card_widget.dart';
import 'package:common_games/games/klondike/klondike_model.dart';
import 'package:common_games/services/haptic_service.dart';

/// Renders a Klondike play area. Pure presentation: it owns the
/// [KlondikeModel] and calls its methods on tap. The widget exposes the
/// current move count and selection via the model getters, so callers
/// (game screen) can render an AppBar and a status bar.
///
/// The top strip is 4 foundations + stock + waste. Below it sits the
/// 7-column tableau. Tap a card to select the contiguous face-up
/// descending-alternating group; tap a destination to move it there.
/// Tapping the same selected card deselects.
class KlondikeBoard extends StatefulWidget {
  const KlondikeBoard({super.key, required this.model, this.onModelChanged});

  /// The model to render. The board mutates it on tap.
  final KlondikeModel model;

  /// Called after any user-driven mutation (tap, stock flip, etc.).
  /// Useful for the screen to know when to save or update its
  /// auto-complete / hint / status-bar state.
  final ValueChanged<KlondikeModel>? onModelChanged;

  @override
  State<KlondikeBoard> createState() => _KlondikeBoardState();
}

class _KlondikeBoardState extends State<KlondikeBoard> {
  void _mutate(void Function() fn) {
    setState(fn);
    widget.onModelChanged?.call(widget.model);
  }

  void _onTapTableau(int col, int idx) {
    final currentSelection = widget.model.selectedPile;
    if (currentSelection != null &&
        currentSelection.fromCol == col &&
        currentSelection.fromIdx == idx) {
      // Tapping the currently-selected card deselects it.
      _mutate(widget.model.deselect);
      HapticService.onSelect();
      return;
    }
    final moved = widget.model.tapTableau(col, idx);
    if (moved) {
      HapticService.onMove();
    } else {
      HapticService.onSelect();
    }
    if (widget.model.selectedPile != currentSelection || moved) {
      _mutate(() {});
    }
  }

  void _onTapWaste() {
    // No waste->tableau/foundation selection in v1; the screen wires its
    // own buttons for those. We just leave the tap as a no-op so a stray
    // tap on the waste doesn't try to do something unintended.
  }

  void _onTapStock() {
    _mutate(widget.model.flipStock);
    HapticService.onMove();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _TopStrip(
                stockCount: widget.model.stock.length,
                wasteTop: widget.model.waste.isEmpty
                    ? null
                    : widget.model.waste.last,
                foundations: widget.model.foundations,
                onTapStock: _onTapStock,
                onTapWaste: _onTapWaste,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _TableauRow(model: widget.model, onTap: _onTapTableau),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The top strip: 4 foundation slots, then stock and waste. Sized by
/// [LayoutBuilder] so it works at any width.
class _TopStrip extends StatelessWidget {
  const _TopStrip({
    required this.stockCount,
    required this.wasteTop,
    required this.foundations,
    required this.onTapStock,
    required this.onTapWaste,
  });

  final int stockCount;
  final PileCard? wasteTop;
  final List<Pile> foundations;
  final VoidCallback onTapStock;
  final VoidCallback onTapWaste;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: _FoundationSlot(pile: foundations[i], suit: Suit.values[i]),
          ),
        const SizedBox(width: 8),
        _StockPile(count: stockCount, onTap: onTapStock),
        const SizedBox(width: 8),
        _WasteSlot(top: wasteTop, onTap: onTapWaste),
      ],
    );
  }
}

class _FoundationSlot extends StatelessWidget {
  const _FoundationSlot({required this.pile, required this.suit});

  final Pile pile;
  final Suit suit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Foundation ${_suitName(suit)}, ${pile.length} cards',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: pile.isEmpty
              ? Center(
                  child: Text(
                    _suitChar(suit),
                    style: TextStyle(
                      color: colorScheme.outline,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(2),
                  child: CardView(card: pile.top.card),
                ),
        ),
      ),
    );
  }
}

class _StockPile extends StatelessWidget {
  const _StockPile({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Stock, $count cards',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 72,
          child: count > 0
              ? const CardView(
                  card: PlayingCard(suit: Suit.clubs, rank: Rank.ace),
                  faceDown: true,
                )
              : Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: colorScheme.outline,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }
}

class _WasteSlot extends StatelessWidget {
  const _WasteSlot({required this.top, required this.onTap});

  final PileCard? top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: top == null
          ? 'Waste, empty'
          : 'Waste, top: ${_suitName(top!.card.suit)} of ${_rankName(top!.card.rank)}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 72,
          child: top == null
              ? const SizedBox.shrink()
              : CardView(card: top!.card),
        ),
      ),
    );
  }
}

/// The 7-column tableau. Each card is fanned vertically — small offset
/// for face-down cards, larger offset for face-up cards. Selection is
/// highlighted with a colored border.
class _TableauRow extends StatelessWidget {
  const _TableauRow({required this.model, required this.onTap});

  final KlondikeModel model;
  final void Function(int col, int idx) onTap;

  static const _faceDownOffset = 8.0;
  static const _faceUpOffset = 18.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Card width = (constraint - gaps) / 7. Clamped to 48dp so each
        // tappable card meets the 48dp touch-target requirement. The
        // height is width × 1.5 (card aspect 2/3), so width ≥ 48 gives
        // a height ≥ 72 — comfortably above the threshold.
        final cardWidth = ((constraints.maxWidth - 6 * 4) / 7).clamp(
          48.0,
          80.0,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < 7; col++) ...[
              SizedBox(
                width: cardWidth,
                child: _TableauColumn(
                  model: model,
                  col: col,
                  cardWidth: cardWidth,
                  faceDownOffset: _faceDownOffset,
                  faceUpOffset: _faceUpOffset,
                  onTap: (idx) => onTap(col, idx),
                ),
              ),
              if (col < 6) const SizedBox(width: 4),
            ],
          ],
        );
      },
    );
  }
}

class _TableauColumn extends StatelessWidget {
  const _TableauColumn({
    required this.model,
    required this.col,
    required this.cardWidth,
    required this.faceDownOffset,
    required this.faceUpOffset,
    required this.onTap,
  });

  final KlondikeModel model;
  final int col;
  final double cardWidth;
  final double faceDownOffset;
  final double faceUpOffset;
  final void Function(int idx) onTap;

  bool _isInSelection(int idx) {
    final sel = model.selectedPile;
    if (sel == null || sel.fromCol != col) return false;
    return idx >= sel.fromIdx;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pile = model.tableau[col];
    if (pile.isEmpty) {
      return GestureDetector(
        onTap: () => onTap(0),
        child: Container(
          height: cardWidth * 1.5,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
        ),
      );
    }
    return SizedBox(
      width: cardWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var idx = 0; idx < pile.length; idx++)
            Positioned(
              top:
                  idx *
                  (pile.cards[idx].faceUp ? faceUpOffset : faceDownOffset),
              left: 0,
              child: GestureDetector(
                onTap: () => onTap(idx),
                child: CardView(
                  card: pile.cards[idx].card,
                  faceDown: !pile.cards[idx].faceUp,
                  width: cardWidth,
                  height: cardWidth * 1.5,
                  highlighted: _isInSelection(idx),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _suitChar(Suit s) {
  return switch (s) {
    Suit.clubs => '♣',
    Suit.diamonds => '♦',
    Suit.hearts => '♥',
    Suit.spades => '♠',
  };
}

String _suitName(Suit s) {
  return switch (s) {
    Suit.clubs => 'clubs',
    Suit.diamonds => 'diamonds',
    Suit.hearts => 'hearts',
    Suit.spades => 'spades',
  };
}

String _rankName(Rank r) {
  return switch (r) {
    Rank.ace => 'ace',
    Rank.jack => 'jack',
    Rank.queen => 'queen',
    Rank.king => 'king',
    _ => '${r.index + 1}',
  };
}
