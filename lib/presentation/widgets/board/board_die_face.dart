import 'package:flutter/material.dart';

/// Red die face from roll_dice_2d assets (shared by strip and board overlays).
class BoardDieFace extends StatelessWidget {
  const BoardDieFace({
    super.key,
    required this.value,
    required this.size,
    this.shadowOpacity = 0.5,
  });

  final int value;
  final double size;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final face = value.clamp(1, 6);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: size * 0.15,
            offset: Offset(size * 0.06, size * 0.1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.14),
        child: Image.asset(
          'assets/images/dice_red_$face.png',
          package: 'roll_dice_2d',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
