import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/players_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/edit_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/notifications_screen.dart';
import 'package:backgammon_score_tracker/presentation/widgets/match_details_dialog.dart';
import 'package:backgammon_score_tracker/presentation/widgets/player_stats_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:backgammon_score_tracker/presentation/screens/profile_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final screenshotController = ScreenshotController();
  final _mainScrollController = ScrollController();
  final _gameListScrollController = ScrollController();
  final _firebaseService = FirebaseService();
  final _guestDataService = GuestDataService();
  bool _isLoading = false;
  Map<String, dynamic>? _cachedGameData;
  DateTime? _lastRefresh;
  StreamSubscription<QuerySnapshot>? _gameStreamSubscription;
  bool _isInitialized = false;
  bool _isGuestUser = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!_isInitialized) {
      _mainScrollController.addListener(_scrollListener);
      _checkUserType();
      _initializeGameStream();
      _isInitialized = true;

      // Misafir verilerinin aktarılıp aktarılmadığını kontrol et
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkGuestDataMigration();
      });
    }
  }

  void _checkUserType() {
    _isGuestUser = _firebaseService.isCurrentUserGuest();
  }

  // Misafir verilerinin aktarılıp aktarılmadığını kontrol et
  Future<void> _checkGuestDataMigration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        // Kullanıcı giriş yapmış ve misafir değil
        final isMigrated = await _guestDataService.isGuestDataMigrated();
        final hasShownMigration =
            await _guestDataService.hasShownMigrationDialog();

        if (isMigrated && !hasShownMigration) {
          // Misafir verileri aktarılmışsa ve dialog henüz gösterilmemişse kullanıcıya bildir
          if (mounted) {
            _showMigrationDialog();
            // Dialog gösterildi olarak işaretle
            await _guestDataService.markMigrationDialogShown();
          }
        }
      }
    } catch (e) {
      debugPrint('Migration check error: $e');
    }
  }

  // Misafir verilerinin aktarıldığını gösteren dialog
  void _showMigrationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.green),
              SizedBox(width: 8),
              Text('Veriler Aktarıldı'),
            ],
          ),
          content: const Text(
            'Misafir olarak kaydettiğiniz oyunlar ve oyuncular başarıyla hesabınıza aktarıldı. '
            'Artık tüm özelliklere erişebilir ve verilerinizi güvenle saklayabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeGameStream();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_scrollListener);
    _mainScrollController.dispose();
    _gameListScrollController.dispose();
    _cancelStreams();
    _isInitialized = false;
    super.dispose();
  }

  void _initializeGameStream() {
    // Önce mevcut stream'i iptal et
    _gameStreamSubscription?.cancel();

    if (_isGuestUser) {
      // Misafir kullanıcılar için yerel veri yükle
      _loadGuestGames();
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _gameStreamSubscription = FirebaseFirestore.instance
        .collection('games')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _cachedGameData = {
            'timestamp': DateTime.now(),
            'data': snapshot.docs
                .map((doc) => {
                      ...doc.data(),
                      'id': doc.id,
                    })
                .toList(),
          };
          _lastRefresh = DateTime.now();
        });
      }
    }, onError: (error) {
      debugPrint('Game Stream Error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veri yüklenirken hata oluştu: $error')),
        );
      }
    });
  }

  // Misafir kullanıcılar için yerel oyunları yükle
  Future<void> _loadGuestGames() async {
    try {
      final games = await _guestDataService.getGuestGames();
      if (mounted) {
        setState(() {
          _cachedGameData = {
            'timestamp': DateTime.now(),
            'data': games,
          };
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Guest Games Load Error: $e');
    }
  }

  Future<void> _loadInitialData() async {
    if (_lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!) < const Duration(seconds: 5)) {
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      if (_isGuestUser) {
        await _loadGuestGames();
      } else {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) return;

        final snapshot = await FirebaseFirestore.instance
            .collection('games')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .get();

        if (mounted) {
          setState(() {
            _cachedGameData = {
              'timestamp': DateTime.now(),
              'data': snapshot.docs
                  .map((doc) => {
                        ...doc.data(),
                        'id': doc.id,
                      })
                  .toList(),
            };
            _lastRefresh = DateTime.now();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veri yüklenirken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollListener() {
    if (!mounted || _isLoading) return;

    if (_mainScrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      _loadInitialData();
    }
  }

  Future<void> _deleteGame(String gameId) async {
    try {
      setState(() => _isLoading = true);

      if (_isGuestUser) {
        await _guestDataService.deleteGuestGame(gameId);
        await _loadGuestGames();
      } else {
        await FirebaseFirestore.instance
            .collection('games')
            .doc(gameId)
            .delete();
        await _loadInitialData();
      }

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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareScoreboard() async {
    try {
      setState(() => _isLoading = true);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildGameList() {
    if (_cachedGameData != null) {
      final games = _cachedGameData!['data'] as List<Map<String, dynamic>>;
      if (games.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Henüz maç kaydı yok'),
              if (_isGuestUser) ...[
                const SizedBox(height: 8),
                Text(
                  'Misafir kullanıcı olarak verileriniz yerel olarak saklanıyor',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _gameListScrollController,
        physics: const ClampingScrollPhysics(),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final data = games[index];
          final player1 = data['player1'] as String;
          final player2 = data['player2'] as String;
          final player1Score = data['player1Score'] as int;
          final player2Score = data['player2Score'] as int;
          final timestamp = data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.parse(data['timestamp'] as String);

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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  gameId: data['id'] as String,
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
                                      _deleteGame(data['id'] as String);
                                    },
                                    child: Text(
                                      'Sil',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
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
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildScoreboard() {
    if (_cachedGameData != null) {
      final games = _cachedGameData!['data'] as List<Map<String, dynamic>>;
      if (games.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Henüz maç kaydı bulunmuyor'),
              if (_isGuestUser) ...[
                const SizedBox(height: 8),
                Text(
                  'Misafir kullanıcı olarak verileriniz yerel olarak saklanıyor',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      }

      // Oyuncu kazanma sayılarını hesapla
      Map<String, int> playerWins = {};
      Map<String, int> playerGames = {};

      for (var data in games) {
        final player1 = data['player1'] as String;
        final player2 = data['player2'] as String;
        final player1Score = data['player1Score'] as int;
        final player2Score = data['player2Score'] as int;

        playerGames[player1] = (playerGames[player1] ?? 0) + 1;
        playerGames[player2] = (playerGames[player2] ?? 0) + 1;

        if (player1Score > player2Score) {
          playerWins[player1] = (playerWins[player1] ?? 0) + 1;
        } else {
          playerWins[player2] = (playerWins[player2] ?? 0) + 1;
        }
      }

      var sortedPlayers = playerWins.entries.toList()
        ..sort((a, b) {
          final aWinRate = (playerWins[a.key] ?? 0) / (playerGames[a.key] ?? 1);
          final bWinRate = (playerWins[b.key] ?? 0) / (playerGames[b.key] ?? 1);
          return bWinRate.compareTo(aWinRate);
        });

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sortedPlayers.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: InkWell(
                onTap: _isGuestUser
                    ? () {
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
                                  Navigator.pop(context);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LoginScreen(showSignUp: true),
                                    ),
                                  );
                                },
                                child: const Text('Giriş Yap'),
                              ),
                            ],
                          ),
                        );
                      }
                    : () {
                        showDialog(
                          context: context,
                          builder: (context) => PlayerStatsDialog(
                            playerName: sortedPlayers[i].key,
                          ),
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (i < 3) ...[
                            Icon(
                              i == 0
                                  ? Icons.emoji_events
                                  : i == 1
                                      ? Icons.workspace_premium
                                      : Icons.military_tech,
                              color: i == 0
                                  ? Colors.amber
                                  : i == 1
                                      ? Colors.grey[400]
                                      : Colors.brown[300],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            sortedPlayers[i].key,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  i < 3 ? FontWeight.bold : FontWeight.normal,
                              color: i < 3
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: i < 3
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '%${((playerWins[sortedPlayers[i].key] ?? 0) / (playerGames[sortedPlayers[i].key] ?? 1) * 100).toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: i < 3
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context)
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
    }

    return const Center(child: CircularProgressIndicator());
  }

  void _cancelStreams() {
    _gameStreamSubscription?.cancel();
    _gameStreamSubscription = null;
  }

  Future<void> _signOut() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

      // Önce stream'leri iptal et
      _cancelStreams();

      // Sonra çıkış yap
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.login,
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata oluştu: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tavla Skor Takip'),
        actions: [
          if (!_isGuestUser) ...[
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
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
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Stack(
        children: [
          BackgroundBoard(
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadInitialData,
                child: SingleChildScrollView(
                  controller: _mainScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
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
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: _buildScoreboard(),
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
                                        builder: (context) =>
                                            const NewGameScreen()),
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
                                        builder: (context) =>
                                            const PlayersScreen()),
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
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            MediaQuery.of(context).size.height *
                                                0.4,
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
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
