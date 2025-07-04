import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/players_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/notifications_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/profile_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_scoreboard_card.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_match_list_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/core/services/update_notification_service.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_scoreboard_card.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_match_list_card.dart';

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
  final _updateNotificationService = UpdateNotificationService();

  // ✅ Optimized state management
  bool _isLoading = false;
  Map<String, dynamic>? _cachedGameData;
  DateTime? _lastRefresh;
  StreamSubscription<QuerySnapshot>? _gameStreamSubscription;
  Timer? _debounceTimer;
  bool _isGuestUser = false;

  // ✅ Performance optimizations
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const Duration _cacheTimeout = Duration(seconds: 30);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  // ✅ Consolidated initialization
  void _initializeScreen() {
    _mainScrollController.addListener(_scrollListener);
    _checkUserType();
    _initializeGameStream();

    // ✅ Optimize PostFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGuestDataMigrationOptimized();
      _checkForPendingUpdates();
    });
  }

  // ✅ Check for pending update notifications
  Future<void> _checkForPendingUpdates() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      if (mounted) {
        await _updateNotificationService.checkForPendingUpdates(context);
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  void _checkUserType() {
    _isGuestUser = _firebaseService.isCurrentUserGuest();
  }

  // ✅ Optimized guest data migration check
  Future<void> _checkGuestDataMigrationOptimized() async {
    await Future.microtask(() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.isAnonymous) {
          final isMigrated = await _guestDataService.isGuestDataMigrated();
          final hasShownMigration =
              await _guestDataService.hasShownMigrationDialog();

          if (isMigrated && !hasShownMigration && mounted) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              _showMigrationDialog();
              await _guestDataService.markMigrationDialogShown();
            }
          }
        }
      } catch (e) {
        debugPrint('Migration check error: $e');
      }
    });
  }

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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mainScrollController.removeListener(_scrollListener);
    _mainScrollController.dispose();
    _gameListScrollController.dispose();
    _gameStreamSubscription?.cancel();
    super.dispose();
  }

  void _initializeGameStream() {
    _gameStreamSubscription?.cancel();

    if (_isGuestUser) {
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
        // ✅ Single setState call
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
    // ✅ Optimize with debouncing
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(_debounceDelay, () async {
      if (_lastRefresh != null &&
          DateTime.now().difference(_lastRefresh!) < _cacheTimeout) {
        return;
      }

      if (_isLoading || !mounted) return;

      // ✅ Optimize state updates
      if (mounted) {
        setState(() => _isLoading = true);
      }

      try {
        if (_isGuestUser) {
          await _loadGuestGames();
        } else {
          await _loadFirebaseGames();
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
    });
  }

  Future<void> _loadFirebaseGames() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('games')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

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
  }

  // ✅ Optimize scroll listener
  void _scrollListener() {
    if (!mounted || _isLoading) return;

    if (_mainScrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      final position = _mainScrollController.position;
      if (position.pixels > position.maxScrollExtent * 0.8) {
        _loadInitialData();
      }
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

  // ✅ Optimize screenshot sharing
  Future<void> _shareScoreboard() async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Reduce pixel ratio for better performance
      final image = await screenshotController.capture(
        delay: const Duration(milliseconds: 50),
        pixelRatio: 2.0,
      );

      if (image == null || !mounted) return;

      final tempDir = await getTemporaryDirectory();
      final file = await File(
              '${tempDir.path}/scoreboard_${DateTime.now().millisecondsSinceEpoch}.png')
          .create();
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

  Future<void> _signOut() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

      _gameStreamSubscription?.cancel();
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              ),
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
                        // ✅ Optimized Scoreboard Card
                        HomeScoreboardCard(
                          cachedGameData: _cachedGameData,
                          isGuestUser: _isGuestUser,
                          screenshotController: screenshotController,
                          onShare: _shareScoreboard,
                        ),
                        const SizedBox(height: 16),
                        // ✅ Optimized Action Buttons
                        _buildActionButtons(),
                        const SizedBox(height: 16),
                        // ✅ Optimized Match List Card
                        HomeMatchListCard(
                          cachedGameData: _cachedGameData,
                          isGuestUser: _isGuestUser,
                          scrollController: _gameListScrollController,
                          onDeleteGame: _deleteGame,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ✅ Optimized loading indicator
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

  // ✅ Separate action buttons for better performance
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NewGameScreen(),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Maç'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PlayersScreen(),
              ),
            ),
            icon: const Icon(Icons.people),
            label: const Text('Oyuncular'),
          ),
        ),
      ],
    );
  }
}
