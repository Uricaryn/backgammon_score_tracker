import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/presentation/screens/edit_player_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/player_match_history_screen.dart';
import 'dart:ui';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addPlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseService().savePlayer(_playerNameController.text);

      if (mounted) {
        _playerNameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.successPlayerSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePlayer(String playerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('players')
          .doc(playerId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.successPlayerDeleted)),
        );
      }
    } on FirebaseException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = ErrorService.firestorePermissionDenied;
          break;
        case 'not-found':
          errorMessage = ErrorService.firestoreDocumentNotFound;
          break;
        case 'unavailable':
          errorMessage = ErrorService.firestoreUnavailable;
          break;
        default:
          errorMessage = ErrorService.playerDeleteFailed;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.generalError)),
        );
      }
    }
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyuncular'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _playerNameController,
                            decoration: InputDecoration(
                              labelText: 'Oyuncu Adı',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              prefixIcon: Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            validator: ValidationService.validatePlayerName,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _addPlayer,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(
                                _isLoading ? 'Ekleniyor...' : 'Oyuncu Ekle'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
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
                            Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.7),
                            Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.5),
                          ],
                        ),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
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
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.people,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Oyuncu Listesi',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('players')
                                        .where('userId', isEqualTo: userId)
                                        .orderBy('createdAt', descending: true)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return Text('Hata: ${snapshot.error}');
                                      }

                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      }

                                      if (!snapshot.hasData ||
                                          snapshot.data!.docs.isEmpty) {
                                        return const Center(
                                          child:
                                              Text('Henüz oyuncu eklenmemiş'),
                                        );
                                      }

                                      return ListView.builder(
                                        itemCount: snapshot.data!.docs.length,
                                        itemBuilder: (context, index) {
                                          final doc =
                                              snapshot.data!.docs[index];
                                          final data = doc.data()
                                              as Map<String, dynamic>;
                                          final name = data['name'] as String;

                                          return Card(
                                            elevation: 2,
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () async {
                                                // Get player statistics
                                                final userId = FirebaseAuth
                                                    .instance.currentUser?.uid;
                                                if (userId == null) return;

                                                final snapshot =
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('games')
                                                        .where('userId',
                                                            isEqualTo: userId)
                                                        .get();

                                                int totalMatches = 0;
                                                int wins = 0;
                                                int totalScore = 0;
                                                int highestScore = 0;
                                                Map<String, int> opponentWins =
                                                    {};

                                                for (var doc in snapshot.docs) {
                                                  final data = doc.data();
                                                  final player1 =
                                                      data['player1'] as String;
                                                  final player2 =
                                                      data['player2'] as String;
                                                  final player1Score =
                                                      data['player1Score']
                                                          as int;
                                                  final player2Score =
                                                      data['player2Score']
                                                          as int;

                                                  if (player1 == name ||
                                                      player2 == name) {
                                                    totalMatches++;

                                                    final isPlayer1 =
                                                        player1 == name;
                                                    final score = isPlayer1
                                                        ? player1Score
                                                        : player2Score;
                                                    final opponent = isPlayer1
                                                        ? player2
                                                        : player1;

                                                    totalScore += score;
                                                    if (score > highestScore) {
                                                      highestScore = score;
                                                    }

                                                    if ((isPlayer1 &&
                                                            player1Score >
                                                                player2Score) ||
                                                        (!isPlayer1 &&
                                                            player2Score >
                                                                player1Score)) {
                                                      wins++;
                                                      opponentWins[opponent] =
                                                          (opponentWins[
                                                                      opponent] ??
                                                                  0) +
                                                              1;
                                                    }
                                                  }
                                                }

                                                if (!mounted) return;

                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .primary
                                                                .withOpacity(
                                                                    0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Icon(
                                                            Icons.person,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .primary,
                                                            size: 24,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            name,
                                                            style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Card(
                                                            elevation: 0,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16),
                                                            ),
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            16),
                                                                gradient:
                                                                    LinearGradient(
                                                                  begin: Alignment
                                                                      .topLeft,
                                                                  end: Alignment
                                                                      .bottomRight,
                                                                  colors: [
                                                                    Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .surfaceVariant
                                                                        .withOpacity(
                                                                            0.7),
                                                                    Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .surfaceVariant
                                                                        .withOpacity(
                                                                            0.5),
                                                                  ],
                                                                ),
                                                                border:
                                                                    Border.all(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .outline
                                                                      .withOpacity(
                                                                          0.2),
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            16),
                                                                child:
                                                                    BackdropFilter(
                                                                  filter: ImageFilter
                                                                      .blur(
                                                                          sigmaX:
                                                                              10,
                                                                          sigmaY:
                                                                              10),
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            16.0),
                                                                    child:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        _buildStatRow(
                                                                            'Toplam Maç',
                                                                            '$totalMatches'),
                                                                        _buildStatRow(
                                                                            'Kazanma',
                                                                            '$wins'),
                                                                        _buildStatRow(
                                                                            'Kazanma Oranı',
                                                                            totalMatches > 0
                                                                                ? '${(wins / totalMatches * 100).toStringAsFixed(1)}%'
                                                                                : '0%'),
                                                                        _buildStatRow(
                                                                            'Toplam Puan',
                                                                            '$totalScore'),
                                                                        _buildStatRow(
                                                                            'En Yüksek Puan',
                                                                            '$highestScore'),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child:
                                                            const Text('Kapat'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: ListTile(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                leading: CircleAvatar(
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withOpacity(0.1),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                                title: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.info_outline,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.history),
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            String?
                                                                selectedPlayer;
                                                            return AlertDialog(
                                                              title: const Text(
                                                                  'İkinci Oyuncuyu Seçin'),
                                                              content:
                                                                  StreamBuilder<
                                                                      QuerySnapshot>(
                                                                stream: FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'players')
                                                                    .where(
                                                                        'userId',
                                                                        isEqualTo:
                                                                            userId)
                                                                    .orderBy(
                                                                        'createdAt',
                                                                        descending:
                                                                            true)
                                                                    .snapshots(),
                                                                builder: (context,
                                                                    snapshot) {
                                                                  if (snapshot
                                                                      .hasError) {
                                                                    return Text(
                                                                        'Hata: ${snapshot.error}');
                                                                  }

                                                                  if (snapshot
                                                                          .connectionState ==
                                                                      ConnectionState
                                                                          .waiting) {
                                                                    return const Center(
                                                                        child:
                                                                            CircularProgressIndicator());
                                                                  }

                                                                  if (!snapshot
                                                                          .hasData ||
                                                                      snapshot
                                                                          .data!
                                                                          .docs
                                                                          .isEmpty) {
                                                                    return const Center(
                                                                        child: Text(
                                                                            'Henüz oyuncu eklenmemiş'));
                                                                  }

                                                                  final players = snapshot
                                                                      .data!
                                                                      .docs
                                                                      .map((doc) => doc
                                                                              .data()
                                                                          as Map<
                                                                              String,
                                                                              dynamic>)
                                                                      .map((data) =>
                                                                          data['name']
                                                                              as String)
                                                                      .where((playerName) =>
                                                                          playerName !=
                                                                          name)
                                                                      .toList();

                                                                  return DropdownButtonFormField<
                                                                      String>(
                                                                    value:
                                                                        selectedPlayer,
                                                                    decoration:
                                                                        const InputDecoration(
                                                                      labelText:
                                                                          'İkinci Oyuncu',
                                                                      border:
                                                                          OutlineInputBorder(),
                                                                    ),
                                                                    items: players
                                                                        .map((player) => DropdownMenuItem(
                                                                              value: player,
                                                                              child: Text(player),
                                                                            ))
                                                                        .toList(),
                                                                    onChanged:
                                                                        (value) {
                                                                      selectedPlayer =
                                                                          value;
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          context),
                                                                  child: const Text(
                                                                      'İptal'),
                                                                ),
                                                                FilledButton(
                                                                  onPressed:
                                                                      selectedPlayer ==
                                                                              null
                                                                          ? null
                                                                          : () {
                                                                              Navigator.pop(context);
                                                                              Navigator.push(
                                                                                context,
                                                                                MaterialPageRoute(
                                                                                  builder: (context) => PlayerMatchHistoryScreen(
                                                                                    player1: name,
                                                                                    player2: selectedPlayer!,
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                  child: const Text(
                                                                      'Görüntüle'),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.edit),
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                EditPlayerScreen(
                                                              playerId: doc.id,
                                                              playerName: name,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete),
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) =>
                                                              AlertDialog(
                                                            title: const Text(
                                                                'Oyuncuyu Sil'),
                                                            content: Text(
                                                                '$name oyuncusunu silmek istediğinizden emin misiniz?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context),
                                                                child:
                                                                    const Text(
                                                                        'İptal'),
                                                              ),
                                                              FilledButton(
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                      context);
                                                                  _deletePlayer(
                                                                      doc.id);
                                                                },
                                                                style: FilledButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .error,
                                                                ),
                                                                child:
                                                                    const Text(
                                                                        'Sil'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
