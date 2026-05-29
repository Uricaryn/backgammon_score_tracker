import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';
import 'package:backgammon_score_tracker/core/services/board_assets_service.dart';
import 'package:backgammon_score_tracker/presentation/widgets/animated_piece_overlay.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_effects_overlay.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_motion.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_ambience_overlay.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/checker_painter.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/bear_off_tray_overlay.dart';

/// Gerçek tavla tahtası: CustomPainter ile çizilen, tıkla-seç-hamle akışlı widget.
class InteractiveBackgammonBoard extends StatefulWidget {
  const InteractiveBackgammonBoard({
    super.key,
    required this.state,
    required this.legalMoves,
    required this.onMoveSelected,
    required this.myColor,
    this.interactive = true,
    this.fillHeight = false,
    this.boardTopOverlay,
    this.boardSize,
  });

  final GameState state;
  final List<Move> legalMoves;
  final ValueChanged<Move> onMoveSelected;

  /// Ekrandaki kullanıcının rengi (beyaz veya siyah).
  final PlayerColor myColor;
  final bool interactive;
  final bool fillHeight;

  /// @deprecated Dice belong in [LiveGameTable] strip, not on the board.
  final Widget? boardTopOverlay;

  /// When set, board uses this size (parent computes via [computeBoardSizeFit]).
  final Size? boardSize;

  @override
  State<InteractiveBackgammonBoard> createState() =>
      _InteractiveBackgammonBoardState();
}

