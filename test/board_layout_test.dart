import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';

void main() {
  test('boardPointLayout maps standard points', () {
    expect(boardPointLayout(0), (12, false));
    expect(boardPointLayout(12), (0, true));
    expect(boardPointLayout(23), (12, true));
  });

  test('boardColToPoint inverts layout', () {
    expect(boardColToPoint(12, false), 0);
    expect(boardColToPoint(0, true), 12);
  });

  test('computeBoardSizeLiveFill uses full play-area box', () {
    final size = computeBoardSizeLiveFill(400, 520);
    expect(size.width, 400);
    expect(size.height, 520);
  });

  test('computeBoardSizeFit caps portrait stretch by aspect ratio', () {
    final size = computeBoardSizeFit(
      400,
      700,
      fillAvailableHeight: true,
      maxHeightToWidthRatio: 0.88,
    );
    expect(size.height, 352);
    expect(size.width, 400);
  });

  test('computeBoardSizeFit keeps 4:3 without fill flag', () {
    final size = computeBoardSizeFit(400, 700);
    expect(size.height, 300);
    expect(size.width, 400);
  });

  test('boardArcPosition lifts midpoint', () {
    const size = Size(400, 300);
    const from = Offset(50, 250);
    const to = Offset(350, 50);
    final mid = boardArcPosition(from, to, 0.5, size);
    final linear = Offset.lerp(from, to, 0.5)!;
    expect(mid.dy, lessThan(linear.dy));
  });

  test('boardModelToView reverses for black seat', () {
    expect(boardModelToView(0, PlayerColor.white), 0);
    expect(boardModelToView(0, PlayerColor.black), 23);
  });
}
