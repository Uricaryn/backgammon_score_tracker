import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_die_face.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_motion.dart';

/// Dice thrown onto the board (rolling player's half), not in the control strip.
class BoardThrownDiceOverlay extends StatefulWidget {
  const BoardThrownDiceOverlay({
    super.key,
    required this.boardSize,
    required this.targetValues,
    required this.isRolling,
    required this.rollingPlayer,
    required this.viewerColor,
  });

  final Size boardSize;
  final List<int> targetValues;
  final bool isRolling;
  final PlayerColor rollingPlayer;
  /// Local player color — their dice rest on the right, opponent's on the left.
  final PlayerColor viewerColor;

  @override
  State<BoardThrownDiceOverlay> createState() => _BoardThrownDiceOverlayState();
}

class _BoardThrownDiceOverlayState extends State<BoardThrownDiceOverlay>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 1050;
  static const _throwEnd = 0.33;
  static const _rollEnd = 0.86;

  late AnimationController _ctrl;
  final _rng = math.Random();
  List<int> _flashFaces = [];
  List<Offset> _origins = [];
  List<Offset> _targets = [];
  int _lastCyclePhase = -1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );
    _ctrl.addListener(_faceCycleListener);
    _syncLayout();
    if (widget.isRolling) {
      _startAnim();
    }
  }

  @override
  void didUpdateWidget(BoardThrownDiceOverlay old) {
    super.didUpdateWidget(old);
    _syncLayout();
    if (widget.isRolling && !old.isRolling) {
      _startAnim();
    } else if (!widget.isRolling && old.isRolling) {
      _ctrl.value = 1.0;
      _flashFaces = boardDiceFaceValues(widget.targetValues);
    } else if (!widget.isRolling) {
      _flashFaces = boardDiceFaceValues(widget.targetValues);
    }
  }

  void _syncLayout() {
    final n = boardPhysicalDieCount(widget.targetValues);
    _origins = boardDiceThrowOrigins(
      widget.boardSize,
      widget.rollingPlayer,
      widget.viewerColor,
      n,
    );
    _targets = boardDiceRestPositions(
      widget.boardSize,
      widget.rollingPlayer,
      widget.viewerColor,
      n,
    );
    if (!widget.isRolling) {
      _flashFaces = boardDiceFaceValues(widget.targetValues);
    }
  }

  void _startAnim() {
    _lastCyclePhase = -1;
    if (!boardAnimationsEnabled(context)) {
      _ctrl.value = 1.0;
      _flashFaces = boardDiceFaceValues(widget.targetValues);
      return;
    }
    _flashFaces = List.generate(
      _origins.length,
      (_) => _rng.nextInt(6) + 1,
    );
    _ctrl
      ..stop()
      ..value = 0
      ..forward(from: 0);
  }

  void _faceCycleListener() {
    if (!widget.isRolling || !_ctrl.isAnimating) return;
    final t = _ctrl.value;
    if (t > _throwEnd && t < _rollEnd) {
      final phase = (t * 20).floor();
      if (phase != _lastCyclePhase) {
        _lastCyclePhase = phase;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _flashFaces = List.generate(
              _origins.length,
              (_) => _rng.nextInt(6) + 1,
            );
          });
        });
      }
    }
    if (t >= _rollEnd && _flashFaces.length == _origins.length) {
      final finalFaces = boardDiceFaceValues(widget.targetValues);
      if (_flashFaces != finalFaces) {
        setState(() => _flashFaces = finalFaces);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_faceCycleListener);
    _ctrl.dispose();
    super.dispose();
  }

  Offset _positionAt(int i, double t) {
    if (_origins.isEmpty || i >= _origins.length) return Offset.zero;
    final from = _origins[i];
    final to = _targets[i];
    if (t <= _throwEnd) {
      final u = t / _throwEnd;
      return boardArcPosition(from, to, u, widget.boardSize);
    }
    if (t <= _rollEnd) {
      final u = (t - _throwEnd) / (_rollEnd - _throwEnd);
      final wobbleX = math.sin(u * math.pi * 6) * widget.boardSize.width * 0.012;
      final wobbleY = math.cos(u * math.pi * 5) * widget.boardSize.height * 0.008;
      return Offset(to.dx + wobbleX, to.dy + wobbleY);
    }
    final u = ((t - _rollEnd) / (1.0 - _rollEnd)).clamp(0.0, 1.0);
    final bounce = math.sin(u * math.pi) * widget.boardSize.height * 0.012;
    return Offset(to.dx, to.dy - bounce);
  }

  double _rotationAt(double t) {
    if (t <= _throwEnd) {
      return (t / _throwEnd) * math.pi * 4;
    }
    if (t <= _rollEnd) {
      final u = (t - _throwEnd) / (_rollEnd - _throwEnd);
      return math.pi * 4 + u * math.pi * 8;
    }
    return 0;
  }

  double _scaleAt(double t) {
    if (t <= _rollEnd) return 1.0;
    final u = ((t - _rollEnd) / (1.0 - _rollEnd)).clamp(0.0, 1.0);
    return 1.0 - u * 0.06;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.boardSize == Size.zero) return const SizedBox.shrink();
    final n = boardPhysicalDieCount(widget.targetValues);
    if (n == 0 && !widget.isRolling) return const SizedBox.shrink();

    final dieSize = boardDiceSize(widget.boardSize);
    final faces = widget.isRolling
        ? (_flashFaces.isNotEmpty
            ? _flashFaces
            : boardDiceFaceValues(widget.targetValues))
        : boardDiceFaceValues(widget.targetValues);

    return IgnorePointer(
      child: SizedBox(
        width: widget.boardSize.width,
        height: widget.boardSize.height,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final progress = widget.isRolling ? _ctrl.value : 1.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < n && i < faces.length; i++)
                  _DieOnBoard(
                    center: _positionAt(i, progress),
                    size: dieSize * _scaleAt(progress),
                    rotation: _rotationAt(progress),
                    value: faces[i],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DieOnBoard extends StatelessWidget {
  const _DieOnBoard({
    required this.center,
    required this.size,
    required this.rotation,
    required this.value,
  });

  final Offset center;
  final double size;
  final double rotation;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: Transform.rotate(
        angle: rotation,
        child: BoardDieFace(
          value: value,
          size: size,
          shadowOpacity: 0.55,
        ),
      ),
    );
  }
}
