import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/friendship_service.dart';
import 'package:backgammon_score_tracker/core/services/match_challenge_service.dart';
import 'package:backgammon_score_tracker/core/utils/number_utils.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_card.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/presentation/screens/player_match_history_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/tournaments_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/premium_upgrade_screen.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendshipService _friendshipService = FriendshipService();
  final MatchChallengeService _challengeService = MatchChallengeService();
  final PremiumService _premiumService = PremiumService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isGuestUser = false;
  Set<String> _sentRequests = {}; // Gönderilen arkadaşlık isteklerini takip et

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 5 -> 4
    _checkUserType();
  }

  void _checkUserType() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isGuestUser = user?.isAnonymous ?? true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Kullanıcı arama
  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || query.length < 2) {
      setState(() {
        _searchResults = [];
        _sentRequests.clear(); // Arama temizlenince istekleri de temizle
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _friendshipService.searchUsers(query);

      // Her arama sonucu için arkadaşlık durumunu kontrol et
      final updatedResults = <Map<String, dynamic>>[];
      final newSentRequests = <String>{};

      for (final user in results) {
        final status = await _friendshipService.getFriendshipStatus(user['id']);
        final updatedUser = Map<String, dynamic>.from(user);
        updatedUser['friendshipStatus'] = status;

        if (status == 'request_sent') {
          newSentRequests.add(user['id']);
        }

        updatedResults.add(updatedUser);
      }

      setState(() {
        _searchResults = updatedResults;
        _sentRequests = newSentRequests;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Arkadaşlık isteği gönder
  Future<void> _sendFriendRequest(String userId, String username) async {
    try {
      await _friendshipService.sendFriendRequest(userId);
      if (mounted) {
        // İsteği gönderildi listesine ekle
        setState(() {
          _sentRequests.add(userId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$username kullanıcısına arkadaşlık isteği gönderildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        if (errorMessage.contains('PREMIUM_REQUIRED:')) {
          // Premium gerekli dialog'u göster
          _showPremiumRequiredDialog('Arkadaş Ekleme');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Arkadaşlık isteği gönderilemedi: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Premium gerekli dialog'u göster
  void _showPremiumRequiredDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.star,
              color: Colors.amber[700],
              size: 24,
            ),
            const SizedBox(width: 8),
            Text('Premium Gerekli'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$feature özelliği için Premium\'a yükseltmeniz gerekiyor.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'Premium özellikler:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildPremiumFeatureItem('Sınırsız arkadaş ekleme'),
            _buildPremiumFeatureItem('Sosyal turnuva oluşturma'),
            _buildPremiumFeatureItem('Öncelikli destek'),
            _buildPremiumFeatureItem('Reklamsız deneyim'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PremiumUpgradeScreen(source: 'friends'),
                ),
              );
            },
            icon: const Icon(Icons.star, size: 16),
            label: const Text('Premium\'a Yükselt'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[600],
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(feature),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuestUser) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Arkadaşlar'),
        ),
        body: BackgroundBoard(
          child: Center(
            child: StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Arkadaş Özelliği',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Arkadaş ekleme ve arkadaşlarınızın maçlarını görme özelliği için hesap oluşturmanız gerekiyor.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Giriş Yap / Kayıt Ol'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _premiumService.hasPremiumAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: BackgroundBoard(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final hasPremium = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Arkadaşlar'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Tab genişliklerini hesapla ve scrollable olup olmayacağını belirle
                    final screenWidth = MediaQuery.of(context).size.width;
                    final availableWidth = constraints.maxWidth;

                    // Tab metinlerinin tahmini genişlikleri
                    final tabTexts = [
                      'Arkadaşlar',
                      'Aktivite',
                      'İstekler',
                      'Arama'
                    ];
                    final iconWidth = 24.0;
                    final textPadding = 8.0;
                    final tabPadding = 16.0;

                    double totalTabWidth = 0;
                    for (final text in tabTexts) {
                      final textWidth =
                          text.length * 8.0; // Tahmini karakter genişliği
                      totalTabWidth +=
                          iconWidth + textWidth + textPadding + tabPadding;
                    }

                    final isScrollable = totalTabWidth > availableWidth;

                    return TabBar(
                      controller: _tabController,
                      isScrollable: isScrollable,
                      labelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(icon: Icon(Icons.people), text: 'Arkadaşlar'),
                        Tab(icon: Icon(Icons.timeline), text: 'Aktivite'),
                        Tab(icon: Icon(Icons.person_add), text: 'İstekler'),
                        Tab(icon: Icon(Icons.search), text: 'Arama'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          body: BackgroundBoard(
            child: TabBarView(
              controller: _tabController,
              children: [
                _KeepAliveWrapper(
                  key: const PageStorageKey('friends_tab'),
                  child: _buildFriendsTab(),
                ),
                _KeepAliveWrapper(
                  key: const PageStorageKey('activity_tab'),
                  child: _buildActivityTab(),
                ),
                _KeepAliveWrapper(
                  key: const PageStorageKey('requests_tab'),
                  child: _buildRequestsTab(),
                ),
                _KeepAliveWrapper(
                  key: const PageStorageKey('search_tab'),
                  child: _buildSearchTab(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendshipService.getFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text('Hata: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          );
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz Arkadaşınız Yok',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Arama sekmesinden kullanıcı arayarak arkadaş ekleyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        _tabController.animateTo(3); // Arama sekmesine git
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Kullanıcı Ara'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return _buildFriendCard(friend);
          },
        );
      },
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    return StyledCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            (friend['username'] as String).isNotEmpty
                ? (friend['username'] as String)[0].toUpperCase()
                : 'K',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          friend['username'] ?? 'Bilinmeyen Kullanıcı',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(friend['email'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  friend['isActive'] == true
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 12,
                  color:
                      friend['isActive'] == true ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  friend['isActive'] == true ? 'Aktif' : 'Çevrimdışı',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        friend['isActive'] == true ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'view_details':
                Navigator.pushNamed(
                  context,
                  AppRouter.friendDetail,
                  arguments: friend,
                );
                break;
              case 'view_games':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlayerMatchHistoryScreen(
                      player1: friend['username'],
                      player2: null, // Tek oyuncu modu
                    ),
                  ),
                );
                break;
              case 'remove_friend':
                _showRemoveFriendDialog(friend);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_details',
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text('Detayları Görüntüle'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'view_games',
              child: ListTile(
                leading: Icon(Icons.sports_esports),
                title: Text('Maçlarını Görüntüle'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'remove_friend',
              child: ListTile(
                leading: Icon(Icons.person_remove, color: Colors.red),
                title: Text('Arkadaşlıktan Çıkar',
                    style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Gelen İstekler'),
              Tab(text: 'Gönderilen İstekler'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildIncomingRequestsTab(),
                _buildOutgoingRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendshipService.getIncomingFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gelen İstek Yok',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz size arkadaşlık isteği gönderen yok.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildIncomingRequestCard(request);
          },
        );
      },
    );
  }

  Widget _buildIncomingRequestCard(Map<String, dynamic> request) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  (request['fromUserName'] as String).isNotEmpty
                      ? (request['fromUserName'] as String)[0].toUpperCase()
                      : 'K',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                request['fromUserName'] ?? 'Bilinmeyen Kullanıcı',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(request['fromUserEmail'] ?? ''),
            ),
            if (request['message'] != null &&
                (request['message'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request['message'],
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _declineFriendRequest(request['id']),
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _acceptFriendRequest(request['id']),
                    icon: const Icon(Icons.check),
                    label: const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingRequestsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendshipService.getOutgoingFriendRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.send_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gönderilen İstek Yok',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz kimseye arkadaşlık isteği göndermediniz.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildOutgoingRequestCard(request);
          },
        );
      },
    );
  }

  Widget _buildOutgoingRequestCard(Map<String, dynamic> request) {
    return StyledCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            (request['toUserName'] as String).isNotEmpty
                ? (request['toUserName'] as String)[0].toUpperCase()
                : 'K',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          request['toUserName'] ?? 'Bilinmeyen Kullanıcı',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request['toUserEmail'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  'Bekliyor',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          tooltip: 'İsteği İptal Et',
          onPressed: () => _cancelFriendRequest(request['id']),
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          StyledCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı adı veya e-posta',
                      hintText: 'En az 2 karakter girin',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        _searchUsers();
                      } else {
                        setState(() {
                          _searchResults = [];
                        });
                      }
                    },
                  ),
                  if (_isSearching) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Aranıyor...'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _searchResults.isEmpty &&
                    _searchController.text.length >= 2 &&
                    !_isSearching
                ? Center(
                    child: StyledCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Kullanıcı Bulunamadı',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aradığınız kriterlere uygun kullanıcı bulunamadı.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return _buildSearchResultCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final friendshipStatus = user['friendshipStatus'] as String? ?? 'none';
    final isRequestSent =
        _sentRequests.contains(userId) || friendshipStatus == 'request_sent';

    return StyledCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            (user['username'] as String).isNotEmpty
                ? (user['username'] as String)[0].toUpperCase()
                : 'K',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user['username'] ?? 'Bilinmeyen Kullanıcı',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  user['isActive'] == true
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 12,
                  color: user['isActive'] == true ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  user['isActive'] == true ? 'Aktif' : 'Çevrimdışı',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        user['isActive'] == true ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing:
            _buildActionButton(friendshipStatus, userId, user['username']),
      ),
    );
  }

  Widget _buildActionButton(String status, String userId, String username) {
    switch (status) {
      case 'friends':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people,
                size: 18,
                color: Colors.blue[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Arkadaş',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      case 'request_sent':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 18,
                color: Colors.green[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Gönderildi',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      case 'request_received':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 18,
                color: Colors.orange[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Bekliyor',
                style: TextStyle(
                  color: Colors.orange[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      default:
        return FilledButton.icon(
          onPressed: () => _sendFriendRequest(userId, username),
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Ekle'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );
    }
  }

  Widget _buildActivityTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _friendshipService.getFriends(),
      builder: (context, friendsSnapshot) {
        if (friendsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (friendsSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text('Hata: ${friendsSnapshot.error}'),
              ],
            ),
          );
        }

        final friends = friendsSnapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timeline_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aktivite Yok',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Arkadaşlarınızın aktivitelerini burada görebilirsiniz. Önce arkadaş eklemeyi deneyin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        _tabController.animateTo(3); // Arama sekmesine git
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Kullanıcı Ara'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Arkadaş listesi varsa, arkadaşların son aktivitelerini göster
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getRecentActivities(friends),
          builder: (context, activitiesSnapshot) {
            if (activitiesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (activitiesSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Aktiviteler yüklenemedi'),
                  ],
                ),
              );
            }

            final activities = activitiesSnapshot.data ?? [];

            if (activities.isEmpty) {
              return Center(
                child: StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timeline_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz Aktivite Yok',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Arkadaşlarınız henüz hiç maç oynamamış.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityCard(activity);
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getRecentActivities(
      List<Map<String, dynamic>> friends) async {
    final List<Map<String, dynamic>> activities = [];

    // Arkadaşlık aktiviteleri - yakın zamanda eklenen arkadaşlar
    for (final friend in friends) {
      final friendshipDate = friend['friendshipDate'] as Timestamp?;
      if (friendshipDate != null) {
        final daysSinceAdded =
            DateTime.now().difference(friendshipDate.toDate()).inDays;

        // Son 30 gün içinde eklenen arkadaşları göster
        if (daysSinceAdded <= 30) {
          activities.add({
            'type': 'friendship',
            'friend': friend,
            'timestamp': friendshipDate,
          });
        }
      }
    }

    // Ortak turnuva aktiviteleri
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        final tournaments = await FirebaseFirestore.instance
            .collection('tournaments')
            .where('participants', arrayContains: currentUserId)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();

        for (final tournamentDoc in tournaments.docs) {
          final tournamentData = tournamentDoc.data();
          final participants =
              List<String>.from(tournamentData['participants'] ?? []);

          // Bu turnuvada arkadaşlarım var mı kontrol et
          final friendIds = friends.map((f) => f['userId'] as String).toSet();
          final commonFriends =
              participants.where((p) => friendIds.contains(p)).toList();

          if (commonFriends.isNotEmpty) {
            activities.add({
              'type': 'tournament',
              'tournament': tournamentData,
              'tournamentId': tournamentDoc.id,
              'commonFriends': commonFriends,
              'timestamp': tournamentData['createdAt'] as Timestamp?,
            });
          }
        }
      }
    } catch (e) {
      print('Turnuva aktiviteleri yüklenirken hata: $e');
    }

    // Zamana göre sırala (en yeni ilk)
    activities.sort((a, b) {
      final timestampA = a['timestamp'] as Timestamp?;
      final timestampB = b['timestamp'] as Timestamp?;

      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1;
      if (timestampB == null) return -1;

      return timestampB.compareTo(timestampA);
    });

    return activities.take(15).toList(); // Son 15 aktiviteyi göster
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final activityType = activity['type'] as String;
    final timestamp = activity['timestamp'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: StyledCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activityType == 'friendship')
                _buildFriendshipActivity(activity, timestamp)
              else if (activityType == 'tournament')
                _buildTournamentActivity(activity, timestamp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendshipActivity(
      Map<String, dynamic> activity, Timestamp? timestamp) {
    final friend = activity['friend'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              child: Icon(
                Icons.person_add,
                color: Colors.blue[600],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: friend['username'] ?? 'Bilinmeyen Kullanıcı',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' arkadaş olarak eklendi'),
                      ],
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      _formatActivityDate(timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.handshake,
                color: Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Artık turnuvalarda birlikte yarışabilirsiniz!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue[700],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentActivity(
      Map<String, dynamic> activity, Timestamp? timestamp) {
    final tournament = activity['tournament'] as Map<String, dynamic>;
    final commonFriends = activity['commonFriends'] as List<String>;
    final tournamentName = tournament['name'] as String? ?? 'Adsız Turnuva';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.orange.withValues(alpha: 0.1),
              child: Icon(
                Icons.emoji_events,
                color: Colors.orange[600],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournamentName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${commonFriends.length} arkadaşınızla ortak turnuva',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                  if (timestamp != null)
                    Text(
                      _formatActivityDate(timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.orange[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${commonFriends.length} ortak katılımcı',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Colors.orange[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tournament['status'] == 'active'
                              ? 'Aktif'
                              : tournament['status'] == 'completed'
                                  ? 'Tamamlandı'
                                  : 'Beklemede',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[700],
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  // Turnuvalar sayfasına git
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TournamentsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Görüntüle'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatActivityDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Arkadaşlık isteğini kabul et
  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      await _friendshipService.acceptFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arkadaşlık isteği kabul edildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İstek kabul edilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Arkadaşlık isteğini reddet
  Future<void> _declineFriendRequest(String requestId) async {
    try {
      await _friendshipService.declineFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arkadaşlık isteği reddedildi'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İstek reddedilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Arkadaşlık isteğini iptal et
  Future<void> _cancelFriendRequest(String requestId) async {
    try {
      await _friendshipService.cancelFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arkadaşlık isteği iptal edildi'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İstek iptal edilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Arkadaşı çıkarma onayı
  void _showRemoveFriendDialog(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arkadaşlıktan Çıkar'),
        content: Text(
          '${friend['username']} kullanıcısını arkadaş listenizden çıkarmak istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeFriend(friend['userId'], friend['username']);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
  }

  // Arkadaşı çıkar
  Future<void> _removeFriend(String friendUserId, String friendUsername) async {
    try {
      await _friendshipService.removeFriend(friendUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$friendUsername arkadaş listenizden çıkarıldı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arkadaş çıkarılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// KeepAlive wrapper for maintaining tab state
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({super.key, required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
