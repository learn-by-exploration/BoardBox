import 'package:flutter/material.dart';

import 'package:common_games/games/cards/card.dart';

/// A playing-card visual. Pure Material — text on a tinted rounded rect,
/// no PNG assets. Suits are tinted red (hearts/diamonds) or black
/// (clubs/spades). Face-down renders a back-pattern with the suit color
/// family in the theme.
///
/// All [CardView]s are at least 48 × 48 dp to satisfy the touch-target
/// requirement in [AGENTS.md]. The widget sizes itself to [width] ×
/// [height] if provided, otherwise fills the available size.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.faceDown = false,
    this.width,
    this.height,
    this.highlighted = false,
  }) : assert(
         !(faceDown && highlighted),
         'A face-down card cannot be highlighted as a destination',
       );

  final PlayingCard card;
  final bool faceDown;
  final double? width;
  final double? height;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRed = card.isRed;
    final fg = isRed ? const Color(0xFFC62828) : const Color(0xFF1A1A1A);
    final bg = colorScheme.surface;
    final border = highlighted
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    final w = width ?? double.infinity;
    final h = height ?? double.infinity;

    return SizedBox(
      width: w,
      height: h,
      child: Material(
        elevation: highlighted ? 6 : 1,
        color: faceDown ? colorScheme.primaryContainer : bg,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: highlighted ? 2 : 1),
          ),
          child: faceDown
              ? _BackPattern(color: colorScheme.onPrimaryContainer)
              : Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Corner(rank: card.rank, suit: card.suit, fg: fg),
                      Center(
                        child: _SuitGlyph(suit: card.suit, fg: fg),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: RotatedBox(
                          quarterTurns: 2,
                          child: _Corner(
                            rank: card.rank,
                            suit: card.suit,
                            fg: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.rank, required this.suit, required this.fg});

  final Rank rank;
  final Suit suit;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _rankShort(rank),
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1,
          ),
        ),
        Text(
          _suitChar(suit),
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _SuitGlyph extends StatelessWidget {
  const _SuitGlyph({required this.suit, required this.fg});

  final Suit suit;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Text(
      _suitChar(suit),
      style: TextStyle(
        color: fg,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1,
      ),
    );
  }
}

/// Subtle geometric pattern for the back of a card. Three concentric
/// diamonds. Cheap to render and reads at small sizes.
class _BackPattern extends StatelessWidget {
  const _BackPattern({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Icon(
          Icons.style_rounded,
          color: color.withValues(alpha: 0.7),
          size: 28,
        ),
      ),
    );
  }
}

String _rankShort(Rank r) {
  return switch (r) {
    Rank.ace => 'A',
    Rank.jack => 'J',
    Rank.queen => 'Q',
    Rank.king => 'K',
    _ => '${r.index + 1}',
  };
}

String _suitChar(Suit s) {
  return switch (s) {
    Suit.clubs => '♣',
    Suit.diamonds => '♦',
    Suit.hearts => '♥',
    Suit.spades => '♠',
  };
}
