import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'dart:ui';

class EditGameScreen extends StatefulWidget {
  final String gameId;
  final String player1;
  final String player2;
  final int player1Score;
  final int player2Score;

  const EditGameScreen({
    super.key,
    required this.gameId,
    required this.player1,
    required this.player2,
    required this.player1Score,
    required this.player2Score,
  });

  @override
  State<EditGameScreen> createState() => _EditGameScreenState();
}

class _EditGameScreenState extends State<EditGameScreen> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedPlayer1;
  late String? _selectedPlayer2;
  late int _player1Score;
  late int _player2Score;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedPlayer1 = widget.player1;
    _selectedPlayer2 = widget.player2;
    _player1Score = widget.player1Score;
    _player2Score = widget.player2Score;
  }

  Future<void> _updateGame() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate player selections
    final player1Error = ValidationService.validatePlayerSelection(
        _selectedPlayer1, _selectedPlayer2);
    final player2Error = ValidationService.validatePlayerSelection(
        _selectedPlayer2, _selectedPlayer1);

    if (player1Error != null || player2Error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                player1Error ?? player2Error ?? ErrorService.generalError)),
      );
      return;
    }

    // Validate scores
    final player1ScoreError = ValidationService.validateScore(_player1Score);
    final player2ScoreError = ValidationService.validateScore(_player2Score);

    if (player1ScoreError != null || player2ScoreError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(player1ScoreError ??
                player2ScoreError ??
                ErrorService.gameInvalidScore)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.authUserNotFound)),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .update({
        'player1': _selectedPlayer1,
        'player2': _selectedPlayer2,
        'player1Score': _player1Score,
        'player2Score': _player2Score,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.successGameUpdated)),
        );
        Navigator.pop(context);
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
        case 'already-exists':
          errorMessage = ErrorService.firestoreAlreadyExists;
          break;
        case 'resource-exhausted':
          errorMessage = ErrorService.firestoreResourceExhausted;
          break;
        case 'failed-precondition':
          errorMessage = ErrorService.firestoreFailedPrecondition;
          break;
        case 'aborted':
          errorMessage = ErrorService.firestoreAborted;
          break;
        case 'out-of-range':
          errorMessage = ErrorService.firestoreOutOfRange;
          break;
        case 'unimplemented':
          errorMessage = ErrorService.firestoreUnimplemented;
          break;
        case 'internal':
          errorMessage = ErrorService.firestoreInternal;
          break;
        case 'unavailable':
          errorMessage = ErrorService.firestoreUnavailable;
          break;
        case 'data-loss':
          errorMessage = ErrorService.firestoreDataLoss;
          break;
        default:
          errorMessage = ErrorService.gameUpdateFailed;
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maçı Düzenle'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    kToolbarHeight -
                    32,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StreamBuilder<QuerySnapshot>(
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
                                            Text('Önce oyuncu eklemelisiniz'),
                                      );
                                    }

                                    final players = snapshot.data!.docs
                                        .map((doc) =>
                                            doc.data() as Map<String, dynamic>)
                                        .map((data) => data['name'] as String)
                                        .toList();

                                    return Column(
                                      children: [
                                        DropdownButtonFormField<String>(
                                          value: _selectedPlayer1,
                                          decoration: const InputDecoration(
                                            labelText: '1. Oyuncu',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: players
                                              .map((player) => DropdownMenuItem(
                                                    value: player,
                                                    child: Text(player),
                                                  ))
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedPlayer1 = value;
                                            });
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Lütfen 1. oyuncuyu seçin';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        DropdownButtonFormField<String>(
                                          value: _selectedPlayer2,
                                          decoration: const InputDecoration(
                                            labelText: '2. Oyuncu',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: players
                                              .map((player) => DropdownMenuItem(
                                                    value: player,
                                                    child: Text(player),
                                                  ))
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedPlayer2 = value;
                                            });
                                          },
                                          validator: (value) =>
                                              ValidationService
                                                  .validatePlayerSelection(
                                                      value, _selectedPlayer1),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
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
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.scoreboard,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Skor',
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              _selectedPlayer1 ?? '1. Oyuncu',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      if (_player1Score > 0) {
                                                        _player1Score--;
                                                      }
                                                    });
                                                  },
                                                  icon: const Icon(
                                                      Icons.remove_circle),
                                                ),
                                                Text(
                                                  '$_player1Score',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _player1Score++;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                      Icons.add_circle),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Text(
                                        'VS',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              _selectedPlayer2 ?? '2. Oyuncu',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      if (_player2Score > 0) {
                                                        _player2Score--;
                                                      }
                                                    });
                                                  },
                                                  icon: const Icon(
                                                      Icons.remove_circle),
                                                ),
                                                Text(
                                                  '$_player2Score',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _player2Score++;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                      Icons.add_circle),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _updateGame,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Güncelleniyor...' : 'Güncelle'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
