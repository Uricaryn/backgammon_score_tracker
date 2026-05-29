import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_thrown_dice_overlay.dart';

void main() {
  const size = Size(400, 600);
  const viewer = PlayerColor.white;

  test('boardDiceRestPositions: local right, opponent left, mid height', () {
    final pw = boardPointWidth(size);
    final mine = boardDiceRestPositions(size, PlayerColor.white, viewer, 2);
    final opp = boardDiceRestPositions(size, PlayerColor.black, viewer, 2);
    expect(mine.first.dx, greaterThan(7 * pw));
    expect(opp.first.dx, lessThan(6 * pw));
    final whiteTray = whiteTrayCenterY(size);
    final blackTray = blackTrayCenterY(size);
    expect(mine.first.dy, greaterThan(whiteTray));
    expect(mine.first.dy, lessThan(opp.first.dy));
    expect(opp.first.dy, lessThan(blackTray));
  });

  test('boardDiceFaceValues handles doubles', () {
    expect(boardDiceFaceValues([4, 4, 4, 4]), [4, 4]);
    expect(boardDiceFaceValues([3, 5]), [3, 5]);
    expect(boardDiceFaceValues([6]), [6]);
  });

  testWidgets('BoardThrownDiceOverlay builds at rest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardThrownDiceOverlay(
            boardSize: size,
            targetValues: const [3, 5],
            isRolling: false,
            rollingPlayer: PlayerColor.white,
            viewerColor: viewer,
          ),
        ),
      ),
    );
    expect(find.byType(BoardThrownDiceOverlay), findsOneWidget);
  });
}

double whiteTrayCenterY(Size boardSize) =>
    boardBearOffCenterForColor(boardSize, PlayerColor.white).dy;

double blackTrayCenterY(Size boardSize) =>
    boardBearOffCenterForColor(boardSize, PlayerColor.black).dy;
