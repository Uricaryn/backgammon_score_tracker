import 'dart:math';

import 'package:backgammon_score_tracker/core/models/dice_roll.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';

class BackgammonEngineService {
  const BackgammonEngineService();

  DiceRoll rollDice([Random? random]) {
    final rng = random ?? Random();
    return DiceRoll(die1: rng.nextInt(6) + 1, die2: rng.nextInt(6) + 1);
  }

  int rollSingleDie([Random? random]) {
    return (random ?? Random()).nextInt(6) + 1;
  }

  /// Records [color]'s opening die [die] and resolves the starting player once
  /// both dice are present.  Returns the updated [GameState].
  ///
  /// - If only one player has rolled, saves their die and keeps status as
  ///   [GameStatus.openingRoll].
  /// - If both have rolled and it's a tie, resets both dice so they roll again.
  /// - If both have rolled and there's a clear winner, transitions to
  ///   [GameStatus.active] with the winner's turn and both dice as remaining.
  GameState resolveOpeningDie(GameState state, PlayerColor color, int die) {
    assert(state.status == GameStatus.openingRoll);

    final wRoll = color == PlayerColor.white ? die : state.openingRollWhite;
    final bRoll = color == PlayerColor.black ? die : state.openingRollBlack;

    if (wRoll != null && bRoll != null) {
      if (wRoll == bRoll) {
        // Tie: reset and let both roll again.
        return state.copyWith(clearOpeningRolls: true);
      }
      final firstPlayer = wRoll > bRoll ? PlayerColor.white : PlayerColor.black;
      final higherDie = wRoll > bRoll ? wRoll : bRoll;
      final lowerDie = wRoll > bRoll ? bRoll : wRoll;
      final activeState = state.copyWith(
        currentTurn: firstPlayer,
        remainingDice: [higherDie, lowerDie],
        status: GameStatus.active,
        clearOpeningRolls: true,
        openingShowWhite: wRoll,
        openingShowBlack: bRoll,
        openingShowFirst: firstPlayer,
        version: state.version + 1,
      );
      // If no legal moves exist for the winner's dice, pass the turn.
      if (legalMoves(activeState).isEmpty) {
        return activeState.copyWith(
          currentTurn: _opponent(firstPlayer),
          remainingDice: const [],
          clearTurnUndo: true,
        );
      }
      return _attachTurnUndoBaseline(activeState);
    }

    // Only one player has rolled so far.
    return state.copyWith(
      openingRollWhite: wRoll,
      openingRollBlack: bRoll,
    );
  }

  GameState startTurn(GameState state, DiceRoll roll) {
    final nextState = state.copyWith(
      remainingDice: roll.toMoves(),
      status: GameStatus.active,
      clearWinner: true,
      clearTurnUndo: true,
    );
    // Backgammon rule: if no legal move exists for rolled dice, turn passes.
    if (legalMoves(nextState).isEmpty) {
      return nextState.copyWith(
        currentTurn: _opponent(state.currentTurn),
        remainingDice: const [],
        clearTurnUndo: true,
      );
    }
    return _attachTurnUndoBaseline(nextState);
  }

  /// Restores board + dice to the snapshot taken at the start of this turn.
  GameState undoTurn(GameState state) {
    final dice = state.turnUndoDice;
    final pts = state.turnUndoPoints;
    final br = state.turnUndoBar;
    final bo = state.turnUndoBorneOff;
    if (dice == null || pts == null || br == null || bo == null) {
      throw Exception('Geri alinacak tur kaydi yok.');
    }
    if (_sameDiceList(state.remainingDice, dice)) {
      throw Exception('Bu turda henuz hamle yapilmadi.');
    }
    return state.copyWith(
      points: List<int>.from(pts),
      bar: Map<PlayerColor, int>.from(br),
      borneOff: Map<PlayerColor, int>.from(bo),
      remainingDice: List<int>.from(dice),
      version: state.version + 1,
      clearLastMove: true,
    );
  }

  GameState _attachTurnUndoBaseline(GameState s) {
    return s.copyWith(
      turnUndoPoints: List<int>.from(s.points),
      turnUndoBar: Map<PlayerColor, int>.from(s.bar),
      turnUndoBorneOff: Map<PlayerColor, int>.from(s.borneOff),
      turnUndoDice: List<int>.from(s.remainingDice),
    );
  }

  bool _sameDiceList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<Move> legalMoves(GameState state) {
    final color = state.currentTurn;
    if (state.status == GameStatus.finished || state.remainingDice.isEmpty) {
      return const [];
    }

    final uniqueDice = state.remainingDice.toSet().toList()..sort();
    final moves = <Move>[];
    for (final die in uniqueDice) {
      moves.addAll(_legalMovesForDie(state, color, die));
    }
    return moves;
  }

