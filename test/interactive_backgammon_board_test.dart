import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/presentation/widgets/interactive_backgammon_board.dart';

void main() {
  testWidgets('interactive board renders as a CustomPaint widget', (tester) async {
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

    // Tahta CustomPaint ile çiziliyor, GestureDetector sarmalıyor
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
