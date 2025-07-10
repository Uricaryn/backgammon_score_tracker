import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/presentation/widgets/player_stats_dialog.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';

class HomeScoreboardCard extends StatefulWidget {
  final Map<String, dynamic>? cachedGameData;
  final bool isGuestUser;
  final ScreenshotController screenshotController;
  final VoidCallback onShare;

  const HomeScoreboardCard({
    super.key,
    required this.cachedGameData,
    required this.isGuestUser,
    required this.screenshotController,
    required this.onShare,
  });

  @override
  State<HomeScoreboardCard> createState() => _HomeScoreboardCardState();
}

class _HomeScoreboardCardState extends State<HomeScoreboardCard> {
  // ✅ Cached player statistics
  Map<String, int>? _cachedPlayerWins;
  Map<String, int>? _cachedPlayerGames;
  Map<String, double>? _cachedPlayerAverageScores;

  @override
  void didUpdateWidget(HomeScoreboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cachedGameData != widget.cachedGameData) {
      _invalidatePlayerStats();
    }
  }

  void _invalidatePlayerStats() {
    _cachedPlayerWins = null;
    _cachedPlayerGames = null;
    _cachedPlayerAverageScores = null;
  }

  void _calculatePlayerStats() {
    if (_cachedPlayerWins != null &&
        _cachedPlayerGames != null &&
        _cachedPlayerAverageScores != null) {
      return; // Use cached data
    }

    if (widget.cachedGameData == null) return;

    final games = widget.cachedGameData!['data'] as List<Map<String, dynamic>>;
    _cachedPlayerWins = {};
    _cachedPlayerGames = {};
    _cachedPlayerAverageScores = {};

    // Temporary storage for total scores to calculate averages
    Map<String, int> playerTotalScores = {};

    for (var data in games) {
      final player1 = data['player1'] as String;
      final player2 = data['player2'] as String;
      final player1Score = data['player1Score'] as int;
      final player2Score = data['player2Score'] as int;

      // Update game counts
      _cachedPlayerGames![player1] = (_cachedPlayerGames![player1] ?? 0) + 1;
      _cachedPlayerGames![player2] = (_cachedPlayerGames![player2] ?? 0) + 1;

      // Update total scores for average calculation
      playerTotalScores[player1] =
          (playerTotalScores[player1] ?? 0) + player1Score;
      playerTotalScores[player2] =
          (playerTotalScores[player2] ?? 0) + player2Score;

      // Update win counts
      if (player1Score > player2Score) {
        _cachedPlayerWins![player1] = (_cachedPlayerWins![player1] ?? 0) + 1;
      } else {
        _cachedPlayerWins![player2] = (_cachedPlayerWins![player2] ?? 0) + 1;
      }
    }

    // Calculate average scores
    for (var playerName in _cachedPlayerGames!.keys) {
      final totalScore = playerTotalScores[playerName] ?? 0;
      final totalGames = _cachedPlayerGames![playerName] ?? 1;
      _cachedPlayerAverageScores![playerName] = totalScore / totalGames;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            ],
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          // ✅ Removed BackdropFilter for better performance
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildScoreboardContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.leaderboard,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Skor Tablosu',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: widget.onShare,
          tooltip: 'Skor tablosunu paylaş',
        ),
      ],
    );
  }

  Widget _buildScoreboardContent() {
    return Screenshot(
      controller: widget.screenshotController,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _buildScoreboard(),
      ),
    );
  }

  Widget _buildScoreboard() {
    if (widget.cachedGameData != null) {
      final games =
          widget.cachedGameData!['data'] as List<Map<String, dynamic>>;
      if (games.isEmpty) {
        return _buildEmptyState();
      }

      // ✅ Use cached calculations
      _calculatePlayerStats();

      var sortedPlayers = _cachedPlayerWins!.entries.toList()
        ..sort((a, b) {
          final aWinRate = (_cachedPlayerWins![a.key] ?? 0) /
              (_cachedPlayerGames![a.key] ?? 1);
          final bWinRate = (_cachedPlayerWins![b.key] ?? 0) /
              (_cachedPlayerGames![b.key] ?? 1);

          // Primary sort: Win rate (higher is better)
          final winRateComparison = bWinRate.compareTo(aWinRate);

          // If win rates are equal, sort by average score (higher is better)
          if (winRateComparison == 0) {
            final aAvgScore = _cachedPlayerAverageScores![a.key] ?? 0.0;
            final bAvgScore = _cachedPlayerAverageScores![b.key] ?? 0.0;
            return bAvgScore.compareTo(aAvgScore);
          }

          return winRateComparison;
        });

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sortedPlayers.length; i++)
            _ScoreboardItem(
              player: sortedPlayers[i],
              index: i,
              totalGames: _cachedPlayerGames![sortedPlayers[i].key] ?? 0,
              averageScore:
                  _cachedPlayerAverageScores![sortedPlayers[i].key] ?? 0.0,
              isGuestUser: widget.isGuestUser,
            ),
        ],
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Henüz maç kaydı bulunmuyor'),
          if (widget.isGuestUser) ...[
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
}

// ✅ Separate scoreboard item widget for better performance
class _ScoreboardItem extends StatelessWidget {
  final MapEntry<String, int> player;
  final int index;
  final int totalGames;
  final double averageScore;
  final bool isGuestUser;

  const _ScoreboardItem({
    required this.player,
    required this.index,
    required this.totalGames,
    required this.averageScore,
    required this.isGuestUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: isGuestUser
            ? () => _showLoginRequired(context)
            : () => _showPlayerStats(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            // ✅ Lighter shadow for better performance
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Trophy icon for top players
              if (index < 3)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTrophyColor(index),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.key,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kazanma: ${player.value} / $totalGames • Ort. Skor: ${averageScore.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${((player.value / totalGames) * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTrophyColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _showLoginRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giriş Gerekli'),
        content: const Text(
            'İstatistikleri görüntülemek için giriş yapmanız gerekiyor'),
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
                  builder: (context) => const LoginScreen(showSignUp: true),
                ),
              );
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  void _showPlayerStats(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PlayerStatsDialog(playerName: player.key),
    );
  }
}
