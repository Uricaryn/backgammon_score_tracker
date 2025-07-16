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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/core/services/update_notification_service.dart';
import 'package:backgammon_score_tracker/core/services/daily_tip_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  bool _isLoading = false;
  bool _isGuestUser = false;
  String _username = 'Kullanıcı';
  String _dailyTip = '';
  bool _isLoadingTip = false;
  bool _showTipPulse = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  // ✅ Properly handle async initialization
  void _initializeScreen() {
    // Start async operations
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    try {
      // ✅ Properly await async operations
      await Future.wait([
        _checkUserTypeAsync(),
        _loadUsername(),
        _loadDailyTip(),
      ]);

      // ✅ Post-frame callbacks for UI-dependent operations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkGuestDataMigrationOptimized();
          _checkForPendingUpdates();
        }
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

      // ✅ Try to get username from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String finalUsername = 'Kullanıcı';

      if (userDoc.exists) {
        final userData = userDoc.data();
        final username = userData?['username'] as String?;

        finalUsername = username ??
            user.displayName ??
            user.email?.split('@').first ??
            'Kullanıcı';
      } else {
        finalUsername =
            user.displayName ?? user.email?.split('@').first ?? 'Kullanıcı';
      }

      if (mounted) {
        setState(() {
          _username = finalUsername;
        });
      }
    } catch (e) {
      debugPrint('Username yüklenirken hata: $e');
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
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

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
      floatingActionButton: AnimatedContainer(
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
                        // Hoş geldin kartı
                        _buildWelcomeCard(_username),
                        const SizedBox(height: 24),

                        // Kişisel oyunlar bölümü
                        _buildMainFeaturesSection(),
                        const SizedBox(height: 24),

                        // Sosyal özellikler bölümü (sadece kayıtlı kullanıcılar için)
                        if (!_isGuestUser) ...[
                          _buildTournamentsSection(),
                          const SizedBox(height: 24),
                        ],

                        // Diğer özellikler
                        _buildOtherFeaturesSection(),
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

  // Ana özellikler kartı
  Widget _buildMainFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceVariant,
                Theme.of(context)
                    .colorScheme
                    .surfaceVariant
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
      builder: (context) => Container(
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
                                  color: Theme.of(context).colorScheme.primary,
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
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceVariant,
                Theme.of(context)
                    .colorScheme
                    .surfaceVariant
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
                  'Turnuva oluştur, katıl ve yönet. Arkadaşlarınla rekabet et!',
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

  // Diğer özellikler kartı - ExpansionTile ile
  Widget _buildOtherFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceVariant,
                Theme.of(context)
                    .colorScheme
                    .surfaceVariant
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
            initiallyExpanded: false,
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
                        subtitle: 'Arkadaş ekle ve takip et',
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
  }

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isFullWidth ? 28 : 24,
                    ),
                  ),
                  if (isFullWidth) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (!isFullWidth) ...[
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDailyTipBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                              .surfaceVariant
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
                                color: Theme.of(context).colorScheme.onSurface,
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
                              .surfaceVariant
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
    );
  }
}

// Modern ve büyük buton widget'ı
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
        isDark ? color.withOpacity(0.18) : color.withOpacity(0.08);
    final Color iconBoxColor =
        isDark ? color.withOpacity(0.32) : color.withOpacity(0.18);
    final Color textColor =
        isDark ? Theme.of(context).colorScheme.onSurface : color;
    final Color subtitleColor = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.85)
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
