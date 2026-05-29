import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerStats {
  const PlayerStats({
    required this.totalMatches,
    required this.wins,
    required this.totalScore,
    required this.highestScore,
    required this.opponentWins,
  });

  final int totalMatches;
  final int wins;
  final int totalScore;
  final int highestScore;
  final Map<String, int> opponentWins;

  double get winRate =>
      totalMatches == 0 ? 0 : (wins / totalMatches) * 100;
}

class PlayerStatsService {
  PlayerStatsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<PlayerStats> computeStats({
    required String userId,
    required String playerName,
    int limit = 100,
  }) async {
    final snapshot = await _firestore
        .collection('games')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    var totalMatches = 0;
    var wins = 0;
    var totalScore = 0;
    var highestScore = 0;
    final opponentWins = <String, int>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final player1 = data['player1'] as String;
      final player2 = data['player2'] as String;
      final player1Score = data['player1Score'] as int;
      final player2Score = data['player2Score'] as int;

      if (player1 != playerName && player2 != playerName) {
        continue;
      }

      totalMatches++;

      final isPlayer1 = player1 == playerName;
      final score = isPlayer1 ? player1Score : player2Score;
      final opponent = isPlayer1 ? player2 : player1;

      totalScore += score;
      if (score > highestScore) {
        highestScore = score;
      }

      final won = (isPlayer1 && player1Score > player2Score) ||
          (!isPlayer1 && player2Score > player1Score);
      if (won) {
        wins++;
        opponentWins[opponent] = (opponentWins[opponent] ?? 0) + 1;
      }
    }

    return PlayerStats(
      totalMatches: totalMatches,
      wins: wins,
      totalScore: totalScore,
      highestScore: highestScore,
      opponentWins: opponentWins,
    );
  }
}
