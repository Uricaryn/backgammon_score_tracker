import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';
import 'package:backgammon_score_tracker/presentation/widgets/animated_piece_overlay.dart';

// Sütun düzeni (14 birim toplamda):
//  0-5  → sol yarı (6 point)
//  6    → bar
//  7-12 → sağ yarı (6 point)
//  13   → bear-off bölgesi
const int _kCols = 14;

/// point index (0-23) → (display column 0-12, isTopRow)
(int col, bool top) _ptLayout(int pt) {
  if (pt >= 12 && pt <= 17) return (pt - 12, true);
  if (pt >= 18 && pt <= 23) return (pt - 11, true);
  if (pt >= 6 && pt <= 11) return (11 - pt, false);
  return (12 - pt, false); // 0-5
}

/// (display column, isTopRow) → point index
int _colPt(int col, bool top) =>
    top ? (col <= 5 ? 12 + col : 11 + col) : (col <= 5 ? 11 - col : 12 - col);

/// Gerçek tavla tahtası: CustomPainter ile çizilen, tıkla-seç-hamle akışlı widget.
class InteractiveBackgammonBoard extends StatefulWidget {
  const InteractiveBackgammonBoard({
    super.key,
    required this.state,
    required this.legalMoves,
    required this.onMoveSelected,
    required this.myColor,
    this.interactive = true,
  });

  final GameState state;
  final List<Move> legalMoves;
  final ValueChanged<Move> onMoveSelected;

  /// Ekrandaki kullanıcının rengi (beyaz veya siyah).
  final PlayerColor myColor;
  final bool interactive;

  @override
  State<InteractiveBackgammonBoard> createState() =>
      _InteractiveBackgammonBoardState();
}

