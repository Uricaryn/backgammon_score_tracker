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
    this.participantIds = const [],
    this.awayPlayers = const [],
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
  final List<String> participantIds;
  final List<String> awayPlayers;

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
    List<String>? participantIds,
    List<String>? awayPlayers,
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
      participantIds: participantIds ?? this.participantIds,
      awayPlayers: awayPlayers ?? this.awayPlayers,
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
      'participantIds': participantIds,
      'awayPlayers': awayPlayers,
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
      participantIds: List<String>.from(
        (map['participantIds'] as List<dynamic>?) ?? _legacyParticipantIds(map),
      ),
      awayPlayers: List<String>.from(
        (map['awayPlayers'] as List<dynamic>?) ??
            (map['leftPlayers'] as List<dynamic>?) ??
            <dynamic>[],
      ),
    );
  }

  static List<String> _legacyParticipantIds(Map<String, dynamic> map) {
    final ids = <String>[];
    final w = map['playerWhiteId'] as String? ?? '';
    final b = map['playerBlackId'] as String? ?? '';
    if (w.isNotEmpty) ids.add(w);
    if (b.isNotEmpty) ids.add(b);
    return ids;
  }
}
