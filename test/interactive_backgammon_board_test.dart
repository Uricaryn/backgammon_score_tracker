import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/presentation/widgets/animated_piece_overlay.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_effects_overlay.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/interactive_backgammon_board.dart';

void main() {
  testWidgets('interactive board renders CustomPaint and gesture layer',
      (tester) async {
    final state = GameState.initial().copyWith(remainingDice: const [1]);
    final moves = [
      const Move(
        player: PlayerColor.white,
        fromPoint: 23,
        toPoint: 22,
        dieUsed: 1,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveBackgammonBoard(
            state: state,
            legalMoves: moves,
            onMoveSelected: (_) {},
            myColor: PlayerColor.white,
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(GestureDetector), findsWidgets);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });

  testWidgets('move version shows animated overlay and effects layer',
      (tester) async {
    var state = GameState.initial().copyWith(
      remainingDice: const [1],
      status: GameStatus.active,
      version: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveBackgammonBoard(
            state: state,
            legalMoves: const [],
            onMoveSelected: (_) {},
            myColor: PlayerColor.white,
          ),
        ),
      ),
    );

    state = state.copyWith(
      version: 1,
      lastMoveFrom: 23,
      lastMoveTo: 22,
      lastMovePlayer: PlayerColor.white,
      lastMoveHit: true,
      points: List<int>.from(state.points)..[23] = 1..[22] = 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveBackgammonBoard(
            state: state,
            legalMoves: const [],
            onMoveSelected: (_) {},
            myColor: PlayerColor.white,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AnimatedPieceOverlay), findsOneWidget);
    expect(find.byType(BoardEffectsOverlay), findsOneWidget);

    await tester.pump(const Duration(milliseconds: kPieceMoveMs));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
