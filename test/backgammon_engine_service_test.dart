import 'package:flutter_test/flutter_test.dart';
import 'package:backgammon_score_tracker/core/models/dice_roll.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/services/backgammon_engine_service.dart';

void main() {
  group('BackgammonEngineService', () {
    final engine = const BackgammonEngineService();

    test('double zar 4 hamle uretir', () {
      final state = GameState.initial();
      final next = engine.startTurn(state, const DiceRoll(die1: 3, die2: 3));
      expect(next.remainingDice.length, 4);
    });

    test('barda tas varken yalniz bar cikis hamlesi uretilir', () {
      final state = GameState.initial().copyWith(
        bar: {PlayerColor.white: 1, PlayerColor.black: 0},
        remainingDice: const [5],
      );
      final legal = engine.legalMoves(state);
      expect(legal, isNotEmpty);
      expect(legal.every((m) => m.fromPoint == null), isTrue);
    });
  });
}
