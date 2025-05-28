import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/dice_icon.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/statistics_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/players_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('Current User ID: $userId'); // Debug print

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backgammon Score Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Skorboard
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Skorboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('games')
                              .where('userId', isEqualTo: userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              debugPrint(
                                  'Skorboard Error: ${snapshot.error}'); // Debug print
                              return Text('Hata: ${snapshot.error}');
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text('Henüz maç kaydı bulunmuyor');
                            }

                            debugPrint(
                                'Skorboard Data: ${snapshot.data!.docs.length} matches'); // Debug print

                            // Oyuncu kazanma sayılarını hesapla
                            Map<String, int> playerWins = {};
                            for (var doc in snapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              debugPrint('Match Data: $data'); // Debug print

                              final player1 = data['player1'] as String;
                              final player2 = data['player2'] as String;
                              final player1Score = data['player1Score'] as int;
                              final player2Score = data['player2Score'] as int;

                              if (player1Score > player2Score) {
                                playerWins[player1] =
                                    (playerWins[player1] ?? 0) + 1;
                              } else {
                                playerWins[player2] =
                                    (playerWins[player2] ?? 0) + 1;
                              }
                            }

                            // Kazanma sayısına göre sırala
                            var sortedPlayers = playerWins.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value));

                            return Column(
                              children: [
                                for (var player in sortedPlayers)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          player.key,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        Text(
                                          '${player.value} galibiyet',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const NewGameScreen()),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Maç'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const PlayersScreen()),
                          );
                        },
                        icon: const Icon(Icons.people),
                        label: const Text('Oyuncular'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Maç Geçmişi
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Maç Geçmişi',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('games')
                                  .where('userId', isEqualTo: userId)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  debugPrint(
                                      'Match History Error: ${snapshot.error}'); // Debug print
                                  return Text('Hata: ${snapshot.error}');
                                }

                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const Center(
                                    child: Text('Henüz maç kaydı bulunmuyor'),
                                  );
                                }

                                debugPrint(
                                    'Match History Data: ${snapshot.data!.docs.length} matches'); // Debug print

                                return ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  itemBuilder: (context, index) {
                                    final doc = snapshot.data!.docs[index];
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    debugPrint(
                                        'Match Data: $data'); // Debug print

                                    final player1 = data['player1'] as String;
                                    final player2 = data['player2'] as String;
                                    final player1Score =
                                        data['player1Score'] as int;
                                    final player2Score =
                                        data['player2Score'] as int;
                                    final timestamp =
                                        (data['timestamp'] as Timestamp)
                                            .toDate();

                                    return ListTile(
                                      title: Text('$player1 vs $player2'),
                                      subtitle: Text(
                                        '${player1Score} - ${player2Score}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: player1Score > player2Score
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      trailing: Text(
                                        '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
