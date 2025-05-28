import 'package:flutter/material.dart';

class DiceIcon extends StatelessWidget {
  final double size;
  final Color color;

  const DiceIcon({
    super.key,
    this.size = 100,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: DiceIconPainter(color: color),
    );
  }
}

class DiceIconPainter extends CustomPainter {
  final Color color;

  DiceIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Zar karesi
    final diceRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(diceRect, paint);
    canvas.drawRect(diceRect, strokePaint);

    // Noktalar
    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final dotRadius = size.width / 10;
    final padding = size.width / 4;

    // Sol üst nokta
    canvas.drawCircle(
      Offset(padding, padding),
      dotRadius,
      dotPaint,
    );

    // Sağ alt nokta
    canvas.drawCircle(
      Offset(size.width - padding, size.height - padding),
      dotRadius,
      dotPaint,
    );

    // Orta nokta
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      dotRadius,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
