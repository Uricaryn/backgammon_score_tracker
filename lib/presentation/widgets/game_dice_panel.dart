import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/package_dice_panel.dart';

class GameDicePanel extends StatefulWidget {
  const GameDicePanel({
    super.key,
    required this.remainingDice,
    required this.onRoll,
    required this.canRoll,
  });

  final List<int> remainingDice;
  final VoidCallback onRoll;
  final bool canRoll;

  @override
  State<GameDicePanel> createState() => _GameDicePanelState();
}

class _GameDicePanelState extends State<GameDicePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _rolling = false;
  List<int> _flashDice = [];
  final _rng = Random();

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
  void didUpdateWidget(covariant GameDicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();

    final newDice = widget.remainingDice;
    final oldDice = oldWidget.remainingDice;
    if (newDice.isNotEmpty && oldDice.isEmpty && !_rolling) {
      _playRollAnimation(newDice);
    }
  }

  void _syncPulse() {
    if (widget.canRoll) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  Future<void> _playRollAnimation(List<int> finalDice) async {
    setState(() => _rolling = true);
    await playDiceRollFlash(
      finalDice: finalDice,
      random: _rng,
      isMounted: () => mounted,
      onFlash: (flash) {
        if (!mounted) return;
        setState(() => _flashDice = flash);
      },
    );
    if (!mounted) return;
    setState(() {
      _flashDice = finalDice;
      _rolling = false;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDice = widget.remainingDice.isNotEmpty;
    final displayDice = _rolling ? _flashDice : widget.remainingDice;

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
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: hasDice || _rolling
                  ? PackageDiceRow(
                      key: ValueKey<String>(
                        'dice-${displayDice.join(",")}-$_rolling',
                      ),
                      values: displayDice,
                      rolling: _rolling,
                    )
                  : _StatusMessageRow(
                      key: ValueKey<String>('status-${widget.canRoll}'),
                      canRoll: widget.canRoll,
                      colorScheme: cs,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final scale = widget.canRoll
                  ? 1.0 + (_pulseCtrl.value * 0.04)
                  : 1.0;
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
}

class _StatusMessageRow extends StatelessWidget {
  const _StatusMessageRow({
    super.key,
    required this.canRoll,
    required this.colorScheme,
  });

  final bool canRoll;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          canRoll ? Icons.casino_outlined : Icons.hourglass_bottom,
          size: 16,
          color: canRoll ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            canRoll ? 'Zar atmak icin butona bas' : 'Rakip oynuyor...',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 3D Dice Widget ──────────────────────────────────────────────────────────

// ignore: library_private_types_in_public_api
class Dice3D extends StatelessWidget {
  const Dice3D({
    super.key,
    required this.value,
    required this.size,
    this.rolling = false,
    this.delay = Duration.zero,
    this.tumble3D = false,
  });

  final int value;
  final double size;
  final bool rolling;
  final Duration delay;
  final bool tumble3D;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget die = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF4A4A4A), const Color(0xFF353535)]
              : [Colors.white, const Color(0xFFF0EDE8)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
            blurRadius: 6,
            offset: const Offset(1, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: CustomPaint(
        painter: DiceDotsPainter(
          value: value.clamp(1, 6),
          isDark: isDark,
        ),
      ),
    );

    if (rolling) {
      Widget rollingDie = die
          .animate(onPlay: (c) => c.repeat())
          .rotate(
            duration: 200.ms,
            begin: -0.08,
            end: 0.08,
          )
          .scale(
            duration: 150.ms,
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.06, 1.06),
          );
      if (tumble3D) {
        rollingDie = rollingDie
            .animate(onPlay: (c) => c.repeat())
            .custom(
              duration: 220.ms,
              builder: (context, value, child) {
                final tiltX = sin(value * pi * 2) * 0.35;
                final tiltY = cos(value * pi * 2) * 0.25;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(tiltX)
                    ..rotateY(tiltY),
                  child: child,
                );
              },
            );
      }
      return rollingDie;
    }

    return die
        .animate(delay: delay)
        .scale(
          duration: 400.ms,
          begin: const Offset(0.3, 0.3),
          end: const Offset(1.0, 1.0),
          curve: Curves.elasticOut,
        )
        .rotate(
          duration: 350.ms,
          begin: 0.15,
          end: 0.0,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 200.ms);
  }
}

class DiceDotsPainter extends CustomPainter {
  final int value;
  final bool isDark;

  const DiceDotsPainter({required this.value, required this.isDark});

  static const Map<int, List<Offset>> _dots = {
    1: [Offset(0.50, 0.50)],
    2: [Offset(0.30, 0.30), Offset(0.70, 0.70)],
    3: [Offset(0.30, 0.30), Offset(0.50, 0.50), Offset(0.70, 0.70)],
    4: [Offset(0.30, 0.30), Offset(0.70, 0.30), Offset(0.30, 0.70), Offset(0.70, 0.70)],
    5: [Offset(0.30, 0.30), Offset(0.70, 0.30), Offset(0.50, 0.50), Offset(0.30, 0.70), Offset(0.70, 0.70)],
    6: [Offset(0.30, 0.22), Offset(0.70, 0.22), Offset(0.30, 0.50), Offset(0.70, 0.50), Offset(0.30, 0.78), Offset(0.70, 0.78)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final dotColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final dotR = size.width * 0.085;
    final positions = _dots[value] ?? _dots[1]!;

    for (final pos in positions) {
      final center = Offset(pos.dx * size.width, pos.dy * size.height);

      // Embossed shadow (inset effect)
      canvas.drawCircle(
        center + const Offset(0, 0.8),
        dotR,
        Paint()..color = (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.3),
      );
      // Dot
      canvas.drawCircle(center, dotR, Paint()..color = dotColor);
    }
  }

  @override
  bool shouldRepaint(DiceDotsPainter old) =>
      old.value != value || old.isDark != isDark;
}
