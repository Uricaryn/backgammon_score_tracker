import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/presentation/screens/edit_player_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/player_match_history_screen.dart';
import 'dart:ui';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  final _firebaseService = FirebaseService();
  final _guestDataService = GuestDataService();
  bool _isLoading = false;
  bool _isGuestUser = false;

  @override
  void initState() {
    super.initState();
    _checkUserType();
  }

  void _checkUserType() {
    _isGuestUser = _firebaseService.isCurrentUserGuest();
  }

  Widget _buildGuestPlayersList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _guestDataService.getGuestPlayers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Hata: ${snapshot.error}'),
          );
        }

        final players = snapshot.data ?? [];

        if (players.isEmpty) {
          return const Center(
            child: Text('Henüz oyuncu eklenmemiş'),
          );
        }

        return ListView.builder(
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            final name = player['name'] as String;
            final playerId = player['id'] as String;

            return PlayerCard(
              playerName: name,
              playerId: playerId,
              onTap: () => _showPlayerOptions(
                context,
                name,
                playerId,
                this.context,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addPlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isGuestUser) {
        await _guestDataService.saveGuestPlayer(_playerNameController.text);
      } else {
        await FirebaseService().savePlayer(_playerNameController.text);
      }

      if (mounted) {
        _playerNameController.clear();
        setState(() {}); // Misafir kullanıcılar için listeyi yenile
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGuestUser
                ? 'Oyuncu yerel olarak kaydedildi'
                : ErrorService.successPlayerSaved),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePlayer(String playerId) async {
    try {
      String? deletedPlayerName;
      if (_isGuestUser) {
        // Misafir kullanıcıda oyuncu adı id ile eşleşiyor mu kontrol et
        final guestPlayers = await _guestDataService.getGuestPlayers();
        final player = guestPlayers.firstWhere((p) => p['id'] == playerId,
            orElse: () => {});
        deletedPlayerName = player['name'] as String?;
        await _guestDataService.deleteGuestPlayer(playerId);
        if (deletedPlayerName != null) {
          await _guestDataService
              .deleteGuestGamesByPlayerName(deletedPlayerName);
        }
      } else {
        // Önce oyuncunun adını al
        final playerDoc = await FirebaseFirestore.instance
            .collection('players')
            .doc(playerId)
            .get();
        deletedPlayerName = playerDoc.data()?['name'] as String?;
        await FirebaseFirestore.instance
            .collection('players')
            .doc(playerId)
            .delete();
        // Oyuncunun adıyla ilişkili tüm maçları sil
        if (deletedPlayerName != null) {
          final gamesQuery = await FirebaseFirestore.instance
              .collection('games')
              .where('userId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('player1', isEqualTo: deletedPlayerName)
              .get();
          for (final doc in gamesQuery.docs) {
            await doc.reference.delete();
          }
          final gamesQuery2 = await FirebaseFirestore.instance
              .collection('games')
              .where('userId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('player2', isEqualTo: deletedPlayerName)
              .get();
          for (final doc in gamesQuery2.docs) {
            await doc.reference.delete();
          }
        }
      }

      if (mounted) {
        setState(() {}); // Misafir kullanıcılar için listeyi yenile
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGuestUser
                ? 'Oyuncu ve ilişkili maçlar yerel olarak silindi'
                : ErrorService.successPlayerDeleted +
                    ' (İlişkili maçlar da silindi)'),
          ),
        );
      }
    } on FirebaseException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = ErrorService.firestorePermissionDenied;
          break;
        case 'not-found':
          errorMessage = ErrorService.firestoreDocumentNotFound;
          break;
        case 'unavailable':
          errorMessage = ErrorService.firestoreUnavailable;
          break;
        default:
          errorMessage = ErrorService.playerDeleteFailed;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.generalError)),
        );
      }
    }
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyuncular'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _playerNameController,
                            decoration: InputDecoration(
                              labelText: 'Oyuncu Adı',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              prefixIcon: Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            validator: ValidationService.validatePlayerName,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _addPlayer,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(
                                _isLoading ? 'Ekleniyor...' : 'Oyuncu Ekle'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
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
                                        Icons.people,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Oyuncu Listesi',
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
                                Expanded(
                                  child: _isGuestUser
                                      ? _buildGuestPlayersList()
                                      : StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('players')
                                              .where('userId',
                                                  isEqualTo: userId)
                                              .orderBy('createdAt',
                                                  descending: true)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError) {
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
                                              return const Center(
                                                child: Text(
                                                    'Henüz oyuncu eklenmemiş'),
                                              );
                                            }

                                            return ListView.builder(
                                              itemCount:
                                                  snapshot.data!.docs.length,
                                              itemBuilder: (context, index) {
                                                final doc =
                                                    snapshot.data!.docs[index];
                                                final data = doc.data()
                                                    as Map<String, dynamic>;
                                                final name =
                                                    data['name'] as String;

                                                return PlayerCard(
                                                  playerName: name,
                                                  playerId: doc.id,
                                                  onTap: () =>
                                                      _showPlayerOptions(
                                                          context,
                                                          name,
                                                          doc.id,
                                                          this.context),
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerOptions(BuildContext bottomSheetContext, String playerName,
      String playerId, BuildContext parentContext) {
    showModalBottomSheet(
      context: bottomSheetContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    playerName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Options
            ListTile(
              leading: Icon(
                Icons.analytics,
                color: _isGuestUser
                    ? Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.5)
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'İstatistikleri Görüntüle',
                style: TextStyle(
                  color: _isGuestUser
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : null,
                ),
              ),
              subtitle: Text(
                _isGuestUser
                    ? 'Giriş yaparak istatistikleri görüntüleyin'
                    : 'Oyuncunun detaylı istatistiklerini görüntüle',
                style: TextStyle(
                  color: _isGuestUser
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : null,
                ),
              ),
              onTap: _isGuestUser
                  ? () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Giriş Gerekli'),
                          content: const Text(
                            'İstatistikleri görüntülemek için giriş yapmanız gerekiyor',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('İptal'),
                            ),
                            FilledButton(
                              onPressed: () {
                                print(
                                    'DEBUG: İstatistik Giriş Yap butonuna tıklandı');
                                Navigator.pop(context);
                                Navigator.pushReplacementNamed(
                                    context, AppRouter.login,
                                    arguments: true);
                              },
                              child: const Text('Giriş Yap'),
                            ),
                          ],
                        ),
                      );
                    }
                  : () {
                      Navigator.pop(context);
                      Future.microtask(() {
                        _showPlayerStatistics(parentContext, playerName);
                      });
                    },
            ),
            ListTile(
              leading: Icon(
                Icons.history,
                color: _isGuestUser
                    ? Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.5)
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Maç Geçmişi',
                style: TextStyle(
                  color: _isGuestUser
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : null,
                ),
              ),
              subtitle: Text(
                _isGuestUser
                    ? 'Giriş yaparak maç geçmişini görüntüleyin'
                    : 'İkinci oyuncu seçerek maç geçmişini görüntüle',
                style: TextStyle(
                  color: _isGuestUser
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : null,
                ),
              ),
              onTap: _isGuestUser
                  ? () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Giriş Gerekli'),
                          content: const Text(
                            'Maç geçmişini görüntülemek için giriş yapmanız gerekiyor',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('İptal'),
                            ),
                            FilledButton(
                              onPressed: () {
                                print(
                                    'DEBUG: Maç Geçmişi Giriş Yap butonuna tıklandı');
                                Navigator.pop(context);
                                Navigator.pushReplacementNamed(
                                    context, AppRouter.login,
                                    arguments: true);
                              },
                              child: const Text('Giriş Yap'),
                            ),
                          ],
                        ),
                      );
                    }
                  : () {
                      Navigator.pop(context);
                      Future.microtask(() {
                        _showMatchHistoryDialog(parentContext, playerName);
                      });
                    },
            ),
            ListTile(
              leading: Icon(
                Icons.list_alt,
                color: _isGuestUser
                    ? Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.5)
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Tüm Maçlarını Görüntüle',
                style: TextStyle(
                  color: _isGuestUser
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : null,
                ),
              ),
              subtitle: Text(
                _isGuestUser
                    ? 'Giriş yaparak tüm maçları görüntüleyin'
                    : 'Oyuncunun tüm maçlarını görüntüle',
                style: TextStyle(
                  color: _isGuestUser
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : null,
                ),
              ),
              onTap: _isGuestUser
                  ? () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Giriş Gerekli'),
                          content: const Text(
                            'Tüm maçları görüntülemek için giriş yapmanız gerekiyor',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('İptal'),
                            ),
                            FilledButton(
                              onPressed: () {
                                print(
                                    'DEBUG: Tüm Maçlar Giriş Yap butonuna tıklandı');
                                Navigator.pop(context);
                                Navigator.pushReplacementNamed(
                                    context, AppRouter.login,
                                    arguments: true);
                              },
                              child: const Text('Giriş Yap'),
                            ),
                          ],
                        ),
                      );
                    }
                  : () {
                      Navigator.pop(context);
                      Future.microtask(() {
                        Navigator.push(
                          parentContext,
                          MaterialPageRoute(
                            builder: (context) => PlayerMatchHistoryScreen(
                              player1: playerName,
                              // player2 is null for single player mode
                            ),
                          ),
                        );
                      });
                    },
            ),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Oyuncuyu Düzenle'),
              subtitle: const Text('Oyuncu bilgilerini düzenle'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPlayerScreen(
                      playerId: playerId,
                      playerName: playerName,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Oyuncuyu Sil',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              subtitle: const Text('Oyuncuyu kalıcı olarak sil'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Oyuncuyu Sil'),
                    content: Text(
                        '$playerName oyuncusunu silmek istediğinizden emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deletePlayer(playerId);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPlayerStatistics(BuildContext context, String playerName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    print(
        'DEBUG: İstatistikler aranıyor - Oyuncu: $playerName, UserId: $userId');

    final snapshot = await FirebaseFirestore.instance
        .collection('games')
        .where('userId', isEqualTo: userId)
        .get();

    print('DEBUG: Toplam oyun sayısı: ${snapshot.docs.length}');

    int totalMatches = 0;
    int wins = 0;
    int totalScore = 0;
    int highestScore = 0;
    Map<String, int> opponentWins = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final player1 = data['player1'] as String;
      final player2 = data['player2'] as String;
      final player1Score = data['player1Score'] as int;
      final player2Score = data['player2Score'] as int;

      print(
          'DEBUG: Oyun kontrol ediliyor - Player1: $player1, Player2: $player2, Aranan: $playerName');

      if (player1 == playerName || player2 == playerName) {
        totalMatches++;
        print('DEBUG: Eşleşme bulundu! Toplam maç sayısı: $totalMatches');

        final isPlayer1 = player1 == playerName;
        final score = isPlayer1 ? player1Score : player2Score;
        final opponent = isPlayer1 ? player2 : player1;

        totalScore += score;
        if (score > highestScore) {
          highestScore = score;
        }

        if ((isPlayer1 && player1Score > player2Score) ||
            (!isPlayer1 && player2Score > player1Score)) {
          wins++;
          opponentWins[opponent] = (opponentWins[opponent] ?? 0) + 1;
          print('DEBUG: Kazanma! Toplam kazanma: $wins');
        }
      }
    }

    print(
        'DEBUG: Final istatistikler - Toplam: $totalMatches, Kazanma: $wins, Toplam Puan: $totalScore, En Yüksek: $highestScore');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.analytics,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$playerName - İstatistikler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
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
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatRow('Toplam Maç', '$totalMatches'),
                            _buildStatRow('Kazanma', '$wins'),
                            _buildStatRow(
                                'Kazanma Oranı',
                                totalMatches > 0
                                    ? '${(wins / totalMatches * 100).toStringAsFixed(1)}%'
                                    : '0%'),
                            _buildStatRow('Toplam Puan', '$totalScore'),
                            _buildStatRow('En Yüksek Puan', '$highestScore'),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showMatchHistoryDialog(BuildContext context, String playerName) {
    String? selectedPlayer;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('İkinci Oyuncuyu Seçin'),
              content: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('players')
                    .where('userId',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Hata: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Henüz oyuncu eklenmemiş'));
                  }

                  final players = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .map((data) => data['name'] as String)
                      .where((name) => name != playerName)
                      .toList();

                  return DropdownButtonFormField<String>(
                    value: selectedPlayer,
                    decoration: const InputDecoration(
                      labelText: 'İkinci Oyuncu',
                      border: OutlineInputBorder(),
                    ),
                    items: players
                        .map((player) => DropdownMenuItem(
                              value: player,
                              child: Text(player),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPlayer = value;
                      });
                    },
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: selectedPlayer == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerMatchHistoryScreen(
                                player1: playerName,
                                player2: selectedPlayer!,
                              ),
                            ),
                          );
                        },
                  child: const Text('Görüntüle'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class PlayerCard extends StatefulWidget {
  final String playerName;
  final String playerId;
  final VoidCallback onTap;

  const PlayerCard({
    super.key,
    required this.playerName,
    required this.playerId,
    required this.onTap,
  });

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Sürekli pulse animasyonunu başlat
    _startPulseAnimation();
  }

  void _startPulseAnimation() {
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Ekran genişliğine göre farklı düzenler
                      if (constraints.maxWidth < 400) {
                        // Küçük ekranlar için dikey düzen
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.playerName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  Icon(
                                    Icons.touch_app,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.6),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Büyük ekranlar için yatay düzen
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.playerName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Icon(
                                Icons.touch_app,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.6),
                                size: 18,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