  GameState applyMove(GameState state, Move move) {
    if (move.player != state.currentTurn) {
      throw Exception('Sira disi hamle.');
    }
    if (!state.remainingDice.contains(move.dieUsed)) {
      throw Exception('Kullanilan zar uygun degil.');
    }
    final isLegal = legalMoves(state).any((m) =>
        m.player == move.player &&
        m.fromPoint == move.fromPoint &&
        m.toPoint == move.toPoint &&
        m.dieUsed == move.dieUsed);
    if (!isLegal) {
      throw Exception('Gecersiz hamle.');
    }

    // Eski odalar / ilk hamle: tur basi anlik goruntu yoksa simdi kaydet.
    var base = state;
    if (base.turnUndoDice == null && base.remainingDice.isNotEmpty) {
      base = _attachTurnUndoBaseline(base);
    }

    final points = List<int>.from(base.points);
    final bar = Map<PlayerColor, int>.from(base.bar);
    final borneOff = Map<PlayerColor, int>.from(base.borneOff);
    final color = state.currentTurn;
    final sign = _sign(color);
    final opponent = _opponent(color);

    if (move.fromPoint == null) {
      bar[color] = (bar[color] ?? 0) - 1;
    } else {
      points[move.fromPoint!] -= sign;
    }

    if (move.bearOff || move.toPoint == null) {
      borneOff[color] = (borneOff[color] ?? 0) + 1;
    } else {
      final dst = move.toPoint!;
      if (points[dst] == -sign) {
        points[dst] = 0;
        bar[opponent] = (bar[opponent] ?? 0) + 1;
      }
      points[dst] += sign;
    }

    final remainingDice = List<int>.from(base.remainingDice);
    remainingDice.remove(move.dieUsed);

    var nextState = base.copyWith(
      points: points,
      bar: bar,
      borneOff: borneOff,
      remainingDice: remainingDice,
      version: base.version + 1,
      lastMoveFrom: move.fromPoint,
      lastMoveTo: move.toPoint,
      lastMoveHit: move.hit,
      lastMoveBearOff: move.bearOff,
      lastMovePlayer: move.player,
    );

    if ((borneOff[color] ?? 0) >= 15) {
      final winType = _determineWinType(nextState, color);
      nextState = nextState.copyWith(
        status: GameStatus.finished,
        winner: color,
        winType: winType,
        clearTurnUndo: true,
      );
      return nextState;
    }

    if (remainingDice.isEmpty || legalMoves(nextState).isEmpty) {
      nextState = nextState.copyWith(
        currentTurn: opponent,
        remainingDice: const [],
        clearTurnUndo: true,
      );
    }
    return nextState;
  }

  List<Move> _legalMovesForDie(GameState state, PlayerColor color, int die) {
    final sign = _sign(color);
    final moves = <Move>[];

    if ((state.bar[color] ?? 0) > 0) {
      final target = _entryPoint(color, die);
      if (_canLand(state.points[target], sign)) {
        moves.add(Move(
          player: color,
          fromPoint: null,
          toPoint: target,
          dieUsed: die,
          hit: state.points[target] == -sign,
        ));
      }
      return moves;
    }

    final points = state.points;
    for (var i = 0; i < points.length; i++) {
      if (points[i] * sign <= 0) {
        continue;
      }
      final target = i + (_direction(color) * die);
      if (target >= 0 && target < 24) {
        if (_canLand(points[target], sign)) {
          moves.add(Move(
            player: color,
            fromPoint: i,
            toPoint: target,
            dieUsed: die,
            hit: points[target] == -sign,
          ));
        }
      } else if (_canBearOff(state, color, i, die)) {
        moves.add(Move(
          player: color,
          fromPoint: i,
          toPoint: null,
          dieUsed: die,
          bearOff: true,
        ));
      }
    }
    return moves;
  }

  bool _canLand(int pointValue, int sign) {
    final opponentOnPoint = pointValue * sign < 0 ? pointValue.abs() : 0;
    return opponentOnPoint <= 1;
  }

  bool _canBearOff(GameState state, PlayerColor color, int fromPoint, int die) {
    if (!_allInHomeBoard(state, color)) {
      return false;
    }

    final target = fromPoint + (_direction(color) * die);
    if (color == PlayerColor.white) {
      if (target == -1) {
        return true;
      }
      if (target < -1) {
        for (var i = fromPoint + 1; i <= 5; i++) {
          if (state.points[i] > 0) {
            return false;
          }
        }
        return true;
      }
      return false;
    }

    if (target == 24) {
      return true;
    }
    if (target > 24) {
      for (var i = fromPoint - 1; i >= 18; i--) {
        if (state.points[i] < 0) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  bool _allInHomeBoard(GameState state, PlayerColor color) {
    if ((state.bar[color] ?? 0) > 0) {
      return false;
    }
    if (color == PlayerColor.white) {
      for (var i = 6; i < 24; i++) {
        if (state.points[i] > 0) {
          return false;
        }
      }
      return true;
    }
    for (var i = 0; i < 18; i++) {
      if (state.points[i] < 0) {
        return false;
      }
    }
    return true;
  }

  int _entryPoint(PlayerColor color, int die) {
    return color == PlayerColor.white ? 24 - die : die - 1;
  }

  PlayerColor _opponent(PlayerColor color) {
    return color == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
  }

  int _direction(PlayerColor color) => color == PlayerColor.white ? -1 : 1;

  int _sign(PlayerColor color) => color == PlayerColor.white ? 1 : -1;

  WinType _determineWinType(GameState state, PlayerColor winner) {
    final loser = _opponent(winner);
    final loserBorneOff = state.borneOff[loser] ?? 0;

    if (loserBorneOff > 0) return WinType.normal;

    // Mars (gammon): loser has 0 pieces borne off
    // Check for kapi marsi (backgammon): loser still on bar or in winner's home board
    final loserOnBar = state.bar[loser] ?? 0;
    if (loserOnBar > 0) return WinType.kapiMarsi;

    final loserSign = _sign(loser);
    final winnerHomeStart = winner == PlayerColor.white ? 0 : 18;
    final winnerHomeEnd = winner == PlayerColor.white ? 5 : 23;
    for (var i = winnerHomeStart; i <= winnerHomeEnd; i++) {
      if (state.points[i] * loserSign > 0) {
        return WinType.kapiMarsi;
      }
    }

    return WinType.mars;
  }
}
