import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart';
import 'package:backgammon_score_tracker/core/services/tournament_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_card.dart';
import 'package:backgammon_score_tracker/core/utils/number_utils.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_scoreboard_card.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TournamentService _tournamentService = TournamentService();
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    // Tab sayısını turnuva türüne göre ayarla
    final isPersonal = widget.tournament['category'] ==
        TournamentService.tournamentCategoryPersonal;
    final tabCount =
        isPersonal ? 3 : 4; // Kişisel turnuvalar için 3, sosyal için 4
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament['name']),
        actions: [
          // Düzenleme butonu
          if (widget.tournament['isCreator'] == true)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Turnuvayı Düzenle',
              onPressed: () => _showEditTournamentDialog(),
            ),

          // Turnuvayı bitir butonu (sadece aktif turnuvalar için)
          if (widget.tournament['isCreator'] == true &&
              widget.tournament['status'] == TournamentService.tournamentActive)
            IconButton(
              icon: const Icon(Icons.flag),
              tooltip: 'Turnuvayı Bitir',
              onPressed: () => _showFinishTournamentDialog(),
            ),

          // Silme butonu (sadece bekleyen veya tamamlanmış turnuvalar için)
          if (widget.tournament['isCreator'] == true &&
              (widget.tournament['status'] ==
                      TournamentService.tournamentPending ||
                  widget.tournament['status'] ==
                      TournamentService.tournamentCompleted))
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Turnuvayı Sil',
              onPressed: () => _showDeleteTournamentDialog(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: [
            const Tab(icon: Icon(Icons.leaderboard), text: 'Scoreboard'),
            const Tab(icon: Icon(Icons.sports_esports), text: 'Maçlar'),
            const Tab(icon: Icon(Icons.history), text: 'Geçmiş'),
            // Mesajlar sekmesi sadece sosyal turnuvalar için
            if (widget.tournament['category'] !=
                TournamentService.tournamentCategoryPersonal)
              const Tab(icon: Icon(Icons.chat), text: 'Mesajlar'),
          ],
        ),
      ),
      body: BackgroundBoard(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildScoreboardTab(),
            _buildMatchesTab(),
            _buildHistoryTab(),
            // Mesajlar sekmesi sadece sosyal turnuvalar için
            if (widget.tournament['category'] !=
                TournamentService.tournamentCategoryPersonal)
              _buildMessagesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboardTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament['id'])
          .snapshots(),
      builder: (context, tournamentSnapshot) {
        if (tournamentSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (tournamentSnapshot.hasError) {
          return Center(child: Text('Hata: ${tournamentSnapshot.error}'));
        }

        if (!tournamentSnapshot.hasData || !tournamentSnapshot.data!.exists) {
          return const Center(child: Text('Turnuva bulunamadı'));
        }

        final tournamentData =
            tournamentSnapshot.data!.data() as Map<String, dynamic>;
        final participants =
            List<String>.from(tournamentData['participants'] ?? []);

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream:
              _tournamentService.getTournamentMatches(widget.tournament['id']),
          builder: (context, matchesSnapshot) {
            if (matchesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (matchesSnapshot.hasError) {
              return Center(child: Text('Hata: ${matchesSnapshot.error}'));
            }

            final matches = matchesSnapshot.data ?? [];
            final completedMatches =
                matches.where((m) => m['status'] == 'completed').toList();

            // Tüm maçları (completed + pending) kullanarak oyuncu listesi oluştur
            final allMatches = matches;

            // Tournament maçlarını HomeScoreboardCard için uygun formata çevir
            return FutureBuilder<Map<String, dynamic>>(
              future: _convertMatchesToGameDataWithParticipants(
                completedMatches,
                allMatches,
                participants,
                tournamentData['category'],
              ),
              builder: (context, gameDataSnapshot) {
                if (gameDataSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (gameDataSnapshot.hasError) {
                  return Center(child: Text('Hata: ${gameDataSnapshot.error}'));
                }

                final gameData = gameDataSnapshot.data ??
                    {
                      'data': [],
                      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                    };

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: HomeScoreboardCard(
                    cachedGameData: gameData,
                    isGuestUser: false,
                    screenshotController: _screenshotController,
                    onShare: _shareScoreboard,
                    onPlayerTap: (playerName) => _showTournamentPlayerStats(
                        playerName, completedMatches),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Tournament maçlarını tüm katılımcıları içerecek şekilde çevir
  Future<Map<String, dynamic>> _convertMatchesToGameDataWithParticipants(
    List<Map<String, dynamic>> completedMatches,
    List<Map<String, dynamic>> allMatches,
    List<String> participants,
    String? tournamentCategory,
  ) async {
    final gameDataList = <Map<String, dynamic>>[];

    // Tamamlanmış maçları ekle
    for (final match in completedMatches) {
      final player1Name = match['player1Name'] ?? match['player1'];
      final player2Name = match['player2Name'] ?? match['player2'];
      final winnerScore = NumberUtils.safeParseInt(match['winnerScore']) ?? 0;
      final loserScore = NumberUtils.safeParseInt(match['loserScore']) ?? 0;

      final isPlayer1Winner = match['winner'] == match['player1'];
      final player1Score = isPlayer1Winner ? winnerScore : loserScore;
      final player2Score = isPlayer1Winner ? loserScore : winnerScore;

      gameDataList.add({
        'player1': player1Name,
        'player2': player2Name,
        'player1Score': player1Score,
        'player2Score': player2Score,
        'timestamp': match['completedAt'],
      });
    }

    // Hiç maçı olmayan katılımcıları tespit et ve dummy maçlar ekle
    final playersInMatches = <String>{};
    for (final match in allMatches) {
      if (match['player1Name'] != null) {
        playersInMatches.add(match['player1Name'] as String);
      }
      if (match['player2Name'] != null) {
        playersInMatches.add(match['player2Name'] as String);
      }
    }

    // Katılımcıların isimlerini al
    final category =
        tournamentCategory ?? TournamentService.tournamentCategorySocial;
    for (final participantId in participants) {
      String playerName;

      if (category == TournamentService.tournamentCategoryPersonal) {
        // Kişisel turnuva - oyuncu ismi
        final doc = await FirebaseFirestore.instance
            .collection('players')
            .doc(participantId)
            .get();
        playerName =
            doc.exists ? (doc.data()?['name'] ?? participantId) : participantId;
      } else {
        // Sosyal turnuva - kullanıcı adı
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(participantId)
            .get();
        playerName = doc.exists
            ? (doc.data()?['username'] ?? participantId)
            : participantId;
      }

      // Eğer bu oyuncu hiç maça çıkmamışsa, 0-0 dummy maç ekle
      if (!playersInMatches.contains(playerName)) {
        gameDataList.add({
          'player1': playerName,
          'player2': 'Henüz maç yok',
          'player1Score': 0,
          'player2Score': 0,
          'timestamp': null,
        });
      }
    }

    return {
      'data': gameDataList,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void _shareScoreboard() {
    // Scoreboard paylaşım fonksiyonu
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skor tablosu paylaşıldı!')),
    );
  }

  // Turnuva içinde oyuncu istatistiklerini göster
  void _showTournamentPlayerStats(
      String playerName, List<Map<String, dynamic>> matches) {
    // Oyuncunun turnuva içindeki istatistiklerini hesapla
    int totalMatches = 0;
    int wins = 0;
    int totalScore = 0;
    int highestScore = 0;
    Map<String, int> opponentWins = {};
    List<Map<String, dynamic>> playerMatches = [];

    for (final match in matches) {
      final player1Name = match['player1Name'] ?? match['player1'] ?? '';
      final player2Name = match['player2Name'] ?? match['player2'] ?? '';

      if (player1Name != playerName && player2Name != playerName) continue;

      totalMatches++;
      final isPlayer1 = player1Name == playerName;

      final winnerScore = NumberUtils.safeParseInt(match['winnerScore']) ?? 0;
      final loserScore = NumberUtils.safeParseInt(match['loserScore']) ?? 0;

      final player1Score =
          (match['winner'] == match['player1']) ? winnerScore : loserScore;
      final player2Score =
          (match['winner'] == match['player2']) ? winnerScore : loserScore;

      final score = isPlayer1 ? player1Score : player2Score;
      final opponent = isPlayer1 ? player2Name : player1Name;

      totalScore += score;
      if (score > highestScore) {
        highestScore = score;
      }

      if ((isPlayer1 && match['winner'] == match['player1']) ||
          (!isPlayer1 && match['winner'] == match['player2'])) {
        wins++;
        opponentWins[opponent] = (opponentWins[opponent] ?? 0) + 1;
      }

      playerMatches.add({
        'opponent': opponent,
        'score': score,
        'opponentScore': isPlayer1 ? player2Score : player1Score,
        'won': (isPlayer1 && match['winner'] == match['player1']) ||
            (!isPlayer1 && match['winner'] == match['player2']),
        'timestamp': match['completedAt'],
      });
    }

    // En çok yenilen rakip
    String mostBeatenOpponent = '';
    int maxWins = 0;
    opponentWins.forEach((opponent, winsCount) {
      if (winsCount > maxWins) {
        maxWins = winsCount;
        mostBeatenOpponent = opponent;
      }
    });

    final winRate = totalMatches > 0 ? (wins / totalMatches * 100) : 0.0;
    final avgScore = totalMatches > 0 ? (totalScore / totalMatches) : 0.0;

    // İstatistikleri dialog'da göster
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$playerName - Turnuva İstatistikleri'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Toplam Maç', totalMatches.toString()),
              _buildStatRow('Kazanılan', wins.toString()),
              _buildStatRow('Kaybedilen', (totalMatches - wins).toString()),
              _buildStatRow('Kazanma Oranı', '${winRate.toStringAsFixed(1)}%'),
              _buildStatRow('Toplam Puan', totalScore.toString()),
              _buildStatRow('Ortalama Puan', avgScore.toStringAsFixed(1)),
              _buildStatRow('En Yüksek Puan', highestScore.toString()),
              if (mostBeatenOpponent.isNotEmpty)
                _buildStatRow(
                    'En Çok Yenilen', '$mostBeatenOpponent ($maxWins)'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Maç Geçmişi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...playerMatches.map((match) => Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'vs ${match['opponent']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${match['score']} - ${match['opponentScore']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: match['won'] ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            match['won'] ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: match['won'] ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _tournamentService.getTournamentMatches(widget.tournament['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final matches = snapshot.data ?? [];
        final pendingMatches =
            matches.where((m) => m['status'] == 'pending').toList();
        final isCreator = widget.tournament['isCreator'] == true;
        final canModify = isCreator &&
            widget.tournament['status'] == TournamentService.tournamentActive;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Manuel maç ekleme butonu
              if (canModify) ...[
                StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Yeni Maç Ekle',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Turnuvaya yeni maç ekleyin',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showAddMatchDialog(),
                          child: const Text('Maç Ekle'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Bekleyen maçlar
              if (pendingMatches.isNotEmpty && canModify) ...[
                StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sonuç Gir',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...pendingMatches
                            .map((match) => _buildPendingMatchCard(match)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Boş alan ya da bilgi mesajı (maç yoksa)
              if (matches.isEmpty && !canModify)
                SizedBox(
                  height: 300, // Minimum height for empty state
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_esports_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz maç eklenmemiş',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Turnuva oluşturanı maç ekledikten sonra burada görüntülenecek',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _tournamentService.getTournamentMatches(widget.tournament['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final matches = snapshot.data ?? [];
        final completedMatches =
            matches.where((m) => m['status'] == 'completed').toList();

        if (completedMatches.isEmpty) {
          return const Center(
            child: Text('Henüz tamamlanmış maç yok.'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StyledCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Maç Geçmişi',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...completedMatches
                      .map((match) => _buildCompletedMatchCard(match)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingMatchCard(Map<String, dynamic> match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (match['round'] != null) ...[
              Text(
                'Round ${match['round']}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    match['player1Name'] ?? match['player1'] ?? 'TBD',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(' vs '),
                Expanded(
                  child: Text(
                    match['player2Name'] ?? match['player2'] ?? 'TBD',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showMatchResultDialog(match),
              child: const Text('Sonuç Gir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedMatchCard(Map<String, dynamic> match) {
    final isCreator = widget.tournament['isCreator'] == true;
    final canEdit = isCreator &&
        widget.tournament['status'] != TournamentService.tournamentCancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (match['round'] != null) ...[
                        Text(
                          'Round ${match['round']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match['player1Name'] ?? match['player1'] ?? 'TBD',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: match['winner'] == match['player1']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                          Text(
                            ' ${match['player1'] == match['winner'] ? match['winnerScore'] : match['loserScore']} - ${match['player2'] == match['winner'] ? match['winnerScore'] : match['loserScore']} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              match['player2Name'] ?? match['player2'] ?? 'TBD',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: match['winner'] == match['player2']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (match['completedAt'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tamamlandı: ${_formatDate(match['completedAt'])}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditMatchResultDialog(match),
                        tooltip: 'Sonucu Düzenle',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.red),
                        onPressed: () => _showDeleteMatchDialog(match),
                        tooltip: 'Maçı Sil',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMatchResultDialog(Map<String, dynamic> match) {
    final player1Controller = TextEditingController();
    final player2Controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maç Sonucu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${match['player1Name'] ?? match['player1']} vs ${match['player2Name'] ?? match['player2']}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: player1Controller,
                    decoration: InputDecoration(
                      labelText: match['player1Name'] ?? match['player1'],
                      hintText: 'Skor',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: player2Controller,
                    decoration: InputDecoration(
                      labelText: match['player2Name'] ?? match['player2'],
                      hintText: 'Skor',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _saveMatchResult(
              match,
              player1Controller.text,
              player2Controller.text,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showEditMatchResultDialog(Map<String, dynamic> match) {
    // Mevcut skorları al
    final player1Score = match['player1'] == match['winner']
        ? match['winnerScore']
        : match['loserScore'];
    final player2Score = match['player2'] == match['winner']
        ? match['winnerScore']
        : match['loserScore'];

    final player1Controller =
        TextEditingController(text: player1Score?.toString() ?? '');
    final player2Controller =
        TextEditingController(text: player2Score?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maç Sonucunu Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${match['player1Name'] ?? match['player1']} vs ${match['player2Name'] ?? match['player2']}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: player1Controller,
                    decoration: InputDecoration(
                      labelText: match['player1Name'] ?? match['player1'],
                      hintText: 'Skor',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: player2Controller,
                    decoration: InputDecoration(
                      labelText: match['player2Name'] ?? match['player2'],
                      hintText: 'Skor',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maç sonucunu değiştirmek turnuva istatistiklerini etkileyecektir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _saveMatchResult(
              match,
              player1Controller.text,
              player2Controller.text,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMatchDialog(Map<String, dynamic> match) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maçı Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu maçı silmek istediğinizden emin misiniz?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match['player1Name'] ?? match['player1']} vs ${match['player2Name'] ?? match['player2']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sonuç: ${match['player1'] == match['winner'] ? match['winnerScore'] : match['loserScore']} - ${match['player2'] == match['winner'] ? match['winnerScore'] : match['loserScore']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bu işlem geri alınamaz!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _deleteMatch(match),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMatch(Map<String, dynamic> match) async {
    try {
      await _tournamentService.deleteMatch(
        widget.tournament['id'],
        match['id'],
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maç başarıyla silindi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveMatchResult(
    Map<String, dynamic> match,
    String player1Score,
    String player2Score,
  ) async {
    try {
      final score1 = int.parse(player1Score);
      final score2 = int.parse(player2Score);

      if (score1 == score2) {
        throw Exception('Berabere sonuç olamaz');
      }

      final winnerId = score1 > score2 ? match['player1'] : match['player2'];
      final winnerScore = score1 > score2 ? score1 : score2;
      final loserScore = score1 > score2 ? score2 : score1;

      await _tournamentService.recordMatchResult(
        widget.tournament['id'],
        match['id'],
        winnerId,
        winnerScore,
        loserScore,
      );

      if (mounted) {
        Navigator.pop(context); // Close result dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maç sonucu kaydedildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  // Manuel maç ekleme diyalogu
  void _showAddMatchDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddMatchDialog(
        tournament: widget.tournament,
        onMatchAdded: () {
          // Maç eklendiğinde UI'yi yenile
          setState(() {});
        },
      ),
    );
  }

  // Turnuvayı bitir diyalogu
  void _showFinishTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turnuvayı Bitir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Turnuvayı bitirmek istediğinizden emin misiniz?'),
            const SizedBox(height: 12),
            const Text('• Turnuva bitirildikten sonra yeni maç eklenemez'),
            const Text('• Mevcut maçların sonuçları girilebilir'),
            const Text('• Bu işlem geri alınamaz'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _finishTournament(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Turnuvayı Bitir'),
          ),
        ],
      ),
    );
  }

  // Turnuvayı bitir
  Future<void> _finishTournament() async {
    try {
      await _tournamentService.finishTournament(widget.tournament['id']);

      if (mounted) {
        Navigator.pop(context); // Dialog'u kapat
        setState(() {
          // UI'yi yenile
          widget.tournament['status'] = TournamentService.tournamentCompleted;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnuva başarıyla bitirildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnuva bitirirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Turnuvayı düzenle diyalogu
  void _showEditTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => _EditTournamentDialog(
        tournament: widget.tournament,
        onTournamentEdited: () {
          // Turnuva güncellendiğinde UI'yi yenile
          setState(() {});
        },
      ),
    );
  }

  // Turnuvayı sil diyalogu
  void _showDeleteTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turnuvayı Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${widget.tournament['name']} turnuvasını silmek istediğinizden emin misiniz?'),
            const SizedBox(height: 12),
            const Text('⚠️ Bu işlem geri alınamaz!'),
            const SizedBox(height: 8),
            const Text('• Turnuva tamamen silinecek'),
            const Text('• Tüm maçlar silinecek'),
            const Text('• Davetler ve bildirimler silinecek'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _deleteTournament(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Turnuvayı sil
  Future<void> _deleteTournament() async {
    try {
      await _tournamentService.deleteTournament(widget.tournament['id']);

      if (mounted) {
        Navigator.pop(context); // Dialog'u kapat
        Navigator.pop(context); // Tournament detail screen'den çık

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnuva başarıyla silindi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnuva silinirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessagesTab() {
    final user = FirebaseAuth.instance.currentUser;
    final tournamentId = widget.tournament['id'];
    final messagesRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId)
        .collection('messages')
        .orderBy('timestamp', descending: false);
    final TextEditingController _messageController = TextEditingController();
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: messagesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Henüz mesaj yok.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isMe = data['userId'] == user?.uid;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['username'] ?? 'Kullanıcı',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMe
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data['message'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatChatTimestamp(data['timestamp']),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(hintText: 'Mesaj yaz...'),
                  onSubmitted: (_) =>
                      _sendMessage(_messageController, user, tournamentId),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () =>
                    _sendMessage(_messageController, user, tournamentId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage(
      TextEditingController controller, User? user, String tournamentId) async {
    final text = controller.text.trim();
    if (text.isEmpty || user == null) return;

    try {
      // Kullanıcı adını çek
      String username = user.displayName ?? '';
      if (username.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        username = userDoc.data()?['username'] ?? 'Kullanıcı';
      }

      // Mesajı kaydet
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .collection('messages')
          .add({
        'userId': user.uid,
        'username': username,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Turnuva katılımcılarına bildirim gönder
      await _sendTournamentMessageNotification(
          tournamentId, user.uid, username, text);

      controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilirken hata oluştu: $e')),
      );
    }
  }

  // Turnuva mesaj bildirimi gönder
  Future<void> _sendTournamentMessageNotification(String tournamentId,
      String fromUserId, String fromUsername, String message) async {
    try {
      // Turnuva bilgilerini al
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .get();

      if (!tournamentDoc.exists) return;

      final tournamentData = tournamentDoc.data()!;
      final participants =
          tournamentData['participants'] as List<dynamic>? ?? [];
      final tournamentName = tournamentData['name'] as String? ?? 'Turnuva';

      // Gönderen hariç diğer katılımcılara bildirim gönder
      for (final participantId in participants) {
        if (participantId != fromUserId) {
          await _sendMessageNotificationToUser(
            participantId.toString(),
            fromUsername,
            tournamentName,
            message,
            tournamentId,
          );
        }
      }
    } catch (e) {
      print('Turnuva mesaj bildirimi gönderilirken hata: $e');
    }
  }

  // Kullanıcıya mesaj bildirimi gönder
  Future<void> _sendMessageNotificationToUser(
    String toUserId,
    String fromUsername,
    String tournamentName,
    String message,
    String tournamentId,
  ) async {
    try {
      // Alıcının bildirim tercihlerini kontrol et
      final toUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(toUserId)
          .get();

      if (!toUserDoc.exists) return;

      final toUserData = toUserDoc.data()!;
      if (toUserData['socialNotifications'] != true) return;

      // Sadece Firebase'e bildirim kaydı yap
      // Local notification Cloud Functions tarafından gönderilecek
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': toUserId,
        'title': 'Yeni Turnuva Mesajı',
        'body':
            '$fromUsername: ${message.length > 50 ? message.substring(0, 50) + '...' : message}',
        'type': 'tournament_message',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'payload': 'tournament_message:$tournamentId',
          'source': 'tournament_message',
          'fromUserId': FirebaseAuth.instance.currentUser?.uid,
          'fromUserName': fromUsername,
          'tournamentId': tournamentId,
          'tournamentName': tournamentName,
          'message': message,
        },
      });

      // Local notification kaldırıldı - Cloud Functions tarafından gönderilecek
    } catch (e) {
      print('Kullanıcıya mesaj bildirimi gönderilirken hata: $e');
    }
  }

  String _formatChatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp is Timestamp)
          ? timestamp.toDate()
          : (timestamp is DateTime)
              ? timestamp
              : DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
      final now = DateTime.now();
      if (now.difference(date).inDays == 0) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}

// Turnuva düzenleme diyalogu widget'ı
class _EditTournamentDialog extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final VoidCallback onTournamentEdited;

  const _EditTournamentDialog({
    required this.tournament,
    required this.onTournamentEdited,
  });

  @override
  State<_EditTournamentDialog> createState() => _EditTournamentDialogState();
}

class _EditTournamentDialogState extends State<_EditTournamentDialog> {
  final TournamentService _tournamentService = TournamentService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _maxParticipantsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tournament['name']);
    _descriptionController =
        TextEditingController(text: widget.tournament['description'] ?? '');
    _maxParticipantsController = TextEditingController(
      text: widget.tournament['maxParticipants']?.toString() ?? '4',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Turnuvayı Düzenle'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Turnuva Adı',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Turnuva adı gerekli';
                      }
                      if (value.trim().length < 3) {
                        return 'Turnuva adı en az 3 karakter olmalı';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama (İsteğe bağlı)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _maxParticipantsController,
                    decoration: const InputDecoration(
                      labelText: 'Maksimum Katılımcı Sayısı',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Maksimum katılımcı sayısı gerekli';
                      }

                      final intValue = int.tryParse(value.trim());
                      if (intValue == null || intValue < 2) {
                        return 'En az 2 katılımcı olmalı';
                      }

                      final currentParticipants =
                          (widget.tournament['participants'] as List<dynamic>?)
                                  ?.length ??
                              0;
                      if (intValue < currentParticipants) {
                        return 'Mevcut katılımcı sayısından ($currentParticipants) az olamaz';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _editTournament,
          child: const Text('Güncelle'),
        ),
      ],
    );
  }

  Future<void> _editTournament() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      await _tournamentService.editTournament(
        widget.tournament['id'],
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        maxParticipants: int.parse(_maxParticipantsController.text.trim()),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onTournamentEdited();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnuva başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnuva güncellenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Manuel maç ekleme diyalogu widget'ı
class _AddMatchDialog extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final VoidCallback onMatchAdded;

  const _AddMatchDialog({
    required this.tournament,
    required this.onMatchAdded,
  });

  @override
  State<_AddMatchDialog> createState() => _AddMatchDialogState();
}

class _AddMatchDialogState extends State<_AddMatchDialog> {
  String? _selectedPlayer1;
  String? _selectedPlayer2;
  bool _isLoading = false;
  List<Map<String, dynamic>> _availablePlayers = [];

  @override
  void initState() {
    super.initState();
    _loadAvailablePlayers();
  }

  Future<void> _loadAvailablePlayers() async {
    try {
      setState(() => _isLoading = true);

      final category = widget.tournament['category'] ??
          TournamentService.tournamentCategorySocial;

      if (category == TournamentService.tournamentCategoryPersonal) {
        // Kişisel turnuva - oyuncuları yükle
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null) {
          final snapshot = await FirebaseFirestore.instance
              .collection('players')
              .where('userId', isEqualTo: currentUserId)
              .get();

          _availablePlayers = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] ?? 'Bilinmeyen',
                  })
              .toList();
        }
      } else {
        // Sosyal turnuva - turnuva katılımcılarını yükle
        final participants =
            List<String>.from(widget.tournament['participants'] ?? []);

        for (final userId in participants) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            _availablePlayers.add({
              'id': userId,
              'name': userDoc.data()!['username'] ?? 'Bilinmeyen',
            });
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oyuncular yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Maç Ekle'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Maç yapacak oyuncuları seçin:'),
                const SizedBox(height: 16),

                // Oyuncu 1 seçimi
                DropdownButtonFormField<String>(
                  value: _selectedPlayer1,
                  decoration: const InputDecoration(
                    labelText: 'Oyuncu 1',
                    border: OutlineInputBorder(),
                  ),
                  items: _availablePlayers
                      .where((player) => player['id'] != _selectedPlayer2)
                      .map((player) => DropdownMenuItem<String>(
                            value: player['id'],
                            child: Text(player['name']),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedPlayer1 = value);
                  },
                ),
                const SizedBox(height: 16),

                // Oyuncu 2 seçimi
                DropdownButtonFormField<String>(
                  value: _selectedPlayer2,
                  decoration: const InputDecoration(
                    labelText: 'Oyuncu 2',
                    border: OutlineInputBorder(),
                  ),
                  items: _availablePlayers
                      .where((player) => player['id'] != _selectedPlayer1)
                      .map((player) => DropdownMenuItem<String>(
                            value: player['id'],
                            child: Text(player['name']),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedPlayer2 = value);
                  },
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _canAddMatch() ? _addMatch : null,
          child: const Text('Maç Ekle'),
        ),
      ],
    );
  }

  bool _canAddMatch() {
    return _selectedPlayer1 != null &&
        _selectedPlayer2 != null &&
        _selectedPlayer1 != _selectedPlayer2 &&
        !_isLoading;
  }

  Future<void> _addMatch() async {
    if (!_canAddMatch()) return;

    try {
      setState(() => _isLoading = true);

      // Maç ID'si oluştur
      final matchId = FirebaseFirestore.instance.collection('matches').doc().id;

      // Turnuva bracket'ını güncelle
      await _addMatchToBracket(matchId);

      if (mounted) {
        Navigator.pop(context);
        widget.onMatchAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maç başarıyla eklendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maç eklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMatchToBracket(String matchId) async {
    // Turnuva bilgilerini al
    final tournamentDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament['id'])
        .get();

    if (!tournamentDoc.exists) {
      throw Exception('Turnuva bulunamadı');
    }

    final tournamentData = tournamentDoc.data()!;
    final bracket = Map<String, dynamic>.from(tournamentData['bracket'] ?? {});

    // Bracket'e maçı ekle
    if (bracket['type'] == 'round_robin') {
      final matches = List<Map<String, dynamic>>.from(bracket['matches'] ?? []);
      matches.add({
        'id': matchId,
        'player1': _selectedPlayer1,
        'player2': _selectedPlayer2,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      bracket['matches'] = matches;
    } else {
      // Elimination bracket için de benzer işlem
      final rounds = List<Map<String, dynamic>>.from(bracket['rounds'] ?? []);
      if (rounds.isEmpty) {
        rounds.add({
          'roundNumber': 1,
          'matches': [],
        });
      }

      final lastRound = rounds.last;
      final matches =
          List<Map<String, dynamic>>.from(lastRound['matches'] ?? []);
      matches.add({
        'id': matchId,
        'player1': _selectedPlayer1,
        'player2': _selectedPlayer2,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      lastRound['matches'] = matches;
      bracket['rounds'] = rounds;
    }

    // Bracket'ı güncelle
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament['id'])
        .update({
      'bracket': bracket,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