class _InteractiveBackgammonBoardState extends State<InteractiveBackgammonBoard>
    with SingleTickerProviderStateMixin {
  int? _sel;
  bool _barSel = false;
  int? _dragFromPoint;
  bool _dragFromBar = false;
  Offset? _dragLocalPos;

  int? _hideAtPoint;
  int? _stackNudgePoint;
  late AnimationController _stackNudgeCtrl;
  late Animation<double> _stackNudgeAnim;

  Size _bs = Size.zero;
  double get _pw => boardPointWidth(_bs);

  int _viewPointToModel(int viewPoint) =>
      boardModelToView(viewPoint, widget.myColor);

  @override
  void initState() {
    super.initState();
    BoardAssetsService.instance.ensureLoaded();
    _stackNudgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _stackNudgeAnim = CurvedAnimation(
      parent: _stackNudgeCtrl,
      curve: Curves.easeOut,
    );
    _stackNudgeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _stackNudgePoint = null);
      }
    });
  }

  @override
  void dispose() {
    _stackNudgeCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(InteractiveBackgammonBoard old) {
    super.didUpdateWidget(old);
    if (old.state.version != widget.state.version) {
      final gs = widget.state;

      // If there's a last move, hide the destination piece during animation
      if (gs.lastMovePlayer != null &&
          gs.lastMoveTo != null &&
          !gs.lastMoveBearOff) {
        _hideAtPoint = gs.lastMoveTo;
        Future.delayed(const Duration(milliseconds: kPieceMoveMs), () {
          if (!mounted) return;
          setState(() => _hideAtPoint = null);
        });
        if (boardAnimationsEnabled(context)) {
          _stackNudgePoint = gs.lastMoveTo;
          _stackNudgeCtrl.forward(from: 0);
        }
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
        (d.localPosition.dx / _pw).floor().clamp(0, kBoardCols - 1);
    if (col == 6) {
      _tapBar();
    } else if (col == 13) {
      _tapBearOff();
    } else {
      final viewPoint =
          boardColToPoint(col, d.localPosition.dy < _bs.height / 2);
      _tapPt(_viewPointToModel(viewPoint));
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (!_myTurn) return;
    final col = (d.localPosition.dx / _pw).floor().clamp(0, kBoardCols - 1);
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

    final viewPoint = boardColToPoint(col, d.localPosition.dy < _bs.height / 2);
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

    final col = (localPos.dx / _pw).floor().clamp(0, kBoardCols - 1);
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
    final viewPoint = boardColToPoint(col, top);
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
    if (widget.boardSize != null) {
      return _buildBoardTree(widget.boardSize!);
    }
    return LayoutBuilder(builder: (ctx, c) {
      _bs = widget.fillHeight
          ? computeBoardSizeFit(c.maxWidth, c.maxHeight)
          : computeBoardSize(c.maxWidth, c.maxHeight);
      return _buildBoardTree(_bs);
    });
  }

  Widget _buildBoardTree(Size size) {
    _bs = size;
    final w = _bs.width;
    final h = _bs.height;
    final pieceR = boardPieceRadius(_bs);

    return RepaintBoundary(
        child: GestureDetector(
          onTapDown: _onTap,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: AnimatedBuilder(
            animation: _stackNudgeAnim,
            builder: (context, _) {
              final nudgePx = _stackNudgePoint != null
                  ? 4.0 * (1.0 - _stackNudgeAnim.value)
                  : 0.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
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
                        stackNudgePoint: _stackNudgePoint,
                        stackNudgeOffset: nudgePx,
                      ),
                    ),
                        const BoardAmbienceOverlay(),
                      ],
                    ),
                  ),
                  AnimatedPieceOverlay(
                    state: widget.state,
                    myColor: widget.myColor,
                    boardSize: _bs,
                  ),
                  BoardEffectsOverlay(
                    state: widget.state,
                    myColor: widget.myColor,
                    boardSize: _bs,
                  ),
                  BearOffTrayOverlay(
                    state: widget.state,
                    boardSize: _bs,
                    bearOffMoves: _bearOffMoves,
                    myTurn: _myTurn,
                    myColor: widget.myColor,
                  ),
                  if (widget.boardTopOverlay != null)
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: Center(child: widget.boardTopOverlay!),
                    ),
                  if (_dragLocalPos != null &&
                      (_dragFromPoint != null || _dragFromBar))
                    Positioned(
                      left: _dragLocalPos!.dx - pieceR,
                      top: _dragLocalPos!.dy - pieceR,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: Size(pieceR * 2, pieceR * 2),
                          painter: FlyingCheckerPainter(
                            isWhite: widget.myColor == PlayerColor.white,
                            elevated: true,
                            selectionRing: true,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
  }
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
  final int? stackNudgePoint;
  final double stackNudgeOffset;

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
    this.stackNudgePoint,
    this.stackNudgeOffset = 0,
  });

  double _pw(Size s) => boardPointWidth(s);
  double _cx(int col, Size s) => boardColumnCenterX(col, s);
  int _modelPointToView(int point) => boardModelToView(point, myColor);

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
    const inset = 5.0;
    final woodBase = AppTheme.getBoardLightColor(ctx);
    final woodGrain = AppTheme.getBoardWoodGrain(ctx);
    final woodDark = AppTheme.getBoardDarkColor(ctx);

    final surfaceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      surfaceRect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.width * 0.85,
          [woodBase, woodGrain, woodDark.withValues(alpha: 0.35)],
          [0.0, 0.55, 1.0],
        ),
    );

    final grainPaint = Paint()
      ..color = woodGrain.withValues(alpha: 0.22)
      ..strokeWidth = 0.6;
    for (double y = inset + 6; y < size.height - inset; y += pw * 0.45) {
      canvas.drawLine(
        Offset(inset + 2, y),
        Offset(size.width - inset - 2, y + 1.5),
        grainPaint,
      );
    }
  }

  // ── Gradient triangles ────────────────────────────────────────────────────

  void _drawTriangles(Canvas canvas, Size size) {
    final pw = _pw(size);
    final th = size.height * 0.46;
    final triDark = AppTheme.getBoardTriangleDark(ctx);
    final triLight = AppTheme.getBoardTriangleLight(ctx);

    for (int col = 0; col < 13; col++) {
      if (col == 6) continue;
      final x = col * pw;
      final isEven = col % 2 == 0;
      final baseColor = isEven ? triDark : triLight;
      final tipColor = isEven
          ? triDark.withValues(alpha: 0.35)
          : triLight.withValues(alpha: 0.45);
      final highlight = isEven
          ? triLight.withValues(alpha: 0.25)
          : triDark.withValues(alpha: 0.2);

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
          [highlight, baseColor, tipColor],
          [0.0, 0.25, 1.0],
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
          [highlight, baseColor, tipColor],
          [0.0, 0.25, 1.0],
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
    final layout = BearOffTrayLayout.fromBoardSize(size);
    final selBear = sel != null && bearOffMoves.any((m) => m.fromPoint == sel);
    final active = bearOffMoves.isNotEmpty && myTurn;
    final frame = AppTheme.getBoardFrameOuter(ctx);
    final inner = AppTheme.getBoardFrameInner(ctx);

    for (final entry in [
      (layout.whiteTray, PlayerColor.white, true),
      (layout.blackTray, PlayerColor.black, false),
    ]) {
      final tray = entry.$1;
      final isWhite = entry.$3;
      final highlight = selBear && active;
      final trayRrect = RRect.fromRectAndRadius(tray, const Radius.circular(8));

      canvas.drawRRect(
        trayRrect,
        Paint()
          ..shader = ui.Gradient.linear(
            tray.topLeft,
            tray.bottomRight,
            [
              inner.withValues(alpha: isWhite ? 0.35 : 0.28),
              frame.withValues(alpha: 0.2),
            ],
          ),
      );

      canvas.drawRRect(
        trayRrect,
        Paint()
          ..color = highlight
              ? const Color(0xFF4CAF50).withValues(alpha: 0.35)
              : frame.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlight ? 2 : 1.2,
      );

      // Slot rails (subtle groove — checkers are the focus)
      final railX = tray.left + tray.width * 0.12;
      final railW = tray.width * 0.76;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(railX, tray.top + 3, railW, tray.height - 6),
          const Radius.circular(6),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.08),
      );
    }

    final wOff = state.borneOff[PlayerColor.white] ?? 0;
    final bOff = state.borneOff[PlayerColor.black] ?? 0;

    paintVerticalCheckerStack(
      canvas,
      layout: layout,
      color: PlayerColor.white,
      count: wOff,
    );
    paintVerticalCheckerStack(
      canvas,
      layout: layout,
      color: PlayerColor.black,
      count: bOff,
    );

    if (wOff == 0 && bOff == 0) {
      _text(
        canvas,
        layout.columnX + layout.columnWidth / 2,
        size.height / 2,
        'OFF',
        TextStyle(
          color: AppTheme.getBoardBorderColor(ctx).withValues(alpha: 0.55),
          fontSize: layout.columnWidth * 0.22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      );
    }
  }

  // ── Double-layer frame ────────────────────────────────────────────────────

  void _drawFrame(Canvas canvas, Size size) {
    final outerColor = AppTheme.getBoardFrameOuter(ctx);
    final innerColor = AppTheme.getBoardFrameInner(ctx);
    const brass = Color(0xFFD4AF37);

    final outerRrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(10),
    );

    // Brass rail (visible “table” edge)
    canvas.drawRRect(
      outerRrect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [brass.withValues(alpha: 0.95), const Color(0xFF8B7355), brass],
          [0.0, 0.5, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    canvas.drawRRect(
      outerRrect,
      Paint()
        ..color = outerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
        const Radius.circular(8),
      ),
      Paint()
        ..color = innerColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
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
      final (col, top) = boardPointLayout(_modelPointToView(pt));
      final nudge = stackNudgePoint == pt ? stackNudgeOffset : 0.0;
      _drawStack(
        canvas,
        _cx(col, size),
        top,
        cnt.abs(),
        cnt > 0,
        r,
        size,
        nudgeOffset: nudge,
      );
    }
  }

  void _drawStack(
    Canvas canvas,
    double cx,
    bool top,
    int cnt,
    bool white,
    double r,
    Size size, {
    double nudgeOffset = 0,
  }) {
    const maxVisible = 5;
    final shown = min(cnt, maxVisible);
    final step = top ? r * 1.85 : -r * 1.85;
    final y0 = top ? r + 6.0 : size.height - r - 6.0;
    final nudgeDir = top ? -1.0 : 1.0;

    for (int i = 0; i < shown; i++) {
      final nudge = (i == shown - 1) ? nudgeOffset * nudgeDir : 0.0;
      _piece(canvas, cx, y0 + step * i + nudge, r, white);
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
    paintChecker(
      canvas,
      cx,
      cy,
      r,
      white,
      assets: BoardAssetsService.instance,
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
      final (col, top) = boardPointLayout(_modelPointToView(sel!));
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
      final (col, top) = boardPointLayout(_modelPointToView(t));
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
        final layout = BearOffTrayLayout.fromBoardSize(size);
        final tray = myColor == PlayerColor.white
            ? layout.whiteTray
            : layout.blackTray;
        canvas.drawRRect(
          RRect.fromRectAndRadius(tray, const Radius.circular(8)),
          Paint()
            ..color = const Color(0xFF4CAF50).withValues(alpha: 0.3)
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
