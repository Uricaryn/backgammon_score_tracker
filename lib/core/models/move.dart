import 'package:backgammon_score_tracker/core/models/game_state.dart';

class Move {
  const Move({
    required this.player,
    required this.fromPoint,
    required this.toPoint,
    required this.dieUsed,
    this.hit = false,
    this.bearOff = false,
  });

  final PlayerColor player;
  final int? fromPoint;
  final int? toPoint;
  final int dieUsed;
  final bool hit;
  final bool bearOff;

  Map<String, dynamic> toMap() {
    return {
      'player': player.name,
      'fromPoint': fromPoint,
      'toPoint': toPoint,
      'dieUsed': dieUsed,
      'hit': hit,
      'bearOff': bearOff,
    };
  }

  factory Move.fromMap(Map<String, dynamic> map) {
    return Move(
      player: (map['player'] as String?) == 'black' ? PlayerColor.black : PlayerColor.white,
      fromPoint: (map['fromPoint'] as num?)?.toInt(),
      toPoint: (map['toPoint'] as num?)?.toInt(),
      dieUsed: (map['dieUsed'] as num?)?.toInt() ?? 0,
      hit: map['hit'] as bool? ?? false,
      bearOff: map['bearOff'] as bool? ?? false,
    );
  }
}
