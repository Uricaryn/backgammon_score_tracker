import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/presentation/widgets/game_dice_panel.dart'
    show Dice3D;

/// Shown at the start of every game while both players roll their opening die.
///
/// Layout:
///   ┌──────────────────────────────────────────────────────┐
///   │  Başlangıç zarı   ·   Büyük olan başlar              │
///   │  ○ Beyaz: [die]   ●  Siyah: [die]   [Zar At]        │
///   └──────────────────────────────────────────────────────┘
class OpeningRollPanel extends StatefulWidget {
  const OpeningRollPanel({
    super.key,
    required this.openingRollWhite,
    required this.openingRollBlack,
    required this.myColor,
    required this.canRoll,
    required this.onRoll,
  });

  final int? openingRollWhite;
  final int? openingRollBlack;
  final PlayerColor myColor;
  final bool canRoll;
  final VoidCallback onRoll;

  @override
  State<OpeningRollPanel> createState() => _OpeningRollPanelState();
}

class _OpeningRollPanelState extends State<OpeningRollPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant OpeningRollPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.canRoll) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHighest.withValues(alpha: 0.75),
            cs.surfaceContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Die slots ───────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                _DieSlot(
                  label: 'Beyaz',
                  dotColor: Colors.white,
                  borderColor: Colors.brown.shade300,
                  value: widget.openingRollWhite,
                ),
                const SizedBox(width: 12),
                _DieSlot(
                  label: 'Siyah',
                  dotColor: Colors.black87,
                  borderColor: Colors.grey.shade600,
                  value: widget.openingRollBlack,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _statusText(),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── Roll button ─────────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final scale =
                  widget.canRoll ? 1.0 + (_pulseCtrl.value * 0.04) : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: widget.canRoll
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: FilledButton.icon(
                onPressed: widget.canRoll
                    ? () {
                        HapticFeedback.mediumImpact();
                        widget.onRoll();
                      }
                    : null,
                icon: const Icon(Icons.casino, size: 18),
                label: const Text('Zar At'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  elevation: widget.canRoll ? 2 : 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    final myRolled = widget.myColor == PlayerColor.white
        ? widget.openingRollWhite != null
        : widget.openingRollBlack != null;
    final opponentRolled = widget.myColor == PlayerColor.white
        ? widget.openingRollBlack != null
        : widget.openingRollWhite != null;

    if (!myRolled && !opponentRolled) {
      return 'Başlangıç zarı → Büyük olan başlar';
    }
    if (myRolled && !opponentRolled) {
      return 'Rakipin zarı bekleniyor…';
    }
    if (!myRolled && opponentRolled) {
      return 'Zarını at!';
    }
    return '';
  }
}

// ── Single die slot ──────────────────────────────────────────────────────────

class _DieSlot extends StatelessWidget {
  const _DieSlot({
    required this.label,
    required this.dotColor,
    required this.borderColor,
    required this.value,
  });

  final String label;
  final Color dotColor;
  final Color borderColor;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        if (value != null)
          Dice3D(value: value!, size: 40)
              .animate()
              .scale(
                duration: 400.ms,
                begin: const Offset(0.3, 0.3),
                end: const Offset(1.0, 1.0),
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 200.ms)
        else
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            child: Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
