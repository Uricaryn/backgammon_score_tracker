import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewGamePlayerSelector extends StatefulWidget {
  final String? selectedPlayer1;
  final String? selectedPlayer2;
  final bool isGuestUser;
  final Function(String?, String?) onPlayersChanged;

  const NewGamePlayerSelector({
    super.key,
    this.selectedPlayer1,
    this.selectedPlayer2,
    required this.isGuestUser,
    required this.onPlayersChanged,
  });

  @override
  State<NewGamePlayerSelector> createState() => _NewGamePlayerSelectorState();
}

class _NewGamePlayerSelectorState extends State<NewGamePlayerSelector> {
  final _firebaseService = FirebaseService();
  final _guestDataService = GuestDataService();

  // ✅ Cached player names for performance
  List<String>? _cachedPlayerNames;
  bool _needsRefresh = true;

  @override
  void initState() {
    super.initState();
    _loadPlayerNames();
  }

  Future<void> _loadPlayerNames() async {
    if (!_needsRefresh && _cachedPlayerNames != null) return;

    try {
      List<String> playerNames = [];

      if (widget.isGuestUser) {
        final players = await _guestDataService.getGuestPlayers();
        playerNames =
            players.map((player) => player['name'] as String).toList();
      } else {
        // Use stream for real-time updates
        // But cache locally to avoid rebuilds
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) return;

        final snapshot = await FirebaseFirestore.instance
            .collection('players')
            .where('userId', isEqualTo: userId)
            .get();

        playerNames =
            snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      }

      if (mounted) {
        setState(() {
          _cachedPlayerNames = playerNames;
          _needsRefresh = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading player names: $e');
    }
  }

  // ✅ Optimized player selection
  void _selectPlayer(String playerName) {
    String? newPlayer1 = widget.selectedPlayer1;
    String? newPlayer2 = widget.selectedPlayer2;

    if (widget.selectedPlayer1 == playerName) {
      newPlayer1 = null;
    } else if (widget.selectedPlayer2 == playerName) {
      newPlayer2 = null;
    } else if (widget.selectedPlayer1 == null) {
      newPlayer1 = playerName;
    } else if (widget.selectedPlayer2 == null &&
        widget.selectedPlayer1 != playerName) {
      newPlayer2 = playerName;
    }

    // ✅ Only call if changed
    if (newPlayer1 != widget.selectedPlayer1 ||
        newPlayer2 != widget.selectedPlayer2) {
      widget.onPlayersChanged(newPlayer1, newPlayer2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildPlayerContent(),
              const SizedBox(height: 16),
              _buildAddPlayerButton(),
            ],
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Oyuncu Seçimi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerContent() {
    if (_cachedPlayerNames == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_cachedPlayerNames!.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Players Quick Selection
        if (_cachedPlayerNames!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Son Oyuncular',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                _PlayerChipsWidget(
                  playerNames: _cachedPlayerNames!.take(4).toList(),
                  selectedPlayer1: widget.selectedPlayer1,
                  selectedPlayer2: widget.selectedPlayer2,
                  onPlayerSelected: _selectPlayer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Dropdown Selection
        _buildDropdownSelectors(),
      ],
    );
  }

  Widget _buildDropdownSelectors() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: widget.selectedPlayer1,
            decoration: InputDecoration(
              labelText: '1. Oyuncu',
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            items: _cachedPlayerNames!
                .map((player) => DropdownMenuItem(
                      value: player,
                      child: Text(
                        player,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ))
                .toList(),
            onChanged: (value) => _selectPlayer(value ?? ''),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: widget.selectedPlayer2,
            decoration: InputDecoration(
              labelText: '2. Oyuncu',
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            items: _cachedPlayerNames!
                .map((player) => DropdownMenuItem(
                      value: player,
                      child: Text(
                        player,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ))
                .toList(),
            onChanged: (value) => _selectPlayer(value ?? ''),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz oyuncu eklenmemiş',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aşağıdaki "Yeni Oyuncu Ekle" butonunu kullanarak ilk oyuncunuzu ekleyin.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddPlayerButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showQuickAddPlayerDialog,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Oyuncu Ekle'),
      ),
    );
  }

  Future<void> _showQuickAddPlayerDialog() async {
    final TextEditingController nameController = TextEditingController();
    final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hızlı Oyuncu Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: errorText,
              builder: (context, error, child) {
                return TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Oyuncu Adı',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                  autofocus: true,
                  onSubmitted: (value) async {
                    final validation =
                        ValidationService.validatePlayerName(value.trim());
                    if (validation != null) {
                      errorText.value = validation;
                      return;
                    }
                    errorText.value = null;
                    await _addPlayer(value.trim());
                  },
                );
              },
            ),
            if (widget.isGuestUser) ...[
              const SizedBox(height: 8),
              Text(
                'Misafir kullanıcı olarak oyuncu yerel olarak kaydedilecek',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final validation = ValidationService.validatePlayerName(name);
              if (validation != null) {
                errorText.value = validation;
                return;
              }
              errorText.value = null;
              await _addPlayer(name);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPlayer(String name) async {
    try {
      if (widget.isGuestUser) {
        await _guestDataService.saveGuestPlayer(name);
      } else {
        await _firebaseService.savePlayer(name);
      }

      if (mounted) {
        Navigator.pop(context);
        _needsRefresh = true;
        await _loadPlayerNames();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isGuestUser
                ? 'Oyuncu yerel olarak eklendi!'
                : 'Oyuncu eklendi!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

// ✅ Separate widget for player chips to avoid rebuilding everything
class _PlayerChipsWidget extends StatelessWidget {
  final List<String> playerNames;
  final String? selectedPlayer1;
  final String? selectedPlayer2;
  final Function(String) onPlayerSelected;

  const _PlayerChipsWidget({
    required this.playerNames,
    this.selectedPlayer1,
    this.selectedPlayer2,
    required this.onPlayerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: playerNames.map((player) {
        final isSelected1 = selectedPlayer1 == player;
        final isSelected2 = selectedPlayer2 == player;
        final isSelected = isSelected1 || isSelected2;

        return FilterChip(
          label: Text(player),
          selected: isSelected,
          onSelected: (selected) => onPlayerSelected(player),
        );
      }).toList(),
    );
  }
}
