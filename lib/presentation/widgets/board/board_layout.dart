import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';

/// Shared duration for piece move overlay and destination hide.
const int kPieceMoveMs = 320;

const int kBoardCols = 14;

/// Board aspect ratio width : height = 4 : 3 (height = width * 0.75).
const double kBoardAspectRatio = 0.75;

(int col, bool top) boardPointLayout(int pt) {
  if (pt >= 12 && pt <= 17) return (pt - 12, true);
  if (pt >= 18 && pt <= 23) return (pt - 11, true);
  if (pt >= 6 && pt <= 11) return (11 - pt, false);
  return (12 - pt, false);
}

int boardColToPoint(int col, bool top) => top
    ? (col <= 5 ? 12 + col : 11 + col)
    : (col <= 5 ? 11 - col : 12 - col);

double boardPointWidth(Size boardSize) => boardSize.width / kBoardCols;

double boardColumnCenterX(int col, Size boardSize) =>
    (col + 0.5) * boardPointWidth(boardSize);

int boardModelToView(int point, PlayerColor myColor) =>
    myColor == PlayerColor.black ? 23 - point : point;

/// Legacy: fit by width first.
Size computeBoardSize(double maxWidth, double maxHeight) =>
    computeBoardSizeExpanded(maxWidth, maxHeight);

/// Fill vertical space (live game table) — reduces empty beige areas.
Size computeBoardSizeExpanded(
  double maxWidth,
  double maxHeight, {
  double heightFraction = 0.92,
  double horizontalPadding = 12,
}) {
  return computeBoardSizeFit(
    maxWidth - horizontalPadding,
    maxHeight.isFinite ? maxHeight * heightFraction : maxWidth * kBoardAspectRatio,
  );
}

/// Largest board that fits in [maxWidth] x [maxHeight] (portrait-friendly).
///
/// When [fillAvailableHeight] is true and width is the limiting edge (typical
/// portrait), grows board height up to [maxHeightToWidthRatio] × width (caps
/// vertical stretch; default 0.88 ≈ slightly taller than classic 4:3).
Size computeBoardSizeFit(
  double maxWidth,
  double maxHeight, {
  bool fillAvailableHeight = false,
  double maxHeightToWidthRatio = 0.88,
}) {
  if (maxWidth <= 0 || maxHeight <= 0) return Size.zero;

  final byWidth = Size(maxWidth, maxWidth * kBoardAspectRatio);
  final byHeight = Size(maxHeight / kBoardAspectRatio, maxHeight);

  final widthFits = byWidth.height <= maxHeight;
  final heightFits = byHeight.width <= maxWidth;

  Size chosen;
  if (widthFits && heightFits) {
    final areaW = byWidth.width * byWidth.height;
    final areaH = byHeight.width * byHeight.height;
    chosen = areaW >= areaH ? byWidth : byHeight;
  } else if (widthFits) {
    chosen = byWidth;
  } else if (heightFits) {
    chosen = byHeight;
  } else {
    chosen = Size(maxWidth, maxWidth * kBoardAspectRatio);
  }

  if (fillAvailableHeight &&
      chosen.width >= maxWidth * 0.98 &&
      chosen.height < maxHeight * 0.98) {
    final capH = maxWidth * maxHeightToWidthRatio;
    final targetH = capH.clamp(chosen.height, maxHeight);
    return Size(maxWidth, targetH);
  }
  return chosen;
}

/// Live game: use nearly all of the play-area box (minimizes empty felt).
Size computeBoardSizeLiveFill(double maxWidth, double maxHeight) {
  if (maxWidth <= 0 || maxHeight <= 0) return Size.zero;
  final boxRatio = maxHeight / maxWidth;
  if (boxRatio >= kBoardAspectRatio) {
    return Size(maxWidth, maxHeight);
  }
  return Size(maxHeight / kBoardAspectRatio, maxHeight);
}

double boardPieceRadius(Size boardSize) => boardPointWidth(boardSize) * 0.41;

