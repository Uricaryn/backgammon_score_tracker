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
    _tabController = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard), text: 'Scoreboard'),
            Tab(icon: Icon(Icons.sports_esports), text: 'Maçlar'),
            Tab(icon: Icon(Icons.history), text: 'Geçmiş'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboardTab() {
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
            child: Text(
                'Henüz tamamlanmış maç yok. Maç sonuçlarını girdikten sonra skor tablosu görüntülenecek.'),
          );
        }

        // Tournament maçlarını HomeScoreboardCard için uygun formata çevir
        final gameData = _convertMatchesToGameData(completedMatches);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: HomeScoreboardCard(
            cachedGameData: gameData,
            isGuestUser: false, // Tournament kullanıcıları kayıtlı
            screenshotController: _screenshotController,
            onShare: _shareScoreboard,
          ),
        );
      },
    );
  }

  // Tournament maçlarını HomeScoreboardCard için uygun formata çevir
  Map<String, dynamic> _convertMatchesToGameData(
      List<Map<String, dynamic>> matches) {
    final gameDataList = <Map<String, dynamic>>[];

    for (final match in matches) {
      final player1Name =
          match['player1Name'] ?? match['player1'] ?? 'Bilinmeyen';
      final player2Name =
          match['player2Name'] ?? match['player2'] ?? 'Bilinmeyen';
      final winnerScore = NumberUtils.safeParseInt(match['winnerScore']) ?? 0;
      final loserScore = NumberUtils.safeParseInt(match['loserScore']) ?? 0;

      // Kazanan ve kaybedeni belirle
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

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final isCompleted = match['status'] == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      color: isCompleted && match['winner'] == match['player1']
                          ? Colors.green
                          : null,
                    ),
                  ),
                ),
                const Text(' vs '),
                Expanded(
                  child: Text(
                    match['player2Name'] ?? match['player2'] ?? 'TBD',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted && match['winner'] == match['player2']
                          ? Colors.green
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sonuç: ${match['winnerScore']} - ${match['loserScore']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Bekliyor...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedMatchCard(Map<String, dynamic> match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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

  Future<String> _getPlayerName(String? playerId) async {
    if (playerId == null) return 'TBD';

    try {
      final category = widget.tournament['category'] ??
          TournamentService.tournamentCategorySocial;

      if (category == TournamentService.tournamentCategoryPersonal) {
        // Kişisel turnuva - oyuncu ismi
        final doc = await FirebaseFirestore.instance
            .collection('players')
            .doc(playerId)
            .get();
        if (doc.exists) {
          return doc.data()!['name'] ?? 'Bilinmeyen Oyuncu';
        }
      } else {
        // Sosyal turnuva - kullanıcı adı
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(playerId)
            .get();
        if (doc.exists) {
          return doc.data()!['username'] ?? 'Bilinmeyen Kullanıcı';
        }
      }

      return 'Bilinmeyen';
    } catch (e) {
      return 'Bilinmeyen';
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
  final TournamentService _tournamentService = TournamentService();
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