class _InteractiveBackgammonBoardState
    extends State<InteractiveBackgammonBoard> {
  int? _sel;
  bool _barSel = false;
  int? _dragFromPoint;
  bool _dragFromBar = false;
  Offset? _dragLocalPos;

  // Animation: hide destination piece while overlay flies it there
  int? _hideAtPoint;

  Size _bs = Size.zero;
  double get _pw => _bs.width / _kCols;
  bool get _isReversed => widget.myColor == PlayerColor.black;

  int _viewPointToModel(int viewPoint) =>
      _isReversed ? 23 - viewPoint : viewPoint;

  @override
  void didUpdateWidget(InteractiveBackgammonBoard old) {
    super.didUpdateWidget(old);
    if (old.state.version != widget.state.version) {
      final gs = widget.state;

      // If there's a last move, hide the destination piece during animation
      if (gs.lastMovePlayer != null && gs.lastMoveTo != null && !gs.lastMoveBearOff) {
        _hideAtPoint = gs.lastMoveTo;
        Future.delayed(const Duration(milliseconds: 320), () {
          if (!mounted) return;
          setState(() => _hideAtPoint = null);
        });
      }

      setState(() {
        _sel = null;
        _barSel = false;
        _dragFromPoint = null;
        _dragFromBar = false;
        _dragLocalPos = null;
      });
    }
  }

  bool get _myTurn =>
      widget.interactive &&
      widget.state.currentTurn == widget.myColor &&
      widget.state.status == GameStatus.active;

  List<Move> get _bearOffMoves =>
      widget.legalMoves.where((m) => m.bearOff).toList();

  Set<int> get _targets {
    if (_barSel) {
      return widget.legalMoves
          .where((m) => m.fromPoint == null && m.toPoint != null)
          .map((m) => m.toPoint!)
          .toSet();
    }
    if (_sel == null) return {};
    return widget.legalMoves
        .where((m) => m.fromPoint == _sel && m.toPoint != null)
        .map((m) => m.toPoint!)
        .toSet();
  }

  // ── Dokunma işleyicileri ───────────────────────────────────────────────────

  void _onTap(TapDownDetails d) {
    if (!_myTurn) return;
    final col =
        (d.localPosition.dx / _pw).floor().clamp(0, _kCols - 1);
    if (col == 6) {
      _tapBar();
    } else if (col == 13) {
      _tapBearOff();
    } else {
      final viewPoint = _colPt(col, d.localPosition.dy < _bs.height / 2);
      _tapPt(_viewPointToModel(viewPoint));
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (!_myTurn) return;
    final col = (d.localPosition.dx / _pw).floor().clamp(0, _kCols - 1);
    if (col == 6 && (widget.state.bar[widget.myColor] ?? 0) > 0) {
      if (!widget.legalMoves.any((m) => m.fromPoint == null)) return;
      setState(() {
        _dragFromBar = true;
        _dragFromPoint = null;
        _dragLocalPos = d.localPosition;
        _barSel = true;
        _sel = null;
      });
      return;
    }
    if (col == 13) return;

    final viewPoint = _colPt(col, d.localPosition.dy < _bs.height / 2);
    final modelPoint = _viewPointToModel(viewPoint);
    final val = widget.state.points[modelPoint];
    final own = widget.myColor == PlayerColor.white ? val > 0 : val < 0;
    final legal = widget.legalMoves.any((m) => m.fromPoint == modelPoint);
    if (!own || !legal) return;
    setState(() {
      _dragFromBar = false;
      _dragFromPoint = modelPoint;
      _dragLocalPos = d.localPosition;
      _sel = modelPoint;
      _barSel = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragFromPoint == null && !_dragFromBar) return;
    setState(() => _dragLocalPos = d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dragFromPoint == null && !_dragFromBar) return;
    _completeDrag(_dragLocalPos);
  }

  void _onPanCancel() {
    if (_dragFromPoint == null && !_dragFromBar) return;
    setState(() {
      _dragFromPoint = null;
      _dragFromBar = false;
      _dragLocalPos = null;
    });
  }

  void _completeDrag(Offset? localPos) {
    if (localPos == null) {
      _clearDragState();
      return;
    }

    final col = (localPos.dx / _pw).floor().clamp(0, _kCols - 1);
    if (col == 13) {
      if (_dragFromPoint != null) {
        final move = _bearOffMoves
            .where((m) => m.fromPoint == _dragFromPoint)
            .firstOrNull;
        if (move != null) {
          widget.onMoveSelected(move);
          HapticFeedback.selectionClick();
        }
      }
      _clearDragState();
      return;
    }

    if (col == 6) {
      _clearDragState();
      return;
    }

    final top = localPos.dy < _bs.height / 2;
    final viewPoint = _colPt(col, top);
    final target = _viewPointToModel(viewPoint);
    Move? move;
    if (_dragFromBar) {
      move = widget.legalMoves
          .where((m) => m.fromPoint == null && m.toPoint == target)
          .firstOrNull;
    } else if (_dragFromPoint != null) {
      move = widget.legalMoves
          .where((m) => m.fromPoint == _dragFromPoint && m.toPoint == target)
          .firstOrNull;
    }
    if (move != null) {
      widget.onMoveSelected(move);
      HapticFeedback.selectionClick();
    }
    _clearDragState();
  }

  void _clearDragState() {
    setState(() {
      _dragFromPoint = null;
      _dragFromBar = false;
      _dragLocalPos = null;
    });
  }

  void _tapBar() {
    final cnt = widget.state.bar[widget.myColor] ?? 0;
    if (cnt > 0 && widget.legalMoves.any((m) => m.fromPoint == null)) {
      setState(() {
        _barSel = true;
        _sel = null;
      });
    }
  }

  void _tapBearOff() {
    final moves = _bearOffMoves;
    if (moves.isEmpty) return;
    final m = (_sel != null
            ? moves.where((m) => m.fromPoint == _sel).firstOrNull
            : null) ??
        moves.first;
    widget.onMoveSelected(m);
    setState(() {
      _sel = null;
      _barSel = false;
    });
  }

  void _tapPt(int pt) {
    final bar = widget.state.bar[widget.myColor] ?? 0;

    // Bar'da taş varken sadece bar çıkışına izin ver
    if (bar > 0) {
      if (_barSel) {
        final m = widget.legalMoves
            .where((m) => m.fromPoint == null && m.toPoint == pt)
            .firstOrNull;
        if (m != null) {
          widget.onMoveSelected(m);
          setState(() => _barSel = false);
        }
      } else {
        if (widget.legalMoves.any((m) => m.fromPoint == null)) {
          setState(() => _barSel = true);
        }
      }
      return;
    }

    // İkinci tıklamada hamle dene
    if (_sel != null) {
      final m = widget.legalMoves
          .where((m) => m.fromPoint == _sel && m.toPoint == pt)
          .firstOrNull;
      if (m != null) {
        widget.onMoveSelected(m);
        setState(() => _sel = null);
        return;
      }
    }

    // Yeni seçim
    final val = widget.state.points[pt];
    final own = widget.myColor == PlayerColor.white ? val > 0 : val < 0;
    final legal = widget.legalMoves.any((m) => m.fromPoint == pt);
    setState(() => _sel = own && legal ? pt : null);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final maxW = c.maxWidth;
      final availH = c.maxHeight.isFinite ? c.maxHeight : maxW * 0.75;
      // Fill available height while maintaining 4:3 (w:h = 1/0.75) aspect ratio.
      // Constrained by whichever dimension is tighter.
      final wFromH = availH / 0.75;
      final w = min(maxW, wFromH);
      final h = w * 0.75;
      _bs = Size(w, h);
      final pw = w / _kCols;
      final pieceR = pw * 0.41;

      return GestureDetector(
        onTapDown: _onTap,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: w,
              height: h,
              child: CustomPaint(
                painter: _BoardPainter(
                  state: widget.state,
                  sel: _sel,
                  barSel: _barSel,
                  targets: _targets,
                  bearOffMoves: _bearOffMoves,
                  myColor: widget.myColor,
                  myTurn: _myTurn,
                  ctx: context,
                  hideAtPoint: _hideAtPoint,
                ),
              ),
            ),
            // Piece movement animation overlay
            AnimatedPieceOverlay(
              state: widget.state,
              myColor: widget.myColor,
              boardSize: _bs,
            ),
            // Drag ghost piece
            if (_dragLocalPos != null && (_dragFromPoint != null || _dragFromBar))
              Positioned(
                left: _dragLocalPos!.dx - pieceR,
                top: _dragLocalPos!.dy - pieceR,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size(pieceR * 2, pieceR * 2),
                    painter: _DragGhostPainter(
                      isWhite: widget.myColor == PlayerColor.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _DragGhostPainter extends CustomPainter {
  final bool isWhite;
  const _DragGhostPainter({required this.isWhite});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final cx = r;
    final cy = r;

    // Large elevated shadow
    canvas.drawCircle(
      Offset(cx + 3, cy + 5),
      r + 3,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Body
    final bodyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - r * 0.25, cy - r * 0.25),
        r * 1.4,
        isWhite
            ? [Colors.white.withValues(alpha: 0.85), const Color(0xFFE8E0D8).withValues(alpha: 0.85), const Color(0xFFBBAAAA).withValues(alpha: 0.85)]
            : [const Color(0xFF555555).withValues(alpha: 0.85), const Color(0xFF2A2A2A).withValues(alpha: 0.85), const Color(0xFF111111).withValues(alpha: 0.85)],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), r, bodyPaint);

    // Amber selection ring
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Specular
    canvas.drawCircle(
      Offset(cx - r * 0.22, cy - r * 0.22),
      r * 0.28,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - r * 0.22, cy - r * 0.22),
          r * 0.28,
          [
            Colors.white.withValues(alpha: isWhite ? 0.6 : 0.2),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_DragGhostPainter old) => old.isWhite != isWhite;
}

// ── CustomPainter ──────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final GameState state;
  final int? sel;
  final bool barSel;
  final Set<int> targets;
  final List<Move> bearOffMoves;
  final PlayerColor myColor;
  final bool myTurn;
  final BuildContext ctx;
  final int? hideAtPoint;
  bool get _isReversed => myColor == PlayerColor.black;

  const _BoardPainter({
    required this.state,
    required this.sel,
    required this.barSel,
    required this.targets,
    required this.bearOffMoves,
    required this.myColor,
    required this.myTurn,
    required this.ctx,
    this.hideAtPoint,
  });

  double _pw(Size s) => s.width / _kCols;
  double _cx(int col, Size s) => (col + 0.5) * _pw(s);
  int _modelPointToView(int point) => _isReversed ? 23 - point : point;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    _drawPlayingSurface(canvas, size);
    _drawTriangles(canvas, size);
    _drawBarArea(canvas, size);
    _drawBearOffArea(canvas, size);
    _drawFrame(canvas, size);
    _drawPieces(canvas, size);
    _drawBarPieces(canvas, size);
    _drawHighlights(canvas, size);
  }

  // ── Premium wood-grain background ──────────────────────────────────────

  void _drawBg(Canvas canvas, Size size) {
    final frameOuter = AppTheme.getBoardFrameOuter(ctx);
    final frameInner = AppTheme.getBoardFrameInner(ctx);

    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(10),
    );
    final framePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [frameOuter, frameInner.withValues(alpha: 0.7), frameOuter],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(outerRect, framePaint);
  }

  void _drawPlayingSurface(Canvas canvas, Size size) {
    final pw = _pw(size);
    const inset = 4.0;
    final woodBase = AppTheme.getBoardLightColor(ctx);
    final woodGrain = AppTheme.getBoardWoodGrain(ctx);

    final surfaceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      const Radius.circular(6),
    );

    final surfacePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, inset),
        Offset(0, size.height - inset),
        [woodBase, woodGrain, woodBase],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(surfaceRect, surfacePaint);

    // Subtle wood grain lines
    final grainPaint = Paint()
      ..color = woodGrain.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;
    for (double y = inset + 8; y < size.height - inset; y += pw * 0.6) {
      canvas.drawLine(
        Offset(inset, y),
        Offset(size.width - inset, y + 2),
        grainPaint,
      );
    }
  }

  // ── Gradient triangles ────────────────────────────────────────────────────

  void _drawTriangles(Canvas canvas, Size size) {
    final pw = _pw(size);
    final th = size.height * 0.44;
    final triDark = AppTheme.getBoardTriangleDark(ctx);
    final triLight = AppTheme.getBoardTriangleLight(ctx);

    for (int col = 0; col < 13; col++) {
      if (col == 6) continue;
      final x = col * pw;
      final isEven = col % 2 == 0;
      final baseColor = isEven ? triDark : triLight;
      final tipColor = isEven
          ? triDark.withValues(alpha: 0.5)
          : triLight.withValues(alpha: 0.6);

      // Top triangle
      final topPath = Path()
        ..moveTo(x + 1, 4)
        ..lineTo(x + pw - 1, 4)
        ..lineTo(x + pw / 2, th)
        ..close();

      final topGrad = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x + pw / 2, 4),
          Offset(x + pw / 2, th),
          [baseColor, tipColor],
        );
      canvas.drawPath(topPath, topGrad);
      canvas.drawPath(
        topPath,
        Paint()
          ..color = baseColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Bottom triangle
      final botPath = Path()
        ..moveTo(x + 1, size.height - 4)
        ..lineTo(x + pw - 1, size.height - 4)
        ..lineTo(x + pw / 2, size.height - th)
        ..close();

      final botGrad = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x + pw / 2, size.height - 4),
          Offset(x + pw / 2, size.height - th),
          [baseColor, tipColor],
        );
      canvas.drawPath(botPath, botGrad);
      canvas.drawPath(
        botPath,
        Paint()
          ..color = baseColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  // ── Bar area with wood strip ──────────────────────────────────────────────

  void _drawBarArea(Canvas canvas, Size size) {
    final pw = _pw(size);
    final barRect = Rect.fromLTWH(6 * pw, 0, pw, size.height);
    final frameOuter = AppTheme.getBoardFrameOuter(ctx);
    final frameInner = AppTheme.getBoardFrameInner(ctx);

    final barPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(6 * pw, 0),
        Offset(7 * pw, 0),
        [frameOuter.withValues(alpha: 0.9), frameInner.withValues(alpha: 0.6), frameOuter.withValues(alpha: 0.9)],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(barRect, barPaint);

    // Subtle center line
    canvas.drawLine(
      Offset(6.5 * pw, 4),
      Offset(6.5 * pw, size.height - 4),
      Paint()
        ..color = frameInner.withValues(alpha: 0.25)
        ..strokeWidth = 0.5,
    );
  }

  // ── Bear-off area ────────────────────────────────────────────────────────

  void _drawBearOffArea(Canvas canvas, Size size) {
    final pw = _pw(size);
    final x = 13 * pw;
    final selBear = sel != null && bearOffMoves.any((m) => m.fromPoint == sel);
    final active = bearOffMoves.isNotEmpty && myTurn;

    final bgColor = selBear
        ? Colors.green.withValues(alpha: 0.2)
        : active
            ? Colors.amber.withValues(alpha: 0.1)
            : AppTheme.getBoardFrameInner(ctx).withValues(alpha: 0.15);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + 2, 4, pw - 4, size.height - 8),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, Paint()..color = bgColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppTheme.getBoardFrameOuter(ctx).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _text(
      canvas,
      x + pw / 2,
      size.height / 2,
      'OFF',
      TextStyle(
        color: selBear
            ? Colors.green
            : AppTheme.getBoardBorderColor(ctx).withValues(alpha: 0.6),
        fontSize: pw * 0.26,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );

    final r = pw * 0.30;
    final wOff = state.borneOff[PlayerColor.white] ?? 0;
    final bOff = state.borneOff[PlayerColor.black] ?? 0;
    if (wOff > 0) {
      _piece2D(canvas, x + pw / 2, size.height * 0.16, r, true);
      _text(canvas, x + pw / 2, size.height * 0.16 + r + 6, '$wOff',
        TextStyle(color: Colors.brown[700], fontSize: pw * 0.24, fontWeight: FontWeight.bold));
    }
    if (bOff > 0) {
      _piece2D(canvas, x + pw / 2, size.height * 0.84, r, false);
      _text(canvas, x + pw / 2, size.height * 0.84 + r + 6, '$bOff',
        TextStyle(color: Colors.white70, fontSize: pw * 0.24, fontWeight: FontWeight.bold));
    }
  }

  // ── Double-layer frame ────────────────────────────────────────────────────

  void _drawFrame(Canvas canvas, Size size) {
    final outerColor = AppTheme.getBoardFrameOuter(ctx);
    final innerColor = AppTheme.getBoardFrameInner(ctx);

    // Outer frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      Paint()
        ..color = outerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Inner frame highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        const Radius.circular(8),
      ),
      Paint()
        ..color = innerColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  // ── 3D Checkers ───────────────────────────────────────────────────────────

  void _drawPieces(Canvas canvas, Size size) {
    final pw = _pw(size);
    final r = pw * 0.41;
    for (int pt = 0; pt < 24; pt++) {
      var cnt = state.points[pt];
      if (cnt == 0) continue;
      // During animation, hide the top piece at destination so overlay can fly it
      if (hideAtPoint != null && pt == hideAtPoint && cnt.abs() > 0) {
        final sign = cnt > 0 ? 1 : -1;
        cnt = cnt - sign;
        if (cnt == 0) continue;
      }
      final (col, top) = _ptLayout(_modelPointToView(pt));
      _drawStack(canvas, _cx(col, size), top, cnt.abs(), cnt > 0, r, size);
    }
  }

  void _drawStack(
    Canvas canvas, double cx, bool top, int cnt, bool white, double r, Size size,
  ) {
    const maxVisible = 5;
    final shown = min(cnt, maxVisible);
    final step = top ? r * 1.85 : -r * 1.85;
    final y0 = top ? r + 6.0 : size.height - r - 6.0;

    for (int i = 0; i < shown; i++) {
      _piece(canvas, cx, y0 + step * i, r, white);
    }

    if (cnt > maxVisible) {
      _text(canvas, cx, y0 + step * (shown - 1), '+$cnt',
        TextStyle(
          color: white ? Colors.black87 : Colors.white70,
          fontSize: r * 0.72,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
        ));
    }
  }

  void _piece(Canvas canvas, double cx, double cy, double r, bool white) {
    // Drop shadow
    canvas.drawCircle(
      Offset(cx + 2, cy + 3),
      r + 1,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Main body with radial gradient
    final bodyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - r * 0.25, cy - r * 0.25),
        r * 1.4,
        white
            ? [Colors.white, const Color(0xFFE8E0D8), const Color(0xFFBBAAAA)]
            : [const Color(0xFF555555), const Color(0xFF2A2A2A), const Color(0xFF111111)],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), r, bodyPaint);

    // Ring border with gradient
    final ringPaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        white
            ? [const Color(0xFFC8A060), const Color(0xFFD4AF37), const Color(0xFF8B7355), const Color(0xFFC8A060)]
            : [const Color(0xFF888888), const Color(0xFFAAAAAA), const Color(0xFF666666), const Color(0xFF888888)],
        [0.0, 0.3, 0.7, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(Offset(cx, cy), r - 0.5, ringPaint);

    // Inner decorative ring
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.72,
      Paint()
        ..color = (white ? const Color(0xFFD4AF37) : const Color(0xFF777777)).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    // Specular highlight
    canvas.drawCircle(
      Offset(cx - r * 0.22, cy - r * 0.22),
      r * 0.28,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - r * 0.22, cy - r * 0.22),
          r * 0.28,
          [
            Colors.white.withValues(alpha: white ? 0.65 : 0.2),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  // ── Flat/2D checkers for bear-off area ───────────────────────────────────
  void _piece2D(Canvas canvas, double cx, double cy, double r, bool white) {
    final fill = white ? const Color(0xFFF2ECE4) : const Color(0xFF2B2B2B);
    final rim = white ? const Color(0xFFB49B84) : const Color(0xFF6C6C6C);
    final center = Offset(cx, cy);

    canvas.drawCircle(center, r, Paint()..color = fill);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ── Bar pieces ────────────────────────────────────────────────────────────

  void _drawBarPieces(Canvas canvas, Size size) {
    final pw = _pw(size);
    final cx = 6.5 * pw;
    final r = pw * 0.36;
    final spacing = r * 2.1 + 2;

    final wBar = state.bar[PlayerColor.white] ?? 0;
    final bBar = state.bar[PlayerColor.black] ?? 0;

    for (int i = 0; i < min(wBar, 4); i++) {
      _piece(canvas, cx, size.height * 0.12 + i * spacing, r, true);
    }
    if (wBar > 4) {
      _text(canvas, cx, size.height * 0.12 + 4 * spacing, '+$wBar',
        TextStyle(color: Colors.white70, fontSize: r * 0.72, fontWeight: FontWeight.bold));
    }

    for (int i = 0; i < min(bBar, 4); i++) {
      _piece(canvas, cx, size.height * 0.88 - i * spacing, r, false);
    }
    if (bBar > 4) {
      _text(canvas, cx, size.height * 0.88 - 4 * spacing, '+$bBar',
        TextStyle(color: Colors.black87, fontSize: r * 0.72, fontWeight: FontWeight.bold));
    }
  }

  // ── Highlights with glow ──────────────────────────────────────────────────

  void _drawHighlights(Canvas canvas, Size size) {
    final pw = _pw(size);
    final r = pw * 0.41;
    final th = size.height * 0.44;

    // Selected point — amber glow ring
    if (sel != null) {
      final (col, top) = _ptLayout(_modelPointToView(sel!));
      final cy = top ? r + 6 : size.height - r - 6;
      final center = Offset(_cx(col, size), cy);

      // Outer glow
      canvas.drawCircle(
        center, r + 8,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Ring
      canvas.drawCircle(
        center, r + 4,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Bar selected — amber glow
    if (barSel) {
      final cy = myColor == PlayerColor.white
          ? size.height * 0.12
          : size.height * 0.88;
      final center = Offset(6.5 * pw, cy);
      canvas.drawCircle(
        center, pw * 0.36 + 8,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        center, pw * 0.36 + 4,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Target points — green glow + tip dot
    for (final t in targets) {
      final (col, top) = _ptLayout(_modelPointToView(t));
      final cx = _cx(col, size);
      final tipY = top ? th : size.height - th;
      final startY = top ? r + 6 : size.height - r - 6;

      // Tip glow dot
      canvas.drawCircle(
        Offset(cx, tipY), pw * 0.15,
        Paint()
          ..color = const Color(0xFF4CAF50).withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(cx, tipY), pw * 0.10,
        Paint()..color = const Color(0xFF4CAF50),
      );

      // Ring glow at base
      canvas.drawCircle(
        Offset(cx, startY), r + 6,
        Paint()
          ..color = const Color(0xFF4CAF50).withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(cx, startY), r + 3,
        Paint()
          ..color = const Color(0xFF4CAF50).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Bear-off highlight
    if (bearOffMoves.isNotEmpty && myTurn) {
      final selBear = sel != null && bearOffMoves.any((m) => m.fromPoint == sel);
      if (selBear) {
        final x = 13 * pw;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 2, 4, pw - 4, size.height - 8),
            const Radius.circular(8),
          ),
          Paint()
            ..color = const Color(0xFF4CAF50).withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  // ── Text helper ───────────────────────────────────────────────────────────

  void _text(Canvas canvas, double cx, double cy, String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
