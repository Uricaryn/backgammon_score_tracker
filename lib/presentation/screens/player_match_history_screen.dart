import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';

class PlayerMatchHistoryScreen extends StatefulWidget {
  final String player1;
  final String player2;

  const PlayerMatchHistoryScreen({
    super.key,
    required this.player1,
    required this.player2,
  });

  @override
  State<PlayerMatchHistoryScreen> createState() =>
      _PlayerMatchHistoryScreenState();
}

class _PlayerMatchHistoryScreenState extends State<PlayerMatchHistoryScreen> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _calculateStats();
  }

  Future<Map<String, dynamic>> _calculateStats() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('games')
        .where('userId', isEqualTo: userId)
        .get();

    int totalMatches = 0;
    int player1Wins = 0;
    int player2Wins = 0;
    int totalPlayer1Score = 0;
    int totalPlayer2Score = 0;
    int highestPlayer1Score = 0;
    int highestPlayer2Score = 0;
    List<Map<String, dynamic>> matchHistory = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final player1 = data['player1'] as String;
      final player2 = data['player2'] as String;
      final player1Score = data['player1Score'] as int;
      final player2Score = data['player2Score'] as int;
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      // Check if this match involves both players
      if ((player1 == widget.player1 && player2 == widget.player2) ||
          (player1 == widget.player2 && player2 == widget.player1)) {
        totalMatches++;

        // Determine winner and update scores
        if (player1 == widget.player1) {
          totalPlayer1Score += player1Score;
          totalPlayer2Score += player2Score;
          if (player1Score > player2Score) {
            player1Wins++;
          } else {
            player2Wins++;
          }
          highestPlayer1Score = player1Score > highestPlayer1Score
              ? player1Score
              : highestPlayer1Score;
          highestPlayer2Score = player2Score > highestPlayer2Score
              ? player2Score
              : highestPlayer2Score;
        } else {
          totalPlayer1Score += player2Score;
          totalPlayer2Score += player1Score;
          if (player2Score > player1Score) {
            player1Wins++;
          } else {
            player2Wins++;
          }
          highestPlayer1Score = player2Score > highestPlayer1Score
              ? player2Score
              : highestPlayer1Score;
          highestPlayer2Score = player1Score > highestPlayer2Score
              ? player1Score
              : highestPlayer2Score;
        }

        matchHistory.add({
          'player1': player1,
          'player2': player2,
          'player1Score': player1Score,
          'player2Score': player2Score,
          'timestamp': timestamp,
        });
      }
    }

    // Sort match history by timestamp (newest first)
    matchHistory.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return {
      'totalMatches': totalMatches,
      'player1Wins': player1Wins,
      'player2Wins': player2Wins,
      'totalPlayer1Score': totalPlayer1Score,
      'totalPlayer2Score': totalPlayer2Score,
      'highestPlayer1Score': highestPlayer1Score,
      'highestPlayer2Score': highestPlayer2Score,
      'matchHistory': matchHistory,
    };
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchHistoryItem(Map<String, dynamic> match) {
    final isPlayer1First = match['player1'] == widget.player1;
    final player1Score =
        isPlayer1First ? match['player1Score'] : match['player2Score'];
    final player2Score =
        isPlayer1First ? match['player2Score'] : match['player1Score'];
    final timestamp = match['timestamp'] as DateTime;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.player1,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          player1Score.toString(),
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
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.player2,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          player2Score.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.player1} vs ${widget.player2}'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Hata: ${snapshot.error}'),
                    );
                  }

                  final stats = snapshot.data ?? {};
                  final totalMatches = stats['totalMatches'] as int? ?? 0;
                  final player1Wins = stats['player1Wins'] as int? ?? 0;
                  final player2Wins = stats['player2Wins'] as int? ?? 0;
                  final matchHistory =
                      stats['matchHistory'] as List<Map<String, dynamic>>? ??
                          [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Head-to-head stats
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.7),
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.5),
                              ],
                            ),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.analytics,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'İstatistikler',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.2,
                                      children: [
                                        _buildStatCard(
                                          'Toplam Maç',
                                          totalMatches.toString(),
                                          Icons.sports_score,
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                        _buildStatCard(
                                          '${widget.player1} Kazanma',
                                          player1Wins.toString(),
                                          Icons.emoji_events,
                                          Colors.orange,
                                        ),
                                        _buildStatCard(
                                          '${widget.player2} Kazanma',
                                          player2Wins.toString(),
                                          Icons.emoji_events,
                                          Colors.deepPurple,
                                        ),
                                        _buildStatCard(
                                          'Kazanma Oranı',
                                          '${((player1Wins / totalMatches) * 100).toStringAsFixed(1)}%',
                                          Icons.percent,
                                          Colors.teal,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Match History
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.7),
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.5),
                              ],
                            ),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.history,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Maç Geçmişi',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (matchHistory.isEmpty)
                                      Center(
                                        child: Text(
                                          'Henüz maç kaydı yok',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: matchHistory.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) =>
                                            _buildMatchHistoryItem(
                                                matchHistory[index]),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
