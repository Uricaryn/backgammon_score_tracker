import 'package:flutter/material.dart';

class BackgammonBoard extends StatelessWidget {
  final double opacity;

  const BackgammonBoard({
    super.key,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BackgammonBoardPainter(opacity: opacity),
      child: Container(),
    );
  }
}

class BackgammonBoardPainter extends CustomPainter {
  final double opacity;

  BackgammonBoardPainter({this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(opacity);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.brown.withOpacity(opacity)
      ..strokeWidth = 2.0;

    // Draw the main board
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(boardRect, paint);
    canvas.drawRect(boardRect, borderPaint);

    // Draw the triangles
    final triangleWidth = size.width / 12;
    final triangleHeight = size.height / 2;

    for (var i = 0; i < 12; i++) {
      final x = i * triangleWidth;

      // Top triangles
      final topPath = Path()
        ..moveTo(x, 0)
        ..lineTo(x + triangleWidth, 0)
        ..lineTo(x + triangleWidth / 2, triangleHeight)
        ..close();

      // Bottom triangles
      final bottomPath = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + triangleWidth, size.height)
        ..lineTo(x + triangleWidth / 2, triangleHeight)
        ..close();

      // Alternate colors
      final isEven = i % 2 == 0;
      final trianglePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = (isEven ? Colors.brown : Colors.brown.shade200)
            .withOpacity(opacity);

      canvas.drawPath(topPath, trianglePaint);
      canvas.drawPath(bottomPath, trianglePaint);
      canvas.drawPath(topPath, borderPaint);
      canvas.drawPath(bottomPath, borderPaint);
    }

    // Draw the bar
    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.brown.shade300.withOpacity(opacity);

    final barRect = Rect.fromLTWH(
      size.width / 2 - 2,
      0,
      4,
      size.height,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
