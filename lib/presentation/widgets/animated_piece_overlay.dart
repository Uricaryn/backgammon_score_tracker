import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';

const int _kCols = 14;

(int col, bool top) _ptLayout(int pt) {
  if (pt >= 12 && pt <= 17) return (pt - 12, true);
  if (pt >= 18 && pt <= 23) return (pt - 11, true);
  if (pt >= 6 && pt <= 11) return (11 - pt, false);
  return (12 - pt, false);
}

class AnimatedPieceOverlay extends StatefulWidget {
  const AnimatedPieceOverlay({
    super.key,
    required this.state,
    required this.myColor,
    required this.boardSize,
  });

  final GameState state;
  final PlayerColor myColor;
  final Size boardSize;

  @override
  State<AnimatedPieceOverlay> createState() => _AnimatedPieceOverlayState();
}

class _AnimatedPieceOverlayState extends State<AnimatedPieceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  int _lastVersion = -1;
  Offset? _fromPos;
  Offset? _toPos;
  bool _animWhite = true;
  bool _isBearOff = false;

  bool get _isReversed => widget.myColor == PlayerColor.black;
  int _modelToView(int pt) => _isReversed ? 23 - pt : pt;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _lastVersion = widget.state.version;
  }

  @override
  void didUpdateWidget(AnimatedPieceOverlay old) {
    super.didUpdateWidget(old);
    final gs = widget.state;
    if (gs.version != _lastVersion && gs.lastMovePlayer != null) {
      _lastVersion = gs.version;
      _startMoveAnimation(gs);
    }
  }

  void _startMoveAnimation(GameState gs) {
    final s = widget.boardSize;
    if (s == Size.zero) return;

    final pw = s.width / _kCols;
    final r = pw * 0.41;

    _animWhite = gs.lastMovePlayer == PlayerColor.white;
    _isBearOff = gs.lastMoveBearOff;

    // Compute source position — piece has already left, so use base of that stack
    if (gs.lastMoveFrom == null) {
      // From bar
      _fromPos = Offset(
        6.5 * pw,
        _animWhite ? s.height * 0.12 : s.height * 0.88,
      );
    } else {
      final (col, top) = _ptLayout(_modelToView(gs.lastMoveFrom!));
      final cx = (col + 0.5) * pw;
      // After the move, fromPoint has fewer pieces; compute where the moved piece WAS
      final fromCnt = gs.points[gs.lastMoveFrom!].abs();
      final step = top ? r * 1.85 : -r * 1.85;
      final y0 = top ? r + 6.0 : s.height - r - 6.0;
      final fromIndex = fromCnt.clamp(0, 4); // piece was one above current top
      final cy = y0 + step * fromIndex;
      _fromPos = Offset(cx, cy);
    }

    // Compute destination — this is where the piece WILL land (top of stack)
    if (gs.lastMoveBearOff || gs.lastMoveTo == null) {
      _toPos = Offset(13.5 * pw, s.height / 2);
    } else {
      final (col, top) = _ptLayout(_modelToView(gs.lastMoveTo!));
      final cx = (col + 0.5) * pw;
      // The piece is now at the top of the destination stack
      final destCnt = gs.points[gs.lastMoveTo!].abs();
      final step = top ? r * 1.85 : -r * 1.85;
      final y0 = top ? r + 6.0 : s.height - r - 6.0;
      final destIndex = (destCnt - 1).clamp(0, 4);
      final cy = y0 + step * destIndex;
      _toPos = Offset(cx, cy);
    }

    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fromPos == null || _toPos == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        if (!_ctrl.isAnimating && _ctrl.isCompleted) {
          return const SizedBox.shrink();
        }

        final t = _progress.value;
        final pos = Offset.lerp(_fromPos!, _toPos!, t)!;
        final pw = widget.boardSize.width / _kCols;
        final r = pw * 0.41;

        final scale = _isBearOff
            ? 1.0 - (t * 0.4)
            : 1.0 + (0.15 * (1.0 - (2 * t - 1).abs()));

        final opacity = _isBearOff ? (1.0 - t * 0.5) : 1.0;

        return Positioned(
          left: pos.dx - r,
          top: pos.dy - r,
          child: IgnorePointer(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: CustomPaint(
                  size: Size(r * 2, r * 2),
                  painter: _FlyingPiecePainter(isWhite: _animWhite),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlyingPiecePainter extends CustomPainter {
  final bool isWhite;

  const _FlyingPiecePainter({required this.isWhite});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final cx = r;
    final cy = r;

    // Shadow
    canvas.drawCircle(
      Offset(cx + 3, cy + 4),
      r + 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Body
    final bodyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - r * 0.25, cy - r * 0.25),
        r * 1.4,
        isWhite
            ? [Colors.white, const Color(0xFFE8E0D8), const Color(0xFFBBAAAA)]
            : [const Color(0xFF555555), const Color(0xFF2A2A2A), const Color(0xFF111111)],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), r, bodyPaint);

    // Ring
    final ringPaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        isWhite
            ? [const Color(0xFFC8A060), const Color(0xFFD4AF37), const Color(0xFF8B7355), const Color(0xFFC8A060)]
            : [const Color(0xFF888888), const Color(0xFFAAAAAA), const Color(0xFF666666), const Color(0xFF888888)],
        [0.0, 0.3, 0.7, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), r - 0.5, ringPaint);

    // Specular
    canvas.drawCircle(
      Offset(cx - r * 0.22, cy - r * 0.22),
      r * 0.28,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - r * 0.22, cy - r * 0.22),
          r * 0.28,
          [
            Colors.white.withValues(alpha: isWhite ? 0.7 : 0.25),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_FlyingPiecePainter old) => old.isWhite != isWhite;
}
