import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_motion.dart';

/// Hit bursts and win confetti over the board ([confetti] package).
class BoardEffectsOverlay extends StatefulWidget {
  const BoardEffectsOverlay({
    super.key,
    required this.state,
    required this.myColor,
    required this.boardSize,
  });

  final GameState state;
  final PlayerColor myColor;
  final Size boardSize;

  @override
  State<BoardEffectsOverlay> createState() => _BoardEffectsOverlayState();
}

class _BoardEffectsOverlayState extends State<BoardEffectsOverlay>
    with TickerProviderStateMixin {
  int _lastVersion = -1;
  AnimationController? _hitCtrl;
  late ConfettiController _confettiController;
  Offset? _hitCenter;
  bool _showWin = false;

  @override
  void initState() {
    super.initState();
    _lastVersion = widget.state.version;
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    if (widget.state.status == GameStatus.finished) {
      _showWin = true;
    }
  }

  @override
  void didUpdateWidget(BoardEffectsOverlay old) {
    super.didUpdateWidget(old);
    final gs = widget.state;
    final animOn = boardAnimationsEnabled(context);

    if (gs.status == GameStatus.finished &&
        old.state.status != GameStatus.finished) {
      setState(() => _showWin = true);
      if (animOn) {
        _confettiController.play();
      }
    }

    if (gs.version != _lastVersion) {
      _lastVersion = gs.version;
      if (gs.lastMoveHit &&
          gs.lastMoveTo != null &&
          animOn &&
          gs.lastMovePlayer != null) {
        _triggerHit(gs.lastMoveTo!);
      }
    }
  }

  void _triggerHit(int modelPoint) {
    final viewPt = boardModelToView(modelPoint, widget.myColor);
    final (col, top) = boardPointLayout(viewPt);
    final r = boardPieceRadius(widget.boardSize);
    final cx = boardColumnCenterX(col, widget.boardSize);
    final step = top ? r * 1.85 : -r * 1.85;
    final y0 = top ? r + 6.0 : widget.boardSize.height - r - 6.0;
    final destIndex = boardDestStackIndex(widget.state, modelPoint);
    final cy = y0 + step * destIndex;

    HapticFeedback.mediumImpact();
    _hitCtrl?.dispose();
    _hitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    setState(() => _hitCenter = Offset(cx, cy));
    _hitCtrl!.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _hitCenter = null);
      }
    });
  }

  @override
  void dispose() {
    _hitCtrl?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.boardSize == Size.zero) return const SizedBox.shrink();

    final children = <Widget>[];

    if (_hitCenter != null && _hitCtrl != null) {
      final r = boardPieceRadius(widget.boardSize) * 2.8;
      children.add(
        Positioned(
          left: _hitCenter!.dx - r / 2,
          top: _hitCenter!.dy - r / 2,
          width: r,
          height: r,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _hitCtrl!,
              builder: (context, _) {
                return CustomPaint(
                  painter: _HitBurstPainter(
                    center: Offset(r / 2, r / 2),
                    t: _hitCtrl!.value,
                    radius: boardPieceRadius(widget.boardSize),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    if (_showWin && widget.state.status == GameStatus.finished) {
      children.add(
        Positioned.fill(
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: true,
              emissionFrequency: 0.07,
              numberOfParticles: 28,
              maxBlastForce: 35,
              minBlastForce: 16,
              gravity: 0.14,
              colors: const [
                Color(0xFFFFD54F),
                Color(0xFF4CAF50),
                Color(0xFFE53935),
                Color(0xFF8E44AD),
                Color(0xFF29B6F6),
                Colors.white,
              ],
              canvas: widget.boardSize,
            ),
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Stack(children: children);
  }
}

class _HitBurstPainter extends CustomPainter {
  const _HitBurstPainter({
    required this.center,
    required this.t,
    required this.radius,
  });

  final Offset center;
  final double t;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final expand = radius + 10 + t * radius * 2.4;
    final alpha = (1.0 - t);
    canvas.drawCircle(
      center,
      expand,
      Paint()
        ..color = const Color(0xFFE53935).withValues(alpha: alpha * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      expand * 0.75,
      Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t * 0.4),
    );
    canvas.drawCircle(
      center,
      expand * 0.45,
      Paint()
        ..color = const Color(0xFFFF5252).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_HitBurstPainter old) =>
      old.t != t || old.center != center;
}
