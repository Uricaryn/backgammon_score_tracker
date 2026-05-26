import 'package:backgammon_score_tracker/core/models/game_state.dart';

class GameSession {
  const GameSession({
    required this.id,
    required this.playerWhiteId,
    required this.playerBlackId,
    required this.playerWhiteName,
    required this.playerBlackName,
    required this.createdAt,
    required this.updatedAt,
    required this.state,
    this.tournamentId,
    this.matchId,
  });

  final String id;
  final String playerWhiteId;
  final String playerBlackId;
  final String playerWhiteName;
  final String playerBlackName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GameState state;
  final String? tournamentId;
  final String? matchId;

  GameSession copyWith({
    String? id,
    String? playerWhiteId,
    String? playerBlackId,
    String? playerWhiteName,
    String? playerBlackName,
    DateTime? createdAt,
    DateTime? updatedAt,
    GameState? state,
    String? tournamentId,
    String? matchId,
  }) {
    return GameSession(
      id: id ?? this.id,
      playerWhiteId: playerWhiteId ?? this.playerWhiteId,
      playerBlackId: playerBlackId ?? this.playerBlackId,
      playerWhiteName: playerWhiteName ?? this.playerWhiteName,
      playerBlackName: playerBlackName ?? this.playerBlackName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      state: state ?? this.state,
      tournamentId: tournamentId ?? this.tournamentId,
      matchId: matchId ?? this.matchId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playerWhiteId': playerWhiteId,
      'playerBlackId': playerBlackId,
      'playerWhiteName': playerWhiteName,
      'playerBlackName': playerBlackName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'state': state.toMap(),
      if (tournamentId != null) 'tournamentId': tournamentId,
      if (matchId != null) 'matchId': matchId,
    };
  }

  factory GameSession.fromMap(Map<String, dynamic> map) {
    return GameSession(
      id: (map['id'] as String?) ?? '',
      playerWhiteId: (map['playerWhiteId'] as String?) ?? '',
      playerBlackId: (map['playerBlackId'] as String?) ?? '',
      playerWhiteName: (map['playerWhiteName'] as String?) ?? 'Beyaz',
      playerBlackName: (map['playerBlackName'] as String?) ?? 'Siyah',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      state: GameState.fromMap((map['state'] as Map<String, dynamic>?) ?? {}),
      tournamentId: map['tournamentId'] as String?,
      matchId: map['matchId'] as String?,
    );
  }
}
