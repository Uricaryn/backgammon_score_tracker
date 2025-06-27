import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';

class BackgammonBoard extends StatelessWidget {
  final double opacity;

  const BackgammonBoard({
    super.key,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BackgammonBoardPainter(
        opacity: opacity,
        context: context,
      ),
      child: Container(),
    );
  }
}

class BackgammonBoardPainter extends CustomPainter {
  final double opacity;
  final BuildContext context;

  BackgammonBoardPainter({
    this.opacity = 1.0,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware colors
    final boardLightColor = AppTheme.getBoardLightColor(context);
    final boardDarkColor = AppTheme.getBoardDarkColor(context);
    final boardBorderColor = AppTheme.getBoardBorderColor(context);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = boardLightColor.withOpacity(opacity);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = boardBorderColor.withOpacity(opacity)
      ..strokeWidth = isDark ? 1.5 : 2.0; // Dark mode'da daha ince border

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

      // Alternate colors with theme awareness
      final isEven = i % 2 == 0;
      final trianglePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = (isEven ? boardDarkColor : boardLightColor).withOpacity(isDark
            ? opacity * 0.7
            : opacity); // Dark mode'da daha düşük opacity

      canvas.drawPath(topPath, trianglePaint);
      canvas.drawPath(bottomPath, trianglePaint);
      canvas.drawPath(topPath, borderPaint);
      canvas.drawPath(bottomPath, borderPaint);
    }

    // Draw the bar with theme-aware color
    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = boardBorderColor.withOpacity(isDark ? opacity * 0.8 : opacity);

    final barRect = Rect.fromLTWH(
      size.width / 2 - (isDark ? 1.5 : 2), // Dark mode'da daha ince bar
      0,
      isDark ? 3 : 4,
      size.height,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
