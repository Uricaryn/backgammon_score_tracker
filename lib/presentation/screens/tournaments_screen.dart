import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/tournament_service.dart';
import 'package:backgammon_score_tracker/core/services/friendship_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_card.dart';
import 'package:backgammon_score_tracker/presentation/screens/tournament_detail_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/premium_upgrade_screen.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';

class TournamentsScreen extends StatefulWidget {
  final int? initialTab;

  const TournamentsScreen({
    super.key,
    this.initialTab,
  });

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TournamentService _tournamentService = TournamentService();
  final PremiumService _premiumService = PremiumService();

  bool _isGuestUser = false;
  Future<bool>? _premiumAccessFuture;
  StreamSubscription<bool>? _premiumActivatedSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );
    _premiumAccessFuture = _premiumService.hasPremiumAccess();
    _premiumActivatedSub =
        _premiumService.premiumActivatedStream.listen((active) {
      if (active && mounted) {
        setState(() {
          _premiumAccessFuture = _premiumService.hasPremiumAccess();
        });
      }
    });
    _checkUserType();
  }

  void _refreshPremiumAccessFuture() {
    setState(() {
      _premiumAccessFuture = _premiumService.hasPremiumAccess();
    });
  }

  void _checkUserType() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isGuestUser = user?.isAnonymous ?? true;
    });
  }

  @override
  void dispose() {
    _premiumActivatedSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuestUser) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Turnuvalar'),
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
                      Icons.emoji_events_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Turnuva Özelliği',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Turnuva oluşturma ve katılma özelliği için hesap oluşturmanız gerekiyor.',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnuvalar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Tab genişliklerini hesapla ve scrollable olup olmayacağını belirle
                final availableWidth = constraints.maxWidth;

                // Tab metinlerinin tahmini genişlikleri
                final tabTexts = ['Kişisel', 'Sosyal', 'Davetler', 'Oluştur'];
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
                    Tab(icon: Icon(Icons.person), text: 'Kişisel'),
                    Tab(icon: Icon(Icons.group), text: 'Sosyal'),
                    Tab(icon: Icon(Icons.mail), text: 'Davetler'),
                    Tab(icon: Icon(Icons.add), text: 'Oluştur'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPersonalTournamentsTab(),
              _buildSocialTournamentsTab(),
              _buildInvitationsTab(),
              _buildCreateTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalTournamentsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _tournamentService.getTournaments(
          category: TournamentService.tournamentCategoryPersonal),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
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

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty) {
          return Center(
            child: StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz Kişisel Turnuva Yok',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz hiç kişisel turnuva oluşturmadınız. Kendi oyuncularınızla turnuva düzenleyin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        _tabController.animateTo(3); // Oluştur sekmesine git
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Kişisel Turnuva Oluştur'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tournaments.length,
          itemBuilder: (context, index) {
            final tournament = tournaments[index];
            return _buildTournamentCard(tournament);
          },
        );
      },
    );
  }

  Widget _buildSocialTournamentsTab() {
    return FutureBuilder<bool>(
      future: _premiumAccessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasPremium = snapshot.data ?? false;

        if (!hasPremium) {
          return Center(
            child: StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 64,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Premium Gerekli',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sosyal turnuva özelliği için Premium\'a yükseltmeniz gerekiyor.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final activated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PremiumUpgradeScreen(source: 'tournaments'),
                          ),
                        );
                        if (activated == true && mounted) {
                          _refreshPremiumAccessFuture();
                        }
                      },
                      icon: const Icon(Icons.star),
                      label: const Text('Premium\'a Yükselt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _tournamentService.getTournaments(
              category: TournamentService.tournamentCategorySocial),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
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

            final tournaments = snapshot.data ?? [];

            if (tournaments.isEmpty) {
              return Center(
                child: StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz Sosyal Turnuva Yok',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz hiç sosyal turnuvaya katılmadınız. Arkadaşlarınızla turnuva oluşturun veya davetlerini bekleyin.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            _tabController
                                .animateTo(3); // Oluştur sekmesine git
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Sosyal Turnuva Oluştur'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                return _buildTournamentCard(tournament);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    final statusColor = _getTournamentStatusColor(tournament['status']);
    final statusText = _getTournamentStatusText(tournament['status']);
    final typeText = _getTournamentTypeText(tournament['type']);

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (tournament['description'].isNotEmpty)
                        Text(
                          tournament['description'],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (tournament['isCreator']) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Yaratıcı',
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                if (tournament['isCreator'] &&
                    tournament['status'] ==
                        TournamentService.tournamentPending) ...[
                  ElevatedButton.icon(
                    onPressed: () => _startTournament(tournament['id']),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Başlat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (tournament['status'] ==
                    TournamentService.tournamentActive) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openTournamentDetails(tournament),
                    icon: const Icon(Icons.emoji_events, size: 16),
                    label: const Text('Maçlar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (tournament['status'] ==
                    TournamentService.tournamentCompleted) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openTournamentDetails(tournament),
                    icon: const Icon(Icons.emoji_events, size: 16),
                    label: const Text('Sonuçlar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _tournamentService.getTournamentInvitations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
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

        final invitations = snapshot.data ?? [];

        if (invitations.isEmpty) {
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
                      'Gelen Davet Yok',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz size turnuva daveti gönderen arkadaşınız yok.',
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
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final invitation = invitations[index];
            return _buildInvitationCard(invitation);
          },
        );
      },
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation) {
    final typeText = _getTournamentTypeText(invitation['tournamentType']);

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    invitation['fromUserName'].isNotEmpty
                        ? invitation['fromUserName'][0].toUpperCase()
                        : 'K',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation['fromUserName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Size turnuva daveti gönderdi',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Bekliyor',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          invitation['tournamentName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tip: $typeText',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Katılımcı: ${invitation['participantCount']}/${invitation['maxParticipants']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (invitation['tournamentDescription'].isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      invitation['tournamentDescription'],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _acceptInvitation(invitation['id']),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Kabul Et'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _declineInvitation(invitation['id']),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return FutureBuilder<bool>(
      future: _premiumAccessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasPremium = snapshot.data ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              StyledCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Yeni Turnuva Oluştur',
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
                      Text(
                        'İki türde turnuva oluşturabilirsiniz: Kendi oyuncularınızla kişisel turnuvalar veya arkadaşlarınızla sosyal turnuvalar.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () =>
                            _showCreateTournamentDialog(isPersonal: true),
                        icon: const Icon(Icons.person),
                        label: const Text('Kişisel Turnuva Oluştur'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (hasPremium)
                        FilledButton.icon(
                          onPressed: () =>
                              _showCreateTournamentDialog(isPersonal: false),
                          icon: const Icon(Icons.group),
                          label: const Text('Sosyal Turnuva Oluştur'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.green,
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.amber[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sosyal Turnuva (Premium Gerekli)',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StyledCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Turnuva Tipleri',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTournamentTypeInfo(
                        'Eleme Turnuvası',
                        'Klasik eleme sistemi. Kaybeden elenir.',
                        Icons.filter_list,
                        Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _buildTournamentTypeInfo(
                        'Round Robin',
                        'Herkes herkesle oynar. En çok kazanan birinci.',
                        Icons.sync,
                        Colors.blue,
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

  Widget _buildTournamentTypeInfo(
      String title, String description, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getTournamentStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTournamentStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Bekliyor';
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Bitti';
      case 'cancelled':
        return 'İptal';
      default:
        return 'Bilinmeyen';
    }
  }

  String _getTournamentTypeText(String type) {
    switch (type) {
      case 'elimination':
        return 'Eleme';
      case 'round_robin':
        return 'Round Robin';
      default:
        return 'Bilinmeyen';
    }
  }

  void _showCreateTournamentDialog({required bool isPersonal}) {
    showDialog(
      context: context,
      builder: (context) => _CreateTournamentDialog(
        isPersonal: isPersonal,
        onTournamentCreated: (tournamentId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turnuva başarıyla oluşturuldu!'),
              backgroundColor: Colors.green,
            ),
          );
          _tabController.animateTo(isPersonal ? 0 : 1); // Uygun sekmeye git
        },
      ),
    );
  }

  Future<void> _startTournament(String tournamentId) async {
    try {
      await _tournamentService.startTournament(tournamentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnuva başlatıldı!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnuva başlatılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openTournamentDetails(Map<String, dynamic> tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentDetailScreen(tournament: tournament),
      ),
    );
  }

  Future<void> _acceptInvitation(String invitationId) async {
    try {
      await _tournamentService.acceptTournamentInvitation(invitationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnuva davetini kabul ettiniz!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Davet kabul edilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineInvitation(String invitationId) async {
    try {
      await _tournamentService.declineTournamentInvitation(invitationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnuva davetini reddettiniz'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Davet reddedilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CreateTournamentDialog extends StatefulWidget {
  final Function(String) onTournamentCreated;
  final bool isPersonal;

  const _CreateTournamentDialog({
    required this.onTournamentCreated,
    required this.isPersonal,
  });

  @override
  State<_CreateTournamentDialog> createState() =>
      _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<_CreateTournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TournamentService _tournamentService = TournamentService();
  final FriendshipService _friendshipService = FriendshipService();

  String _selectedType = TournamentService.tournamentTypeElimination;
  int _maxParticipants = 4;
  List<Map<String, dynamic>> _friends = [];
  final List<String> _selectedFriends = [];
  List<Map<String, dynamic>> _players = [];
  final List<String> _selectedPlayers = [];
  bool _isLoading = false;
  bool _isLoadingFriends = false;
  bool _isLoadingPlayers = false;
  bool _isOnline = false;
  String _scoringMode = TournamentService.scoringModeSimple;
  int _targetScore = 5;
  StreamSubscription? _friendsSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.isPersonal) {
      _loadPlayers();
    } else {
      _loadFriends();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _friendsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;

    setState(() {
      _isLoadingFriends = true;
    });

    try {
      final friendsStream = _friendshipService.getFriends();
      _friendsSubscription = friendsStream.listen(
        (friends) {
          if (mounted) {
            setState(() {
              _friends = friends;
              _isLoadingFriends = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoadingFriends = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _loadPlayers() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPlayers = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final playersSnapshot = await FirebaseFirestore.instance
          .collection('players')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      if (mounted) {
        setState(() {
          _players = playersSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _isLoadingPlayers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlayers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔵 Dialog build - isLoadingFriends: $_isLoadingFriends, friends count: ${_friends.length}');
    debugPrint(
        '🔵 Selected type: $_selectedType, max participants: $_maxParticipants');
    debugPrint('🔵 Form key: $_formKey');

    return AlertDialog(
      title: Text(widget.isPersonal
          ? 'Yeni Kişisel Turnuva Oluştur'
          : 'Yeni Sosyal Turnuva Oluştur'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Turnuva Adı',
                    hintText: 'Örn: Arkadaşlar Turnuvası',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Turnuva adı gereklidir';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (İsteğe Bağlı)',
                    hintText: 'Turnuva hakkında kısa açıklama',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Turnuva Tipi',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'elimination',
                      child: Text('Eleme Turnuvası'),
                    ),
                    DropdownMenuItem(
                      value: 'round_robin',
                      child: Text('Round Robin'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _maxParticipants,
                  decoration: const InputDecoration(
                    labelText: 'Maksimum Katılımcı',
                  ),
                  items: _getMaxParticipantsItems(),
                  onChanged: (value) {
                    setState(() {
                      _maxParticipants = value!;
                    });
                  },
                ),
                if (!widget.isPersonal) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Online Turnuva'),
                    subtitle: const Text(
                      'Maclar canli tavla odasinda oynanir',
                    ),
                    value: _isOnline,
                    onChanged: (v) => setState(() => _isOnline = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isOnline) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _scoringMode,
                      decoration: const InputDecoration(
                        labelText: 'Puanlama Modu',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'simple',
                          child: Text('Basit (Her oyun 1 puan)'),
                        ),
                        DropdownMenuItem(
                          value: 'backgammon',
                          child: Text(
                              'Tavla Kurallari (Normal:1, Mars:2, Kapi:3)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _scoringMode = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _targetScore,
                      decoration: const InputDecoration(
                        labelText: 'Hedef Puan',
                      ),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 Puan')),
                        DropdownMenuItem(value: 5, child: Text('5 Puan')),
                        DropdownMenuItem(value: 7, child: Text('7 Puan')),
                        DropdownMenuItem(value: 11, child: Text('11 Puan')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _targetScore = v);
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                if (widget.isPersonal) ...[
                  // Kişisel turnuva - oyuncu seçimi
                  if (_isLoadingPlayers)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Oyuncular yükleniyor...'),
                      ],
                    )
                  else if (_players.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Turnuvaya Katılacak Oyuncular:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _players.length,
                        itemBuilder: (context, index) {
                          final player = _players[index];
                          final isSelected =
                              _selectedPlayers.contains(player['id']);
                          final canSelect =
                              _selectedPlayers.length < _maxParticipants ||
                                  isSelected;

                          return CheckboxListTile(
                            title: Text(player['name'] ?? 'Bilinmeyen'),
                            subtitle: Text(
                                'Toplam Skor: ${player['totalScore'] ?? 0}'),
                            value: isSelected,
                            enabled: canSelect,
                            onChanged: canSelect
                                ? (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedPlayers.add(player['id']);
                                      } else {
                                        _selectedPlayers.remove(player['id']);
                                      }
                                    });
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Seçilen: ${_selectedPlayers.length}/$_maxParticipants oyuncu',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Henüz oyuncunuz yok.\nÖnce oyuncu oluşturmalısınız.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ] else ...[
                  // Sosyal turnuva - arkadaş seçimi
                  if (_isLoadingFriends)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Arkadaşlar yükleniyor...'),
                      ],
                    )
                  else if (_friends.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Davet Edilecek Arkadaşlar:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final isSelected =
                              _selectedFriends.contains(friend['userId']);

                          return CheckboxListTile(
                            title: Text(friend['username'] ?? 'Bilinmeyen'),
                            subtitle: Text(friend['email'] ?? ''),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedFriends.add(friend['userId']);
                                } else {
                                  _selectedFriends.remove(friend['userId']);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Henüz arkadaşınız yok.\nTurnuvayı sadece kendiniz için oluşturacaksınız.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _createTournament,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Oluştur'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<int>> _getMaxParticipantsItems() {
    if (_selectedType == TournamentService.tournamentTypeElimination) {
      return const [
        DropdownMenuItem(value: 2, child: Text('2 Katılımcı')),
        DropdownMenuItem(value: 4, child: Text('4 Katılımcı')),
        DropdownMenuItem(value: 8, child: Text('8 Katılımcı')),
        DropdownMenuItem(value: 16, child: Text('16 Katılımcı')),
      ];
    } else {
      return List.generate(9, (index) {
        final count = index + 2;
        return DropdownMenuItem(
          value: count,
          child: Text('$count Katılımcı'),
        );
      });
    }
  }

  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tournamentId = await _tournamentService.createTournament(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        category: widget.isPersonal
            ? TournamentService.tournamentCategoryPersonal
            : TournamentService.tournamentCategorySocial,
        maxParticipants: _maxParticipants,
        invitedFriends: widget.isPersonal ? null : _selectedFriends,
        selectedPlayers: widget.isPersonal ? _selectedPlayers : null,
        isOnline: _isOnline,
        scoringMode: _scoringMode,
        targetScore: _targetScore,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onTournamentCreated(tournamentId);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        if (errorMessage.contains('PREMIUM_REQUIRED:')) {
          // Premium gerekli dialog'u göster
          _showPremiumRequiredDialog('Sosyal Turnuva Oluşturma');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Turnuva oluşturulamadı: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PremiumUpgradeScreen(source: 'tournaments'),
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
}
