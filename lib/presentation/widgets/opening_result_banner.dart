import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/package_dice_panel.dart';

/// Oyun başlarken açılış zarlarının sonucu ve ilk hamleyi yapacak oyuncu.
class OpeningResultBanner extends StatelessWidget {
  const OpeningResultBanner({
    super.key,
    required this.whiteDie,
    required this.blackDie,
    required this.firstPlayer,
    required this.firstPlayerName,
  });

  final int whiteDie;
  final int blackDie;
  final PlayerColor firstPlayer;
  final String firstPlayerName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      color: cs.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.flag_circle_outlined, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Açılış zarı',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _DieLine(label: 'Beyaz', value: whiteDie),
                      _DieLine(label: 'Siyah', value: blackDie),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'İlk hamle',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstPlayerName,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: firstPlayer == PlayerColor.white
                          ? Colors.brown.shade800
                          : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: -0.08, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}

class _DieLine extends StatelessWidget {
  const _DieLine({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        PackageDieFace(value: value, size: 36),
      ],
    );
  }
}