Offset boardPieceCenter({
  required Size boardSize,
  required int modelPoint,
  required PlayerColor myColor,
  required GameState state,
  int stackIndexFromBase = 0,
}) {
  final r = boardPieceRadius(boardSize);
  final viewPt = boardModelToView(modelPoint, myColor);
  final (col, top) = boardPointLayout(viewPt);
  final cx = boardColumnCenterX(col, boardSize);
  final step = top ? r * 1.85 : -r * 1.85;
  final y0 = top ? r + 6.0 : boardSize.height - r - 6.0;
  final cy = y0 + step * stackIndexFromBase;
  return Offset(cx, cy);
}

Offset boardBarPieceCenter(Size boardSize, bool isWhite) {
  final pw = boardPointWidth(boardSize);
  return Offset(
    6.5 * pw,
    isWhite ? boardSize.height * 0.12 : boardSize.height * 0.88,
  );
}

Offset boardBearOffCenter(Size boardSize) {
  final pw = boardPointWidth(boardSize);
  return Offset(13.5 * pw, boardSize.height / 2);
}

/// Geometry for white (top) and black (bottom) collection trays.
class BearOffTrayLayout {
  const BearOffTrayLayout({
    required this.whiteTray,
    required this.blackTray,
    required this.checkerRadius,
    required this.columnX,
    required this.columnWidth,
  });

  static const int maxVisibleStack = 12;

  final Rect whiteTray;
  final Rect blackTray;
  final double checkerRadius;
  final double columnX;
  final double columnWidth;

  static BearOffTrayLayout fromBoardSize(Size boardSize) {
    final pw = boardPointWidth(boardSize);
    final x = 13 * pw;
    const pad = 3.0;
    const gap = 5.0;
    final mid = boardSize.height / 2;
    return BearOffTrayLayout(
      columnX: x,
      columnWidth: pw,
      checkerRadius: pw * 0.36,
      whiteTray: Rect.fromLTWH(x + pad, pad, pw - pad * 2, mid - gap - pad),
      blackTray: Rect.fromLTWH(
        x + pad,
        mid + gap,
        pw - pad * 2,
        boardSize.height - mid - gap - pad,
      ),
    );
  }

  Rect trayFor(PlayerColor color) =>
      color == PlayerColor.white ? whiteTray : blackTray;

  /// Vertical spacing between stacked borne-off checkers (fills tray as count grows).
  double stackStepFor(PlayerColor color, int visibleCount) {
    final tray = trayFor(color);
    final avail = tray.height - checkerRadius * 2.2;
    if (visibleCount <= 1) return checkerRadius * 0.85;
    final fit = avail / visibleCount;
    return fit.clamp(checkerRadius * 0.58, checkerRadius * 0.95);
  }

  /// Center of the [stackIndex] checker (0 = first collected, grows into tray).
  Offset checkerCenter(
    PlayerColor color,
    int stackIndex, {
    int visibleCount = 1,
    double? step,
  }) {
    final tray = trayFor(color);
    final shown = visibleCount.clamp(1, maxVisibleStack);
    final s = step ?? stackStepFor(color, shown);
    final cx = tray.center.dx;

    if (shown == 1) {
      final cy = color == PlayerColor.white
          ? tray.top + tray.height * 0.38
          : tray.bottom - tray.height * 0.38;
      return Offset(cx, cy);
    }

    if (color == PlayerColor.white) {
      return Offset(cx, tray.top + checkerRadius + 3 + stackIndex * s);
    }
    return Offset(cx, tray.bottom - checkerRadius - 3 - stackIndex * s);
  }

  /// Landing target for the next borne-off checker.
  Offset nextSlotCenter(PlayerColor color, int borneOffCount) {
    final idx = (borneOffCount - 1).clamp(0, 14);
    final visible = borneOffCount.clamp(1, maxVisibleStack);
    return checkerCenter(color, idx, visibleCount: visible);
  }
}

Offset boardBearOffCenterForColor(Size boardSize, PlayerColor color) {
  final layout = BearOffTrayLayout.fromBoardSize(boardSize);
  return layout.trayFor(color).center;
}

