import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:backgammon_score_tracker/core/controllers/tournament_detail_controller.dart';
import 'package:backgammon_score_tracker/presentation/widgets/home_scoreboard_card.dart';

class TournamentScoreboardTab extends StatefulWidget {
  const TournamentScoreboardTab({
    super.key,
    required this.controller,
    required this.screenshotController,
    required this.convertMatches,
    required this.onShare,
    required this.onPlayerTap,
  });

  final TournamentDetailController controller;
  final ScreenshotController screenshotController;
  final Future<Map<String, dynamic>> Function({
    required List<Map<String, dynamic>> completedMatches,
    required List<Map<String, dynamic>> allMatches,
    required List<String> participants,
    required String? tournamentCategory,
  }) convertMatches;
  final VoidCallback onShare;
  final ValueChanged<String> onPlayerTap;

  @override
  State<TournamentScoreboardTab> createState() =>
      _TournamentScoreboardTabState();
}

class _TournamentScoreboardTabState extends State<TournamentScoreboardTab> {
  Future<Map<String, dynamic>>? _gameDataFuture;
  int _matchesVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refreshGameData);
    _refreshGameData();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshGameData);
    super.dispose();
  }

  void _refreshGameData() {
    final controller = widget.controller;
    if (controller.tournamentLoading ||
        controller.matchesLoading ||
        controller.tournamentData == null) {
      return;
    }

    final version = controller.matches.length;
    if (_gameDataFuture != null && version == _matchesVersion) {
      return;
    }

    _matchesVersion = version;
    _gameDataFuture = widget.convertMatches(
      completedMatches: controller.completedMatches,
      allMatches: controller.matches,
      participants: controller.participants,
      tournamentCategory: controller.tournamentData?['category'] as String?,
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.tournamentLoading ||
            widget.controller.matchesLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (widget.controller.tournamentError != null) {
          return Center(
            child: Text('Hata: ${widget.controller.tournamentError}'),
          );
        }

        if (widget.controller.matchesError != null) {
          return Center(
            child: Text('Hata: ${widget.controller.matchesError}'),
          );
        }

        if (widget.controller.tournamentData == null) {
          return const Center(child: Text('Turnuva bulunamadı'));
        }

        final future = _gameDataFuture;
        if (future == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            final gameData = snapshot.data ??
                {
                  'data': [],
                  'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                };

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HomeScoreboardCard(
                cachedGameData: gameData,
                isGuestUser: false,
                screenshotController: widget.screenshotController,
                onShare: widget.onShare,
                onPlayerTap: widget.onPlayerTap,
              ),
            );
          },
        );
      },
    );
  }
}
