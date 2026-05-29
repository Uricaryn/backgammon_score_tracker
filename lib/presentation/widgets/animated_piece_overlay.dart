import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_motion.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/checker_painter.dart';

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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kPieceMoveMs),
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
      if (boardAnimationsEnabled(context)) {
        _startMoveAnimation(gs);
      } else {
        setState(() {
          _fromPos = null;
          _toPos = null;
        });
      }
    }
  }

  void _startMoveAnimation(GameState gs) {
    final s = widget.boardSize;
    if (s == Size.zero) return;

    _animWhite = gs.lastMovePlayer == PlayerColor.white;
    _isBearOff = gs.lastMoveBearOff;

    if (gs.lastMoveFrom == null) {
      _fromPos = boardBarPieceCenter(s, _animWhite);
    } else {
      final idx = boardFromStackIndex(gs, gs.lastMoveFrom!);
      _fromPos = boardPieceCenter(
        boardSize: s,
        modelPoint: gs.lastMoveFrom!,
        myColor: widget.myColor,
        state: gs,
        stackIndexFromBase: idx,
      );
    }

    if (gs.lastMoveBearOff || gs.lastMoveTo == null) {
      final color = gs.lastMovePlayer ??
          (_animWhite ? PlayerColor.white : PlayerColor.black);
      final count = (gs.borneOff[color] ?? 0);
      if (count > 0) {
        final layout = BearOffTrayLayout.fromBoardSize(s);
        _toPos = layout.nextSlotCenter(color, count);
      } else {
        _toPos = boardBearOffCenterForColor(s, color);
      }
    } else {
      final idx = boardDestStackIndex(gs, gs.lastMoveTo!);
      _toPos = boardPieceCenter(
        boardSize: s,
        modelPoint: gs.lastMoveTo!,
        myColor: widget.myColor,
        state: gs,
        stackIndexFromBase: idx,
      );
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
        final pos = boardArcPosition(_fromPos!, _toPos!, t, widget.boardSize);
        final r = boardPieceRadius(widget.boardSize);

        final morph = _isBearOff ? ((t - 0.5) / 0.5).clamp(0.0, 1.0) : 0.0;
        final scale = _isBearOff
            ? 1.0 - morph * 0.35
            : 1.0 + (0.15 * (1.0 - (2 * t - 1).abs()));
        final scaleY = _isBearOff
            ? 1.0 + morph * 0.25
            : boardLandingScaleY(t);
        final opacity = _isBearOff ? (1.0 - t * 0.35) : 1.0;
        final w = r * 2.2;
        final h = _isBearOff ? r * 2.4 : r * 2;

        return Positioned(
          left: pos.dx - w / 2,
          top: pos.dy - h / 2,
          child: IgnorePointer(
            child: Transform.scale(
              scaleX: scale,
              scaleY: scaleY,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _FlyingBearOffPainter(
                    isWhite: _animWhite,
                    verticalMorph: morph,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlyingBearOffPainter extends CustomPainter {
  const _FlyingBearOffPainter({
    required this.isWhite,
    required this.verticalMorph,
  });

  final bool isWhite;
  final double verticalMorph;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;
    if (verticalMorph > 0.35) {
      paintCheckerVertical(canvas, cx, cy, r, isWhite);
    } else {
      paintChecker(canvas, cx, cy, r, isWhite);
    }
  }

  @override
  bool shouldRepaint(_FlyingBearOffPainter old) =>
      old.isWhite != isWhite || old.verticalMorph != verticalMorph;
}