/// Standard die size when resting on the play surface.
double boardDiceSize(Size boardSize) => boardPointWidth(boardSize) * 0.68;

/// How many physical dice to show (always 2 for backgammon; doubles reuse faces).
int boardPhysicalDieCount(List<int> remainingDice) {
  if (remainingDice.isEmpty) return 0;
  return remainingDice.length >= 2 ? 2 : 1;
}

/// Face values for each physical die (handles doubles: same face twice).
List<int> boardDiceFaceValues(List<int> remainingDice) {
  if (remainingDice.isEmpty) return [];
  if (remainingDice.length >= 4) {
    final v = remainingDice.first.clamp(1, 6);
    return [v, v];
  }
  if (remainingDice.length >= 2) {
    return [
      remainingDice[0].clamp(1, 6),
      remainingDice[1].clamp(1, 6),
    ];
  }
  return [remainingDice[0].clamp(1, 6)];
}

/// Horizontal slot: local player rolls on the right, opponent on the left.
double boardDiceColumnX(
  Size boardSize,
  PlayerColor rollingPlayer,
  PlayerColor viewerColor,
) {
  final pw = boardPointWidth(boardSize);
  final onRight = rollingPlayer == viewerColor;
  return onRight ? 10.2 * pw : 3.2 * pw;
}

/// Rest Y pulled toward the board midline (above checker stacks at the rims).
double boardDiceRestY(Size boardSize, PlayerColor rollingPlayer) {
  final mid = boardSize.height * 0.5;
  final trayCy = boardBearOffCenterForColor(boardSize, rollingPlayer).dy;
  return trayCy + (mid - trayCy) * 0.58;
}

/// Resting centers on the rolling player's half (away from bar and checkers).
List<Offset> boardDiceRestPositions(
  Size boardSize,
  PlayerColor rollingPlayer,
  PlayerColor viewerColor,
  int physicalDieCount,
) {
  if (physicalDieCount <= 0) return [];
  final pw = boardPointWidth(boardSize);
  final cx = boardDiceColumnX(boardSize, rollingPlayer, viewerColor);
  final spread = pw * 0.85;
  final cy = boardDiceRestY(boardSize, rollingPlayer);

  if (physicalDieCount == 1) {
    return [Offset(cx, cy)];
  }
  return [
    Offset(cx - spread * 0.5, cy),
    Offset(cx + spread * 0.5, cy),
  ];
}

/// Spawn above the same side as the rest slot for the throw arc.
List<Offset> boardDiceThrowOrigins(
  Size boardSize,
  PlayerColor rollingPlayer,
  PlayerColor viewerColor,
  int physicalDieCount,
) {
  if (physicalDieCount <= 0) return [];
  final rests = boardDiceRestPositions(
    boardSize,
    rollingPlayer,
    viewerColor,
    physicalDieCount,
  );
  const throwY = 14.0;
  return rests.map((r) => Offset(r.dx, throwY)).toList();
}

int boardDestStackIndex(GameState gs, int modelPoint) {
  final destCnt = gs.points[modelPoint].abs();
  return (destCnt - 1).clamp(0, 4);
}

int boardFromStackIndex(GameState gs, int modelPoint) {
  final fromCnt = gs.points[modelPoint].abs();
  return fromCnt.clamp(0, 4);
}

Offset boardArcPosition(Offset from, Offset to, double t, Size boardSize) {
  final mid = Offset.lerp(from, to, 0.5)!;
  final lift = boardSize.height * 0.15;
  final control = Offset(mid.dx, mid.dy - lift);
  final u = 1 - t;
  return Offset(
    u * u * from.dx + 2 * u * t * control.dx + t * t * to.dx,
    u * u * from.dy + 2 * u * t * control.dy + t * t * to.dy,
  );
}

double boardLandingScaleY(double t) {
  if (t < 0.85) return 1.0;
  final land = (t - 0.85) / 0.15;
  if (land < 0.5) return 1.0 - land * 0.2;
  return 0.9 + (land - 0.5) * 0.2;
}
