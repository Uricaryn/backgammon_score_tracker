import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/services/board_assets_service.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';

/// Premium marble-style checker (no external assets required).
void paintChecker(
  Canvas canvas,
  double cx,
  double cy,
  double r,
  bool white, {
  BoardAssetsService? assets,
}) {
  final sprite = assets?.checkerImage(white);
  if (sprite != null) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawImageRect(
      sprite,
      Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.high,
    );
    return;
  }

  // Contact shadow
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(cx + 1, cy + r * 0.35),
      width: r * 1.85,
      height: r * 0.55,
    ),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );

  // Side bevel (darker crescent)
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx + r * 0.35, cy + r * 0.2),
        r * 1.2,
        [
          Colors.transparent,
          (white ? const Color(0xFFB8A898) : const Color(0xFF1A1A1A))
              .withValues(alpha: 0.55),
        ],
      ),
  );

  // Main marble body
  final bodyColors = white
      ? [
          const Color(0xFFFFFDF8),
          const Color(0xFFF5EBE0),
          const Color(0xFFE8D5C4),
          const Color(0xFFD4C4B0),
        ]
      : [
          const Color(0xFF4A4A4A),
          const Color(0xFF2E2E2E),
          const Color(0xFF1A1A1A),
          const Color(0xFF0D0D0D),
        ];

  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - r * 0.3, cy - r * 0.35),
        r * 1.55,
        bodyColors,
        [0.0, 0.35, 0.72, 1.0],
      ),
  );

  // Marble vein (subtle)
  if (white) {
    final vein = Path()
      ..moveTo(cx - r * 0.5, cy - r * 0.1)
      ..quadraticBezierTo(cx, cy + r * 0.2, cx + r * 0.4, cy - r * 0.3);
    canvas.drawPath(
      vein,
      Paint()
        ..color = const Color(0xFFD7CEC4).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12,
    );
  }

  // Rim
  canvas.drawCircle(
    Offset(cx, cy),
    r - 0.5,
    Paint()
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        white
            ? [
                const Color(0xFFE8D4B0),
                const Color(0xFFC9A227),
                const Color(0xFF8B7355),
                const Color(0xFFE8D4B0),
              ]
            : [
                const Color(0xFF666666),
                const Color(0xFFAAAAAA),
                const Color(0xFF333333),
                const Color(0xFF666666),
              ],
        [0.0, 0.25, 0.6, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.08),
  );

  // Specular highlight
  canvas.drawCircle(
    Offset(cx - r * 0.28, cy - r * 0.32),
    r * 0.32,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - r * 0.28, cy - r * 0.32),
        r * 0.32,
        [
          Colors.white.withValues(alpha: white ? 0.75 : 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
      ),
  );
}

/// Checker on its edge — for the bear-off collection tray (vertical stack).
void paintCheckerVertical(
  Canvas canvas,
  double cx,
  double cy,
  double r,
  bool white, {
  double depth = 1.0,
}) {
  final w = r * 0.95 * depth;
  final h = r * 0.78 * depth;
  final rect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
    Radius.circular(w * 0.48),
  );

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(cx + 1, cy + h * 0.42),
      width: w * 1.15,
      height: h * 0.22,
    ),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  final sideDark = white ? const Color(0xFFC4B5A4) : const Color(0xFF151515);
  final sideLight = white ? const Color(0xFFFFF8F0) : const Color(0xFF4A4A4A);

  canvas.drawRRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - w * 0.5, cy),
        Offset(cx + w * 0.5, cy),
        [sideLight, sideDark, sideLight],
        [0.0, 0.55, 1.0],
      ),
  );

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(cx, cy - h * 0.38),
      width: w * 1.05,
      height: h * 0.28,
    ),
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy - h * 0.38),
        w * 0.55,
        [
          Colors.white.withValues(alpha: white ? 0.85 : 0.25),
          Colors.transparent,
        ],
      ),
  );

  canvas.drawRRect(
    rect,
    Paint()
      ..color = (white ? const Color(0xFFC9A227) : const Color(0xFF666666))
          .withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.07),
  );
}

/// Stacked checkers in the bear-off tray (face-up discs, spread to fill the slot).
void paintVerticalCheckerStack(
  Canvas canvas, {
  required BearOffTrayLayout layout,
  required PlayerColor color,
  required int count,
  int? maxVisible,
}) {
  if (count <= 0) return;
  final cap = maxVisible ?? BearOffTrayLayout.maxVisibleStack;
  final shown = math.min(count, cap);
  final r = layout.checkerRadius;
  final step = layout.stackStepFor(color, shown);
  final isWhite = color == PlayerColor.white;
  for (int i = 0; i < shown; i++) {
    final stackIdx = count - shown + i;
    final center = layout.checkerCenter(
      color,
      stackIdx,
      visibleCount: shown,
      step: step,
    );
    paintChecker(canvas, center.dx, center.dy, r * 0.92, isWhite);
  }
  if (count > cap) {
    final tray = layout.trayFor(color);
    final badgeY = color == PlayerColor.white ? tray.bottom - 6 : tray.top + 6;
    final tp = TextPainter(
      text: TextSpan(
        text: '+$count',
        style: TextStyle(
          color: color == PlayerColor.white
              ? const Color(0xFF5D4037)
              : Colors.white70,
          fontSize: r * 0.95,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(tray.center.dx - tp.width / 2, badgeY - tp.height / 2),
    );
  }
}

class FlyingCheckerPainter extends CustomPainter {
  const FlyingCheckerPainter({
    required this.isWhite,
    this.elevated = false,
    this.selectionRing = false,
  });

  final bool isWhite;
  final bool elevated;
  final bool selectionRing;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    if (elevated) {
      canvas.drawCircle(
        Offset(r + 4, r + 6),
        r + 4,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    paintChecker(canvas, r, r, r, isWhite);
    if (selectionRing) {
      canvas.drawCircle(
        Offset(r, r),
        r + 2,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(FlyingCheckerPainter old) =>
      old.isWhite != isWhite ||
      old.elevated != elevated ||
      old.selectionRing != selectionRing;
}
