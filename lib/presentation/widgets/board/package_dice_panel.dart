import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:roll_dice_2d/roll_dice_2d.dart';

/// Dice row using bundled photo-style faces from [roll_dice_2d].
class PackageDiceRow extends StatelessWidget {
  const PackageDiceRow({
    super.key,
    required this.values,
    required this.rolling,
    this.dieSize = 58,
    this.showTray = true,
  });

  final List<int> values;
  final bool rolling;
  final double dieSize;
  final bool showTray;

  @override
  Widget build(BuildContext context) {
    final dice = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < values.length; i++)
          PackageDieFace(
            key: ValueKey('die-$i-${values[i]}-$rolling'),
            value: values[i],
            size: dieSize,
            rolling: rolling,
            animateEntrance: !rolling && i == 0,
          ),
      ],
    );

    if (!showTray) return dice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
        border: Border.all(color: const Color(0xFF81C784), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: dice,
    );
  }
}

/// Single die — red 3D PNG from [roll_dice_2d] (high contrast on green tray).
class PackageDieFace extends StatelessWidget {
  const PackageDieFace({
    super.key,
    required this.value,
    required this.size,
    this.rolling = false,
    this.animateEntrance = false,
    this.color = DiceColor.red,
  });

  final int value;
  final double size;
  final bool rolling;
  final bool animateEntrance;
  final DiceColor color;

  static String assetPath(DiceColor color, int face) =>
      'assets/images/dice_${color.name}_${face.clamp(1, 6)}.png';

  Widget _dieImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.14),
        child: Image.asset(
          assetPath(color, value),
          package: 'roll_dice_2d',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _FallbackDie(value: value, size: size),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rolling) {
      return _dieImage()
          .animate(onPlay: (c) => c.repeat())
          .shake(hz: 14, rotation: 0.12)
          .scale(
            duration: 120.ms,
            begin: const Offset(0.88, 0.88),
            end: const Offset(1.08, 1.08),
          );
    }

    final die = _dieImage();
    if (!animateEntrance) return die;

    return die
        .animate()
        .scale(
          duration: 450.ms,
          begin: const Offset(0.2, 0.2),
          end: const Offset(1.0, 1.0),
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 250.ms);
  }
}

class _FallbackDie extends StatelessWidget {
  const _FallbackDie({required this.value, required this.size});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFC62828),
        borderRadius: BorderRadius.circular(size * 0.14),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Future<List<int>> playDiceRollFlash({
  required List<int> finalDice,
  required void Function(List<int> flash) onFlash,
  required bool Function() isMounted,
  Random? random,
}) async {
  final rng = random ?? Random();
  for (int i = 0; i < 8; i++) {
    if (!isMounted()) return finalDice;
    onFlash(
      List.generate(finalDice.length, (_) => rng.nextInt(6) + 1),
    );
    await Future.delayed(Duration(milliseconds: 50 + i * 28));
  }
  return finalDice;
}
