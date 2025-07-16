import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_match_list_card.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final _scrollController = ScrollController();
  final _firebaseService = FirebaseService();
  final _guestDataService = GuestDataService();

  bool _isLoading = false;
  bool _isGuestUser = false;
  Map<String, dynamic>? _cachedGameData;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _checkUserType();
    _loadMatchHistory();
  }

  void _checkUserType() {
    _isGuestUser = _firebaseService.isCurrentUserGuest();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchHistory() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_isGuestUser) {
        await _loadGuestGames();
      } else {
        await _loadFirebaseGames();
      }
    } catch (e) {
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

  Future<void> _loadGuestGames() async {
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
  }

  Future<void> _loadFirebaseGames() async {
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
        await _loadFirebaseGames();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Geçmişi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMatchHistory,
          ),
        ],
      ),
      body: Stack(
        children: [
          BackgroundBoard(
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadMatchHistory,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: HomeMatchListCard(
                            cachedGameData: _cachedGameData,
                            isGuestUser: _isGuestUser,
                            scrollController: _scrollController,
                            onDeleteGame: _deleteGame,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
