import 'package:flutter/material.dart';

class PlayerInfo {
  final String label;
  final Color color;
  final int? score; // null = hide score

  const PlayerInfo({required this.label, required this.color, this.score});
}

/// Animated turn-indicator bar used by all four board widgets.
class GameStatusBar extends StatelessWidget {
  final PlayerInfo player1;
  final PlayerInfo player2;

  /// 1 or 2 — whose turn it is. 0 = game over (both chips de-emphasised).
  final int activePlayer;

  /// Optional override message (e.g. "Computer thinking…", "Black wins!").
  /// When null the bar shows "{active player label}'s turn".
  final String? message;

  const GameStatusBar({
    super.key,
    required this.player1,
    required this.player2,
    required this.activePlayer,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activeLabel = activePlayer == 1
        ? player1.label
        : activePlayer == 2
        ? player2.label
        : '';
    final defaultMsg = activePlayer == 0 ? '' : "$activeLabel's turn";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _PlayerChip(info: player1, isActive: activePlayer == 1),
          Expanded(
            child: Center(
              child: Text(
                message ?? defaultMsg,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: message != null
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _PlayerChip(info: player2, isActive: activePlayer == 2),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final PlayerInfo info;
  final bool isActive;

  const _PlayerChip({required this.info, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? info.color.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: isActive ? info.color : cs.outline.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: info.color,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: info.color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            info.score != null ? '${info.label}  ${info.score}' : info.label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? info.color : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
