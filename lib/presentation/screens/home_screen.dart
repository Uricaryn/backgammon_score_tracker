import 'package:flutter/material.dart';
import 'dart:async';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/players_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/notifications_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/auth/auth_verification.dart';
import 'package:backgammon_score_tracker/core/auth/post_auth_navigation.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/core/services/update_notification_service.dart';
import 'package:backgammon_score_tracker/core/services/daily_tip_service.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';
import 'package:backgammon_score_tracker/presentation/screens/premium_upgrade_screen.dart';
import 'package:backgammon_score_tracker/core/services/ad_service.dart';
import 'package:backgammon_score_tracker/core/services/tutorial_service.dart';
import 'package:backgammon_score_tracker/core/widgets/banner_ad_widget.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_tutorial_overlay.dart';
import 'package:backgammon_score_tracker/presentation/widgets/tutorial_anchor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.startTutorial = false});

  /// Profilden turu tekrar başlatmak için.
  final bool startTutorial;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _mainScrollController = ScrollController();
  final _firebaseService = FirebaseService();
  final _guestDataService = GuestDataService();
  final _updateNotificationService = UpdateNotificationService();
  final _dailyTipService = DailyTipService();
  final _premiumService = PremiumService();
  final _adService = AdService();

  bool _isLoading = false;
  bool _isGuestUser = false;
  String _username = 'Kullanıcı';
  String _dailyTip = '';
  bool _isLoadingTip = false;
  bool _showTipPulse = false;

  final _welcomeKey = GlobalKey();
  final _onlineTavlaKey = GlobalKey();
  final _quickTournamentKey = GlobalKey();
  final _tournamentsKey = GlobalKey();
  final _socialKey = GlobalKey();
  final _fabKey = GlobalKey();

  bool _socialExpanded = false;
  bool _pendingUpdatesAfterTutorial = false;
  int? _tutorialStepIndex;
  OverlayEntry? _tutorialOverlayEntry;
  Future<bool>? _premiumAccessFuture;
  StreamSubscription<bool>? _premiumActivatedSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _premiumAccessFuture = _premiumService.hasPremiumAccess();
    _premiumActivatedSub =
        _premiumService.premiumActivatedStream.listen((active) {
      if (active && mounted) {
        setState(() {
          _premiumAccessFuture = _premiumService.hasPremiumAccess();
        });
      }
    });
    _initializeScreen();
  }

  void _refreshPremiumAccessFuture() {
    setState(() {
      _premiumAccessFuture = _premiumService.hasPremiumAccess();
    });
  }

  // Geçiş reklamını göster
  Future<void> _showInterstitialAd() async {
    try {
      // Premium kullanıcı kontrolü
      final hasPremium = await _premiumService.hasPremiumAccess();
      if (hasPremium) {
        return;
      }

      final interstitialAd = await _adService.createInterstitialAd();
      if (interstitialAd != null) {
        await interstitialAd.show();
        interstitialAd.dispose();
      }
    } catch (e) {
      debugPrint('Geçiş reklamı gösterilemedi: $e');
    }
  }

  // ✅ Properly handle async initialization
  void _initializeScreen() {
    // Start async operations
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    try {
      // Ad service'i başlat
      await _adService.initialize();

      // ✅ Properly await async operations
      await Future.wait([
        _checkUserTypeAsync(),
        _loadUsername(),
        _loadDailyTip(),
      ]);

      // ✅ Post-frame callbacks for UI-dependent operations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkGuestDataMigrationOptimized();
        _scheduleTutorialOrUpdates();
        _showInterstitialAd();
      });
    } catch (e) {
      debugPrint('Screen initialization error: $e');
    }
  }

  // Günlük tavla bilgisini yükle
  Future<void> _loadDailyTip() async {
    if (mounted) {
      setState(() => _isLoadingTip = true);
    }

    try {
      final tip = await _dailyTipService.getDailyTip();
      if (mounted) {
        setState(() {
          _dailyTip = tip;
          _isLoadingTip = false;
          _showTipPulse = true;
        });

        // Pulse animation duration
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _showTipPulse = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading daily tip: $e');
      if (mounted) {
        setState(() => _isLoadingTip = false);
      }
    }
  }

  // ✅ Improved update check with proper error handling
  Future<void> _checkForPendingUpdates() async {
    if (!mounted) return;

    try {
      // ✅ Wait for UI to be ready
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        await _updateNotificationService.checkForPendingUpdates(context);
      }
    } catch (e) {
      debugPrint('Update check error: $e');
      // ✅ Don't show error to user for update checks
    }
  }

  // ✅ Make user type check async for proper state management
  Future<void> _checkUserTypeAsync() async {
    try {
      final isGuest = _firebaseService.isCurrentUserGuest();
      if (mounted) {
        setState(() {
          _isGuestUser = isGuest;
        });
      }
    } catch (e) {
      debugPrint('User type check error: $e');
      if (mounted) {
        setState(() {
          _isGuestUser = false;
        });
      }
    }
  }

  // ✅ Improved username loading with better error handling
  Future<void> _loadUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // ✅ Check guest status first
      final isGuest = _firebaseService.isCurrentUserGuest();

      if (user == null || isGuest) {
        if (mounted) {
          setState(() {
            _username = isGuest ? 'Misafir' : 'Kullanıcı';
          });
        }
        return;
      }

      if (AuthVerification.requiresEmailVerification(user)) {
        if (mounted) {
          await PostAuthNavigation.go(context, user: user);
        }
        return;
      }

      // ✅ Try to get username from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String finalUsername = 'Kullanıcı';

      if (userDoc.exists) {
        final userData = userDoc.data();

        // Kullanıcı adı kontrolü
        final username = userData?['username'] as String?;
        if (username == null || username.isEmpty) {
          // Kullanıcı adı yoksa username setup ekranına yönlendir
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRouter.usernameSetup);
          }
          return;
        }

        finalUsername = username;
      }

      if (mounted) {
        setState(() {
          _username = finalUsername;
        });
      }
    } catch (e) {
      debugPrint('Username loading error: $e');
      if (mounted) {
        setState(() {
          _username = 'Kullanıcı';
        });
      }
    }
  }

  // ✅ Improved guest data migration check
  Future<void> _checkGuestDataMigrationOptimized() async {
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        final isMigrated = await _guestDataService.isGuestDataMigrated();
        final hasShownMigration =
            await _guestDataService.hasShownMigrationDialog();

        if (isMigrated && !hasShownMigration && mounted) {
          // ✅ Small delay to ensure UI is ready
          await Future.delayed(const Duration(milliseconds: 200));

          if (mounted) {
            _showMigrationDialog();
            await _guestDataService.markMigrationDialogShown();
          }
        }
      }
    } catch (e) {
      debugPrint('Migration check error: $e');
    }
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
    _premiumActivatedSub?.cancel();
    _removeTutorialOverlay();
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.login,
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çıkış yapılırken hata oluştu: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<_HomeTutorialStep> _buildTutorialSteps() {
    final steps = <_HomeTutorialStep>[
      _HomeTutorialStep(
        targetKey: _welcomeKey,
        title: 'Hoş geldin',
        description:
            'Tavla Skor Takip ile maçlarını kaydet, skor tablosu oluştur ve arkadaşlarınla turnuvalar düzenle.',
      ),
      _HomeTutorialStep(
        targetKey: _onlineTavlaKey,
        title: 'Online Tavla',
        description:
            'Arkadaşınla canlı tavla oyna: oda oluştur, davet gönder veya oda koduyla katıl.',
        scrollAlignment: 0.12,
      ),
      _HomeTutorialStep(
        targetKey: _quickTournamentKey,
        title: 'Hızlı Turnuva',
        description:
            'Yeni maç başlat, oyuncuları yönet, skorboard ve maç geçmişine buradan ulaş.',
        scrollAlignment: 0.18,
      ),
    ];
    if (!_isGuestUser) {
      steps.add(
        _HomeTutorialStep(
          targetKey: _tournamentsKey,
          title: 'Turnuvalar',
          description:
              'Turnuva oluştur, katıl ve eşleşmeleri yönet. Online turnuvalarda canlı tavla odası açılır.',
          preferTooltipAbove: true,
          scrollAlignment: 0.42,
        ),
      );
    }
    steps.addAll([
      _HomeTutorialStep(
        targetKey: _socialKey,
        title: 'Hesap ve Sosyal',
        description: _isGuestUser
            ? 'Profilini yönet. Kayıt olduktan sonra arkadaş ekleyip davet gönderebilirsin.'
            : 'Arkadaşlarını ekle, profilini düzenle ve bildirimlerden davetleri takip et.',
        preferTooltipAbove: true,
        scrollAlignment: 0.48,
      ),
      _HomeTutorialStep(
        targetKey: _fabKey,
        title: 'Günün ipucu',
        description:
            'Ampul düğmesine basarak her gün yeni bir tavla bilgisi veya strateji ipucu okuyabilirsin.',
        preferTooltipAbove: true,
        scrollToEndFirst: true,
        scrollAlignment: 0.85,
      ),
    ]);
    return steps;
  }

  Widget _tutorialTarget(
    GlobalKey targetKey,
    Widget child, {
    bool fullWidth = true,
  }) {
    return TutorialAnchor(
      anchorKey: targetKey,
      fullWidth: fullWidth,
      child: child,
    );
  }

  void _removeTutorialOverlay() {
    _tutorialOverlayEntry?.remove();
    _tutorialOverlayEntry = null;
  }

  void _syncTutorialOverlay() {
    final steps = _buildTutorialSteps();
    final index = _tutorialStepIndex;
    if (index == null || index >= steps.length) {
      _removeTutorialOverlay();
      return;
    }

    _tutorialOverlayEntry ??= OverlayEntry(
      builder: (overlayContext) {
        final currentSteps = _buildTutorialSteps();
        final currentIndex = _tutorialStepIndex;
        if (currentIndex == null || currentIndex >= currentSteps.length) {
          return const SizedBox.shrink();
        }
        final currentStep = currentSteps[currentIndex];
        return HomeTutorialOverlay(
          key: ValueKey('tutorial_$currentIndex'),
          targetKey: currentStep.targetKey,
          title: currentStep.title,
          description: currentStep.description,
          stepIndex: currentIndex,
          totalSteps: currentSteps.length,
          scrollController: _mainScrollController,
          preferTooltipAbove: currentStep.preferTooltipAbove,
          scrollToEndFirst: currentStep.scrollToEndFirst,
          scrollAlignment: currentStep.scrollAlignment,
          onNext: _tutorialNext,
          onPrevious: _tutorialPrevious,
          onSkip: _tutorialSkip,
        );
      },
    );

    if (_tutorialOverlayEntry!.mounted) {
      _tutorialOverlayEntry!.markNeedsBuild();
    } else {
      Overlay.of(context).insert(_tutorialOverlayEntry!);
    }
  }

  Future<void> _scheduleTutorialOrUpdates() async {
    final force = widget.startTutorial;
    final shouldShow = force || await TutorialService.instance.shouldShow();
    if (shouldShow && mounted) {
      await _maybeStartTutorial(force: force);
    } else if (mounted) {
      await _checkForPendingUpdates();
    }
  }

  Future<void> _maybeStartTutorial({bool force = false}) async {
    if (!force && !await TutorialService.instance.shouldShow()) {
      await _checkForPendingUpdates();
      return;
    }
    if (!mounted) return;
    _pendingUpdatesAfterTutorial = true;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _tutorialStepIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTutorialOverlay();
    });
  }

  void _tutorialNext() {
    final steps = _buildTutorialSteps();
    final current = _tutorialStepIndex;
    if (current == null) return;
    if (current >= steps.length - 1) {
      _removeTutorialOverlay();
      setState(() => _tutorialStepIndex = null);
      _finishTutorial();
      return;
    }
    final nextIndex = current + 1;
    final nextKey = steps[nextIndex].targetKey;
    if (nextKey == _socialKey && !_socialExpanded) {
      setState(() {
        _socialExpanded = true;
        _tutorialStepIndex = nextIndex;
      });
    } else {
      setState(() => _tutorialStepIndex = nextIndex);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTutorialOverlay();
    });
  }

  void _tutorialPrevious() {
    if (_tutorialStepIndex == null || _tutorialStepIndex! <= 0) return;
    final prevIndex = _tutorialStepIndex! - 1;
    final prevKey = _buildTutorialSteps()[prevIndex].targetKey;
    if (prevKey == _socialKey && !_socialExpanded) {
      setState(() {
        _socialExpanded = true;
        _tutorialStepIndex = prevIndex;
      });
    } else {
      setState(() => _tutorialStepIndex = prevIndex);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTutorialOverlay();
    });
  }

  void _tutorialSkip() {
    _removeTutorialOverlay();
    setState(() => _tutorialStepIndex = null);
    _finishTutorial();
  }

  Future<void> _finishTutorial() async {
    await TutorialService.instance.markCompleted();
    if (_pendingUpdatesAfterTutorial && mounted) {
      _pendingUpdatesAfterTutorial = false;
      await _checkForPendingUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildHomeScaffold(context, userId);
  }

  Widget _buildHomeScaffold(BuildContext context, String userId) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tavla Skor Takip'),
        actions: [
          if (!_isGuestUser) ...[
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: userId)
                  .where('isRead', isEqualTo: false)
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) {
                  unreadCount = snapshot.data!.docs.length;
                }

                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
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
      floatingActionButton: _tutorialTarget(
        _fabKey,
        fullWidth: false,
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: FloatingActionButton(
            onPressed: _showDailyTipBottomSheet,
            backgroundColor:
                _showTipPulse ? Colors.amber[500] : Colors.amber[600],
            foregroundColor: Colors.white,
            elevation: _showTipPulse ? 12 : 8,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 500),
              turns: _isLoadingTip ? 0.5 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: _isLoadingTip ? 0.9 : (_showTipPulse ? 1.1 : 1.0),
                child: Icon(
                  _isLoadingTip ? Icons.hourglass_empty : Icons.lightbulb,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: _mainScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tutorialTarget(
                          _welcomeKey,
                          _buildWelcomeCard(_username),
                        ),
                        const SizedBox(height: 24),

                        _tutorialTarget(
                          _onlineTavlaKey,
                          _buildOnlineTavlaSection(),
                        ),
                        const SizedBox(height: 24),

                        _tutorialTarget(
                          _quickTournamentKey,
                          _buildMainFeaturesSection(),
                        ),
                        const SizedBox(height: 24),

                        if (!_isGuestUser) ...[
                          _tutorialTarget(
                            _tournamentsKey,
                            _buildTournamentsSection(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        _tutorialTarget(
                          _socialKey,
                          _buildOtherFeaturesSection(),
                        ),

                        // Premium section
                        if (!_isGuestUser) ...[
                          const SizedBox(height: 16),
                          _buildCompactPremiumSection(),
                        ],

                        // Banner reklam - en altta
                        const SizedBox(height: 16),
                        const BannerAdWidget(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Hoşgeldin kartı
  Widget _buildWelcomeCard(String displayName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş geldin!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                          ),
                    ),
                    Text(
                      displayName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isGuestUser
                ? 'Misafir hesabınızla temel özellikleri kullanabilirsiniz.'
                : 'Tavla oyunlarınızı takip edin, arkadaşlarınızla turnuvalar düzenleyin!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }

  void _openOnlineTavlaLobby() {
    Navigator.pushNamed(context, AppRouter.gameLobby);
  }

  /// Canlı tavla lobisi — diğer ana kartlarla aynı görsel dil.
  Widget _buildOnlineTavlaSection() {
    final cs = Theme.of(context).colorScheme;
    const accent = Color(0xFF00796B);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openOnlineTavlaLobby,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    color: accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Online Tavla',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                    fontSize: 18,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: accent.withValues(alpha: 0.45),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Yeni',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Oda aç, davet et veya kodla katıl',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Ana özellikler kartı
  Widget _buildMainFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showQuickFeaturesBottomSheet(),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hızlı Turnuva',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 18,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Maç başlat, oyuncuları yönet, skorları takip et',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showQuickFeaturesBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hızlı Turnuva',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            Text(
                              'Tavla oyunlarınızı kaydedin, skorları takip edin',
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
                    ],
                  ),
                ),
                // Features
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildBottomSheetButton(
                        icon: Icons.sports_esports,
                        color: Colors.blue,
                        label: 'Yeni Maç',
                        subtitle: 'Maç başlat ve skoru takip et',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NewGameScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildBottomSheetButton(
                        icon: Icons.people,
                        color: Colors.green,
                        label: 'Oyuncular',
                        subtitle: 'Oyuncuları yönet',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlayersScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildBottomSheetButton(
                        icon: Icons.leaderboard,
                        color: Colors.deepPurple,
                        label: 'Skorboard',
                        subtitle: 'Oynanan maçlardan otomatik skor tablosu',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.scoreboard);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildBottomSheetButton(
                        icon: Icons.history,
                        color: Colors.orange,
                        label: 'Maç Geçmişi',
                        subtitle: 'Geçmiş maçlarınızı görüntüleyin',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.matchHistory);
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetButton({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Turnuvalar kartı
  Widget _buildTournamentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events,
                        color: Colors.amber[800], size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Turnuvalar',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800],
                                  fontSize: 17,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Turnuva oluştur, katıl ve yönet. Sosyal turnuvalar Premium özelliği!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 16),
                _ModernFeatureButton(
                  icon: Icons.emoji_events,
                  color: Colors.amber[800]!,
                  label: 'Turnuvalar',
                  subtitle: 'Turnuva oluştur, katıl ve yönet',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.tournaments),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Kompakt premium bölümü
  Widget _buildCompactPremiumSection() {
    return FutureBuilder<bool>(
      future: _premiumAccessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final hasPremium = snapshot.data ?? false;

        if (hasPremium) {
          return const SizedBox.shrink(); // Premium kullanıcılar için gösterme
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final titleColor =
            isDark ? Colors.amber[700]! : const Color(0xFF7A4A00);
        final subtitleColor =
            isDark ? Colors.amber[700]!.withValues(alpha: 0.7) : const Color(0xFF8B5E1A);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDark
                    ? Colors.amber[700]!.withValues(alpha: 0.05)
                    : const Color(0xFFFFF1C7),
                isDark
                    ? Colors.amber[500]!.withValues(alpha: 0.02)
                    : const Color(0xFFFFE5A3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.amber[700]!.withValues(alpha: 0.2)
                  : const Color(0xFFE2B44A),
              width: isDark ? 1 : 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber[700]!.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.star,
                  color: titleColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium\'a Yükselt',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                    ),
                    Text(
                      'Sınırsız arkadaş + Sosyal turnuvalar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final activated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PremiumUpgradeScreen(source: 'home'),
                    ),
                  );
                  if (activated == true && mounted) {
                    _refreshPremiumAccessFuture();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'Yükselt',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Diğer özellikler kartı - ExpansionTile ile
  Widget _buildOtherFeaturesSection() {
    return FutureBuilder<bool>(
      future: _premiumAccessFuture,
      builder: (context, snapshot) {
        final hasPremium = snapshot.data ?? false;
        final friendsSubtitle = hasPremium
            ? 'Arkadaş ekle ve takip et'
            : 'Arkadaş ekle ve takip et (3 arkadaş limiti)';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExpansionTile(
            key: ValueKey('social_expanded_$_socialExpanded'),
            initiallyExpanded: _socialExpanded,
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            iconColor: Theme.of(context).colorScheme.primary,
            collapsedIconColor: Theme.of(context).colorScheme.primary,
            title: Row(
              children: [
                Icon(Icons.widgets_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hesap ve Sosyal',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 17,
                                ),
                      ),
                      Text(
                        'Profilini yönet, arkadaşlarını takip et.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    if (!_isGuestUser) ...[
                      _ModernFeatureButton(
                        icon: Icons.group,
                        color: Colors.purple,
                        label: 'Arkadaşlar',
                        subtitle: friendsSubtitle,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRouter.friends),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _ModernFeatureButton(
                      icon: Icons.person,
                      color: Colors.indigo,
                      label: 'Profil',
                      subtitle: 'Hesap ayarları',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
            ),
          ],
        );
      },
    );
  }

  void _showDailyTipBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.lightbulb,
                          color: Colors.amber[700],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Günün Tavla İpucu',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[700],
                                  ),
                            ),
                            Text(
                              'AI destekli günlük bilgi',
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
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      if (_isLoadingTip)
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Bilgi yükleniyor...',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                      else if (_dailyTip.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _dailyTip,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                          ),
                        )
                      else
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Bilgi yüklenemedi',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
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

// Modern ve büyük buton widget'ı
class _HomeTutorialStep {
  const _HomeTutorialStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.preferTooltipAbove = false,
    this.scrollToEndFirst = false,
    this.scrollAlignment = 0.08,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final bool preferTooltipAbove;
  final bool scrollToEndFirst;
  final double scrollAlignment;
}

class _ModernFeatureButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ModernFeatureButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.08);
    final Color iconBoxColor =
        isDark ? color.withValues(alpha: 0.32) : color.withValues(alpha: 0.18);
    final Color textColor =
        isDark ? Theme.of(context).colorScheme.onSurface : color;
    final Color subtitleColor = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBoxColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 28, color: subtitleColor),
            ],
          ),
        ),
      ),
    );
  }
}
