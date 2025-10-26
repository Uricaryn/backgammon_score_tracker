import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_container.dart';
import 'package:backgammon_score_tracker/core/services/match_challenge_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendDetailScreen extends StatefulWidget {
  final Map<String, dynamic> friend;

  const FriendDetailScreen({
    super.key,
    required this.friend,
  });

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen>
    with SingleTickerProviderStateMixin {
  final MatchChallengeService _challengeService = MatchChallengeService();
  final LogService _logService = LogService();

  late TabController _tabController;
  List<Map<String, dynamic>> _sharedTournaments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriendData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Ortak turnuvaları getir
      final sharedTournaments = await _getSharedTournaments();

      setState(() {
        _sharedTournaments = sharedTournaments;
        _isLoading = false;
      });
    } catch (e) {
      _logService.error('Failed to load friend data',
          tag: 'FriendDetail', error: e);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Ortak turnuvaları getir
  Future<List<Map<String, dynamic>>> _getSharedTournaments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Her iki kullanıcının da katıldığı turnuvaları bul
      // ✅ Limit ekle - son 20 ortak turnuva
      final snapshot = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('participants', arrayContains: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final sharedTournaments = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as List<dynamic>? ?? [];

        // Arkadaş da bu turnuvada mı kontrol et
        if (participants.contains(widget.friend['userId'])) {
          // Yaratıcı bilgilerini al
          final createdByDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['createdBy'])
              .get();

          final createdByData = createdByDoc.exists ? createdByDoc.data()! : {};

          sharedTournaments.add({
            'id': doc.id,
            'name': data['name'],
            'description': data['description'],
            'type': data['type'],
            'status': data['status'],
            'maxParticipants': data['maxParticipants'],
            'participantCount': participants.length,
            'createdBy': data['createdBy'],
            'createdByName': createdByData['username'] ?? 'Bilinmeyen',
            'createdAt': data['createdAt'],
            'startDate': data['startDate'],
            'participants': participants,
          });
        }
      }

      // En yeni turnuvalar önce
      sharedTournaments.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return sharedTournaments;
    } catch (e) {
      _logService.error('Failed to get shared tournaments',
          tag: 'FriendDetail', error: e);
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundBoard(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        widget.friend['username'] != null &&
                                (widget.friend['username'] as String).isNotEmpty
                            ? (widget.friend['username'] as String)[0]
                                .toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.friend['username'] ?? 'Arkadaş',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            widget.friend['email'] ?? '',
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
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 16,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Arkadaş',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Maç daveti butonu kaldırıldı
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Theme.of(context).colorScheme.onPrimary,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tabs: const [
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Profil'),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Ortak Turnuvalar'),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar View
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _buildErrorWidget()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildProfileTab(),
                                _buildTournamentsTab(),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: StyledContainer(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Veriler yüklenemedi',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFriendData,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Arkadaş Bilgileri
          StyledContainer(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Arkadaş Bilgileri',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Kullanıcı Adı',
                      widget.friend['username'] ?? 'Bilinmeyen'),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                      'E-posta', widget.friend['email'] ?? 'Bilinmeyen'),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                      'Ortak Turnuvalar', '${_sharedTournaments.length} adet'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Turnuva İstatistikleri
          StyledContainer(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Turnuva Özeti',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_sharedTournaments.isEmpty)
                    Text(
                      'Henüz ortak turnuvanız yok. İlk turnuvayı oluşturmak için Turnuvalar bölümüne gidin!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                      textAlign: TextAlign.center,
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Toplam Turnuva',
                            _sharedTournaments.length.toString(),
                            Icons.emoji_events,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Aktif Turnuva',
                            _sharedTournaments
                                .where((t) => t['status'] == 'active')
                                .length
                                .toString(),
                            Icons.play_circle,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Bekleyen',
                            _sharedTournaments
                                .where((t) => t['status'] == 'pending')
                                .length
                                .toString(),
                            Icons.hourglass_empty,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Tamamlanan',
                            _sharedTournaments
                                .where((t) => t['status'] == 'completed')
                                .length
                                .toString(),
                            Icons.check_circle,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab() {
    if (_sharedTournaments.isEmpty) {
      return Center(
        child: StyledContainer(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ortak Turnuva Yok',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu arkadaşınızla henüz ortak bir turnuvanız bulunmuyor. Yeni bir turnuva oluşturup arkadaşınızı davet edebilirsiniz.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/tournaments'),
                  icon: const Icon(Icons.add),
                  label: const Text('Turnuva Oluştur'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _sharedTournaments.length,
      itemBuilder: (context, index) {
        final tournament = _sharedTournaments[index];
        return _buildTournamentCard(tournament);
      },
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    final status = tournament['status'] as String;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Bekliyor';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'active':
        statusColor = Colors.green;
        statusText = 'Aktif';
        statusIcon = Icons.play_circle;
        break;
      case 'completed':
        statusColor = Colors.purple;
        statusText = 'Tamamlandı';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Bilinmeyen';
        statusIcon = Icons.help;
    }

    final typeText =
        tournament['type'] == 'elimination' ? 'Eleme' : 'Round Robin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: StyledContainer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tournament['name'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (tournament['description'] != null &&
                  tournament['description'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  tournament['description'],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tip: $typeText',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Katılımcı: ${tournament['participantCount']}/${tournament['maxParticipants']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Yaratıcı: ${tournament['createdByName']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/tournaments'),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Detay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
