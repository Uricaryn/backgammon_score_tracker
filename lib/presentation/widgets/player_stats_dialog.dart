import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';

class PlayerStatsDialog extends StatelessWidget {
  final String playerName;

  const PlayerStatsDialog({
    super.key,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isGuestUser = FirebaseService().isCurrentUserGuest();

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Oyuncu İstatistikleri',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              playerName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isGuestUser)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'İstatistikler Sadece Giriş Yapan Kullanıcılar İçin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detaylı istatistikleri görüntülemek için giriş yapmanız gerekiyor.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('games')
                    .where('userId', isEqualTo: userId)
                    .where(Filter.or(
                      Filter('player1', isEqualTo: playerName),
                      Filter('player2', isEqualTo: playerName),
                    ))
                    .orderBy('timestamp', descending: true)
                    .limit(200)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Hata: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text(
                      'Henüz maç kaydı bulunmuyor',
                      textAlign: TextAlign.center,
                    );
                  }

                  int totalGames = snapshot.data!.docs.length;
                  int wins = 0;
                  int totalScore = 0;
                  Map<String, int> opponentStats = {};

                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final player1 = data['player1'] as String;
                    final player2 = data['player2'] as String;
                    final player1Score = data['player1Score'] as int;
                    final player2Score = data['player2Score'] as int;

                    if (player1 == playerName) {
                      totalScore += player1Score;
                      if (player1Score > player2Score) {
                        wins++;
                      }
                      opponentStats[player2] =
                          (opponentStats[player2] ?? 0) + 1;
                    } else {
                      totalScore += player2Score;
                      if (player2Score > player1Score) {
                        wins++;
                      }
                      opponentStats[player1] =
                          (opponentStats[player1] ?? 0) + 1;
                    }
                  }

                  double winRate =
                      totalGames > 0 ? (wins / totalGames) * 100 : 0;
                  double avgScore =
                      totalGames > 0 ? totalScore / totalGames : 0;

                  return Column(
                    children: [
                      _buildStatRow(
                          context, 'Toplam Maç', totalGames.toString()),
                      _buildStatRow(context, 'Galibiyet', wins.toString()),
                      _buildStatRow(context, 'Galibiyet Oranı',
                          '%${winRate.toStringAsFixed(1)}'),
                      _buildStatRow(context, 'Ortalama Skor',
                          avgScore.toStringAsFixed(1)),
                      const SizedBox(height: 24),
                      Text(
                        'Rakip İstatistikleri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ...opponentStats.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${entry.value} maç',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
