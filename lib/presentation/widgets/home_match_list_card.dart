import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/presentation/screens/edit_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/widgets/match_details_dialog.dart';

class HomeMatchListCard extends StatelessWidget {
  final Map<String, dynamic>? cachedGameData;
  final bool isGuestUser;
  final ScrollController scrollController;
  final Function(String) onDeleteGame;

  const HomeMatchListCard({
    super.key,
    required this.cachedGameData,
    required this.isGuestUser,
    required this.scrollController,
    required this.onDeleteGame,
  });

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
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildMatchList(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.history,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Maç Geçmişi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchList(BuildContext context) {
    if (cachedGameData != null) {
      final games = cachedGameData!['data'] as List<Map<String, dynamic>>;
      if (games.isEmpty) {
        return _buildEmptyState(context);
      }

      return Container(
        constraints: const BoxConstraints(maxHeight: 400),
        child: ListView.builder(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          itemCount: games.length,
          // ✅ Add caching for better performance
          cacheExtent: 200.0,
          itemBuilder: (context, index) {
            final data = games[index];
            return _MatchListItem(
              gameData: data,
              onDeleteGame: onDeleteGame,
            );
          },
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Henüz maç kaydı yok'),
          if (isGuestUser) ...[
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

// ✅ Separate match item widget for better performance
class _MatchListItem extends StatelessWidget {
  final Map<String, dynamic> gameData;
  final Function(String) onDeleteGame;

  const _MatchListItem({
    required this.gameData,
    required this.onDeleteGame,
  });

  @override
  Widget build(BuildContext context) {
    final player1 = gameData['player1'] as String;
    final player2 = gameData['player2'] as String;
    final player1Score = gameData['player1Score'] as int;
    final player2Score = gameData['player2Score'] as int;
    final timestamp = gameData['timestamp'] is Timestamp
        ? (gameData['timestamp'] as Timestamp).toDate()
        : DateTime.parse(gameData['timestamp'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // ✅ Lighter styling for better performance
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        // ✅ Reduced shadow for better performance
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
        trailing: _buildActions(context),
        onTap: () => _showMatchDetails(
            context, player1, player2, player1Score, player2Score, timestamp),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => _navigateToEditGame(context),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _showDeleteDialog(context),
          ),
        ),
      ],
    );
  }

  void _navigateToEditGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditGameScreen(
          gameId: gameData['id'] as String,
          player1: gameData['player1'] as String,
          player2: gameData['player2'] as String,
          player1Score: gameData['player1Score'] as int,
          player2Score: gameData['player2Score'] as int,
        ),
      ),
    );
  }

  void _showMatchDetails(BuildContext context, String player1, String player2,
      int player1Score, int player2Score, DateTime timestamp) {
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
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maçı Sil'),
        content: const Text('Bu maçı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteGame(gameData['id'] as String);
            },
            child: Text(
              'Sil',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
