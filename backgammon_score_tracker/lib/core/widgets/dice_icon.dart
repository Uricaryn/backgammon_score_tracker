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
    // Enable anti-aliasing for smoother edges
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cornerRadius = size.width * 0.15;

    // Create the dice path with rounded corners
    final dicePath = Path()
      ..moveTo(cornerRadius, 0)
      ..lineTo(size.width - cornerRadius, 0)
      ..arcToPoint(
        Offset(size.width, cornerRadius),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      )
      ..lineTo(size.width, size.height - cornerRadius)
      ..arcToPoint(
        Offset(size.width - cornerRadius, size.height),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      )
      ..lineTo(cornerRadius, size.height)
      ..arcToPoint(
        Offset(0, size.height - cornerRadius),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      )
      ..lineTo(0, cornerRadius)
      ..arcToPoint(
        Offset(cornerRadius, 0),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      )
      ..close();

    // Create gradient for 3D effect with more color stops for smoother transition
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withOpacity(0.95),
        color.withOpacity(0.85),
        color.withOpacity(0.75),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    // Draw shadow with softer edges
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..isAntiAlias = true;

    canvas.drawPath(
      dicePath,
      shadowPaint,
    );

    // Draw the dice with gradient
    final dicePaint = Paint()
      ..shader =
          gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..isAntiAlias = true;

    canvas.drawPath(dicePath, dicePaint);

    // Draw border with anti-aliasing
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawPath(dicePath, borderPaint);

    // Draw dots with refined gradients
    final dotRadius = size.width * 0.07;
    final padding = size.width * 0.25;

    // Create dot gradient with more color stops for smoother appearance
    final dotGradient = RadialGradient(
      colors: [
        Colors.white,
        Colors.white.withOpacity(0.95),
        Colors.white.withOpacity(0.9),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final dotPaint = Paint()
      ..shader = dotGradient.createShader(Rect.fromCircle(
        center: Offset(padding, padding),
        radius: dotRadius,
      ))
      ..isAntiAlias = true;

    // Draw dots with softer shadows
    final dotShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..isAntiAlias = true;

    // Helper function to draw a dot with shadow
    void drawDot(Offset center) {
      canvas.drawCircle(
        center,
        dotRadius + 1.5,
        dotShadowPaint,
      );
      canvas.drawCircle(
        center,
        dotRadius,
        dotPaint,
      );
    }

    // Draw all dots
    drawDot(Offset(padding, padding)); // Top-left
    drawDot(Offset(size.width / 2, size.height / 2)); // Center
    drawDot(
        Offset(size.width - padding, size.height - padding)); // Bottom-right

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
