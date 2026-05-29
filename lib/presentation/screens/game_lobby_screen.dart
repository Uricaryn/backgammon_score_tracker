import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:backgammon_score_tracker/core/models/active_live_game_summary.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/services/realtime_game_service.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final _service = RealtimeGameService();
  final _roomController = TextEditingController();
  bool _busy = false;

  Future<void> _openLiveGame(String roomId) async {
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      AppRouter.liveGame,
      arguments: {'roomId': roomId},
    );
  }

  Future<void> _confirmDeleteGame(ActiveLiveGameSummary game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oyunu sil'),
        content: Text(
          '${game.opponentName} ile oda ${game.roomId} kalici olarak silinsin mi?\n\n'
          'Bu islem geri alinamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteGame(game.roomId);
  }

  Future<void> _deleteGame(String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await _service.deleteUnfinishedGame(
        roomId: roomId,
        playerUid: user.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyun silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resumeGame(ActiveLiveGameSummary game) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await _service.resumeRoom(
        roomId: game.roomId,
        playerUid: user.uid,
        playerName: user.displayName ?? user.email ?? 'Oyuncu',
      );
      await _openLiveGame(game.roomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final roomId = await _service.createRoom(
        creatorUid: user.uid,
        creatorName: user.displayName ?? user.email ?? 'Oyuncu 1',
      );
      await _openLiveGame(roomId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _roomController.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final roomId = _roomController.text.trim();
      await _service.resumeRoom(
        roomId: roomId,
        playerUid: user.uid,
        playerName: user.displayName ?? user.email ?? 'Oyuncu 2',
      );
      await _openLiveGame(roomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Online Tavla Lobisi')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.getBackgroundGradientColors(context),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (uid != null) ...[
              Text(
                'Devam Eden Oyunlar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ActiveLiveGameSummary>>(
                stream: _service.watchActiveGamesForUser(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final games = snapshot.data ?? [];
                  if (games.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Aktif oyun yok. Yeni oda olusturun veya kod ile katilin.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: games.map((g) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                cs.primaryContainer.withValues(alpha: 0.6),
                            child: Icon(Icons.sports_esports, color: cs.primary),
                          ),
                          title: Text(
                            g.opponentName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Oda ${g.roomId} · ${g.statusLabel}'
                            '${g.isOpponentAway ? ' · Rakip uzakta' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Oyunu sil',
                                onPressed:
                                    _busy ? null : () => _confirmDeleteGame(g),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: cs.error,
                                ),
                              ),
                              FilledButton(
                                onPressed:
                                    _busy ? null : () => _resumeGame(g),
                                child: const Text('Devam'),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer.withValues(alpha: 0.75),
                    cs.tertiaryContainer.withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sports_esports, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gercek zamanli eslesme',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Yeni oda olustur veya kod ile oyuna katil.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Yeni Oda',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Arkadasinla paylasmak icin 6 haneli oda kodu olustur.',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _createRoom,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(_busy ? 'Hazirlaniyor...' : 'Oda Olustur'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Odaya Katil',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Diger oyuncudan aldigin kodu girip oyuna baglan.',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _roomController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (value) {
                        final upper = value.toUpperCase();
                        if (value != upper) {
                          _roomController.value =
                              _roomController.value.copyWith(
                            text: upper,
                            selection: TextSelection.collapsed(
                                offset: upper.length),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Oda Kodu',
                        hintText: 'ORN: EZ0WTX',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Panodakini yapistir',
                          onPressed: () async {
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            final pasted = (data?.text ?? '')
                                .replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
                            final code = pasted.toUpperCase();
                            if (code.isEmpty) return;
                            _roomController.value = TextEditingValue(
                              text: code.length > 6
                                  ? code.substring(0, 6)
                                  : code,
                              selection: TextSelection.collapsed(
                                offset: code.length > 6 ? 6 : code.length,
                              ),
                            );
                          },
                          icon: const Icon(Icons.content_paste),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _joinRoom,
                      icon: const Icon(Icons.meeting_room_outlined),
                      label: const Text('Odaya Katil'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
