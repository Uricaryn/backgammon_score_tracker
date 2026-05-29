import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Top strip: Zar At button + status text (dice render on [BoardThrownDiceOverlay]).
class DiceControlStrip extends StatelessWidget {
  const DiceControlStrip({
    super.key,
    required this.canRoll,
    this.onRollTap,
    this.isRolling = false,
    this.hasDiceOnBoard = false,
    this.compact = false,
    this.showRollButton = true,
  });

  final bool canRoll;
  final VoidCallback? onRollTap;
  final bool isRolling;
  final bool hasDiceOnBoard;
  final bool compact;
  /// When true and [onRollTap] is set, always show Zar At (disabled when !canRoll).
  final bool showRollButton;

  @override
  Widget build(BuildContext context) {
    final statusText = isRolling
        ? 'Zarlar atiliyor...'
        : hasDiceOnBoard
            ? 'Zarlar masada'
            : canRoll
                ? 'Zar at'
                : 'Bekleniyor...';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: compact ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (showRollButton && onRollTap != null) ...[
              FilledButton.icon(
                onPressed: canRoll && !isRolling
                    ? () {
                        HapticFeedback.mediumImpact();
                        onRollTap!();
                      }
                    : null,
                icon: isRolling
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      )
                    : const Icon(Icons.casino, size: 18),
                label: const Text('Zar At'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A227),
                  foregroundColor: Colors.black87,
                  disabledBackgroundColor:
                      const Color(0xFFC9A227).withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.black54,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: compact ? 8 : 10,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
            ] else if (isRolling) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
