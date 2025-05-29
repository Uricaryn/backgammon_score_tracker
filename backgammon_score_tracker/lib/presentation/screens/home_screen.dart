import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/dice_icon.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/statistics_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/players_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/edit_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/widgets/match_details_dialog.dart';
import 'package:backgammon_score_tracker/presentation/widgets/player_stats_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:backgammon_score_tracker/presentation/screens/profile_screen.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final screenshotController = ScreenshotController();

  Future<void> _deleteGame(String gameId) async {
    try {
      await FirebaseFirestore.instance.collection('games').doc(gameId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maç başarıyla silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareScoreboard() async {
    try {
      final image = await screenshotController.capture(
        delay: const Duration(milliseconds: 10),
        pixelRatio: 3.0,
      );
      if (image == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/scoreboard.png').create();
      await file.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tavla Skor Tablosu',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Paylaşım sırasında hata oluştu: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildGameList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Hata: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Henüz maç kaydı yok'),
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final player1 = data['player1'] as String;
            final player2 = data['player2'] as String;
            final player1Score = data['player1Score'] as int;
            final player2Score = data['player2Score'] as int;
            final timestamp = (data['timestamp'] as Timestamp).toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    title: Text(
                      '$player1 vs $player2',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Skor: $player1Score - $player2Score',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditGameScreen(
                                    gameId: doc.id,
                                    player1: player1,
                                    player2: player2,
                                    player1Score: player1Score,
                                    player2Score: player2Score,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Maçı Sil'),
                                  content: const Text(
                                      'Bu maçı silmek istediğinizden emin misiniz?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('İptal'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteGame(doc.id);
                                      },
                                      child: Text(
                                        'Sil',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => MatchDetailsDialog(
                          player1: player1,
                          player2: player2,
                          player1Score: player1Score,
                          player2Score: player2Score,
                          timestamp: timestamp,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('Current User ID: $userId'); // Debug print

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tavla Skor Takip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Skorboard Card
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
                            padding: const EdgeInsets.all(20.0),
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.leaderboard,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Skor Tablosu',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.share),
                                      onPressed: _shareScoreboard,
                                      tooltip: 'Skor tablosunu paylaş',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Screenshot(
                                  controller: screenshotController,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.3,
                                      child: SingleChildScrollView(
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('games')
                                              .where('userId',
                                                  isEqualTo: userId)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError) {
                                              debugPrint(
                                                  'Skorboard Error: ${snapshot.error}'); // Debug print
                                              return Text(
                                                  'Hata: ${snapshot.error}');
                                            }

                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                  child:
                                                      CircularProgressIndicator());
                                            }

                                            if (!snapshot.hasData ||
                                                snapshot.data!.docs.isEmpty) {
                                              return const Text(
                                                  'Henüz maç kaydı bulunmuyor');
                                            }

                                            debugPrint(
                                                'Skorboard Data: ${snapshot.data!.docs.length} matches'); // Debug print

                                            // Oyuncu kazanma sayılarını hesapla
                                            Map<String, int> playerWins = {};
                                            Map<String, int> playerGames = {};
                                            for (var doc
                                                in snapshot.data!.docs) {
                                              final data = doc.data()
                                                  as Map<String, dynamic>;
                                              final player1 =
                                                  data['player1'] as String;
                                              final player2 =
                                                  data['player2'] as String;
                                              final player1Score =
                                                  data['player1Score'] as int;
                                              final player2Score =
                                                  data['player2Score'] as int;

                                              // Toplam oyun sayısını güncelle
                                              playerGames[player1] =
                                                  (playerGames[player1] ?? 0) +
                                                      1;
                                              playerGames[player2] =
                                                  (playerGames[player2] ?? 0) +
                                                      1;

                                              // Kazanma sayısını güncelle
                                              if (player1Score > player2Score) {
                                                playerWins[player1] =
                                                    (playerWins[player1] ?? 0) +
                                                        1;
                                              } else {
                                                playerWins[player2] =
                                                    (playerWins[player2] ?? 0) +
                                                        1;
                                              }
                                            }

                                            // Kazanma oranına göre sırala
                                            var sortedPlayers = playerWins
                                                .entries
                                                .toList()
                                              ..sort((a, b) {
                                                final aWinRate =
                                                    (playerWins[a.key] ?? 0) /
                                                        (playerGames[a.key] ??
                                                            1);
                                                final bWinRate =
                                                    (playerWins[b.key] ?? 0) /
                                                        (playerGames[b.key] ??
                                                            1);
                                                return bWinRate
                                                    .compareTo(aWinRate);
                                              });

                                            // Sadece ilk 6 oyuncuyu al
                                            final topPlayers =
                                                sortedPlayers.take(6).toList();

                                            return Column(
                                              children: [
                                                for (var i = 0;
                                                    i < topPlayers.length;
                                                    i++)
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 8.0),
                                                    child: InkWell(
                                                      onTap: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) =>
                                                              PlayerStatsDialog(
                                                            playerName:
                                                                topPlayers[i]
                                                                    .key,
                                                          ),
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surface,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .shadow
                                                                  .withOpacity(
                                                                      0.1),
                                                              blurRadius: 4,
                                                              offset:
                                                                  const Offset(
                                                                      0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                if (i < 3) ...[
                                                                  Icon(
                                                                    i == 0
                                                                        ? Icons
                                                                            .emoji_events
                                                                        : i == 1
                                                                            ? Icons.workspace_premium
                                                                            : Icons.military_tech,
                                                                    color: i ==
                                                                            0
                                                                        ? Colors
                                                                            .amber
                                                                        : i == 1
                                                                            ? Colors.grey[400]
                                                                            : Colors.brown[300],
                                                                    size: 28,
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          12),
                                                                ],
                                                                Text(
                                                                  topPlayers[i]
                                                                      .key,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight: i <
                                                                            3
                                                                        ? FontWeight
                                                                            .bold
                                                                        : FontWeight
                                                                            .normal,
                                                                    color: i < 3
                                                                        ? Theme.of(context)
                                                                            .colorScheme
                                                                            .primary
                                                                        : Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurface,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 12,
                                                                vertical: 6,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: i < 3
                                                                    ? Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primaryContainer
                                                                    : Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .surfaceVariant,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                              ),
                                                              child: Text(
                                                                '%${((playerWins[topPlayers[i].key] ?? 0) / (playerGames[topPlayers[i].key] ?? 1) * 100).toStringAsFixed(1)}',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: i < 3
                                                                      ? Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onPrimaryContainer
                                                                      : Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
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
                  // Match History Card
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
                            padding: const EdgeInsets.all(20.0),
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.history,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Maç Geçmişi',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  child: _buildGameList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
}
