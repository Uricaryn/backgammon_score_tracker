import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_motion.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/checker_painter.dart';

/// Pulse + borne-off intake animations on the collection trays.
class BearOffTrayOverlay extends StatefulWidget {
  const BearOffTrayOverlay({
    super.key,
    required this.state,
    required this.boardSize,
    required this.bearOffMoves,
    required this.myTurn,
    required this.myColor,
  });

  final GameState state;
  final Size boardSize;
  final List<Move> bearOffMoves;
  final bool myTurn;
  final PlayerColor myColor;

  @override
  State<BearOffTrayOverlay> createState() => _BearOffTrayOverlayState();
}

class _BearOffTrayOverlayState extends State<BearOffTrayOverlay>
    with TickerProviderStateMixin {
  int _lastVersion = -1;
  int _prevWhiteOff = 0;
  int _prevBlackOff = 0;

  late AnimationController _pulseCtrl;
  late AnimationController _intakeCtrl;
  late Animation<double> _intakeT;

  PlayerColor? _intakeColor;
  Offset? _intakeFrom;
  Offset? _intakeTo;

  @override
  void initState() {
    super.initState();
    _lastVersion = widget.state.version;
    _prevWhiteOff = widget.state.borneOff[PlayerColor.white] ?? 0;
    _prevBlackOff = widget.state.borneOff[PlayerColor.black] ?? 0;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _intakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _intakeT = CurvedAnimation(parent: _intakeCtrl, curve: Curves.easeOutCubic);
    _intakeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _intakeColor = null;
          _intakeFrom = null;
          _intakeTo = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(BearOffTrayOverlay old) {
    super.didUpdateWidget(old);
    final gs = widget.state;
    final active = widget.bearOffMoves.isNotEmpty && widget.myTurn;
    if (active && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!active && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }

    final wOff = gs.borneOff[PlayerColor.white] ?? 0;
    final bOff = gs.borneOff[PlayerColor.black] ?? 0;

    if (gs.version != _lastVersion && boardAnimationsEnabled(context)) {
      _lastVersion = gs.version;
      if (!gs.lastMoveBearOff) {
        if (wOff > _prevWhiteOff) {
          _startIntake(PlayerColor.white, wOff, gs);
        } else if (bOff > _prevBlackOff) {
          _startIntake(PlayerColor.black, bOff, gs);
        }
      }
    }
    _prevWhiteOff = wOff;
    _prevBlackOff = bOff;
  }

  void _startIntake(PlayerColor color, int newCount, GameState gs) {
    final layout = BearOffTrayLayout.fromBoardSize(widget.boardSize);
    _intakeTo = layout.nextSlotCenter(color, newCount);

    if (gs.lastMoveBearOff && gs.lastMoveFrom != null) {
      final idx = boardFromStackIndex(gs, gs.lastMoveFrom!);
      _intakeFrom = boardPieceCenter(
        boardSize: widget.boardSize,
        modelPoint: gs.lastMoveFrom!,
        myColor: widget.myColor,
        state: gs,
        stackIndexFromBase: idx,
      );
    } else {
      _intakeFrom = boardBearOffCenterForColor(widget.boardSize, color);
    }

    HapticFeedback.lightImpact();
    setState(() => _intakeColor = color);
    _intakeCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _intakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.boardSize == Size.zero) return const SizedBox.shrink();

    final layout = BearOffTrayLayout.fromBoardSize(widget.boardSize);
    final pulse = widget.bearOffMoves.isNotEmpty && widget.myTurn
        ? 0.35 + 0.25 * math.sin(_pulseCtrl.value * math.pi * 2)
        : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (pulse > 0)
          CustomPaint(
            size: widget.boardSize,
            painter: _TrayPulsePainter(
              layout: layout,
              strength: pulse,
            ),
          ),
        if (_intakeColor != null && _intakeFrom != null && _intakeTo != null)
          AnimatedBuilder(
            animation: _intakeT,
            builder: (context, _) {
              final t = _intakeT.value;
              final pos = Offset.lerp(_intakeFrom!, _intakeTo!, t)!;
              final lift = widget.boardSize.height * 0.06 * math.sin(t * math.pi);
              final cx = pos.dx;
              final cy = pos.dy - lift;
              final r = layout.checkerRadius;
              final morph = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
              final scaleX = 1.0 - morph * 0.55;
              final scaleY = 1.0 + morph * 0.2;

              return Positioned(
                left: cx - r,
                top: cy - r * 1.2,
                child: IgnorePointer(
                  child: Transform.scale(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    child: CustomPaint(
                      size: Size(r * 2.2, r * 2.6),
                      painter: _IntakeCheckerPainter(
                        isWhite: _intakeColor == PlayerColor.white,
                        verticalAmount: morph,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _TrayPulsePainter extends CustomPainter {
  _TrayPulsePainter({required this.layout, required this.strength});

  final BearOffTrayLayout layout;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    for (final tray in [layout.whiteTray, layout.blackTray]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(tray, const Radius.circular(8)),
        Paint()
          ..color = const Color(0xFF81C784).withValues(alpha: 0.15 + strength * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + strength,
      );
    }
  }

  @override
  bool shouldRepaint(_TrayPulsePainter old) => old.strength != strength;
}

class _IntakeCheckerPainter extends CustomPainter {
  _IntakeCheckerPainter({required this.isWhite, required this.verticalAmount});

  final bool isWhite;
  final double verticalAmount;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.45;
    if (verticalAmount > 0.5) {
      paintCheckerVertical(canvas, cx, cy, r, isWhite);
    } else {
      paintChecker(canvas, cx, cy, r * (1 - verticalAmount * 0.2), isWhite);
    }
  }

  @override
  bool shouldRepaint(_IntakeCheckerPainter old) =>
      old.isWhite != isWhite || old.verticalAmount != verticalAmount;
}
