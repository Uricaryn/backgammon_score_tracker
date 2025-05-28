import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedPlayer1;
  String? _selectedPlayer2;
  int _player1Score = 0;
  int _player2Score = 0;
  bool _isLoading = false;

  Future<void> _saveGame() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlayer1 == null || _selectedPlayer2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen her iki oyuncuyu da seçin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      await FirebaseFirestore.instance.collection('games').add({
        'player1': _selectedPlayer1,
        'player2': _selectedPlayer2,
        'player1Score': _player1Score,
        'player2Score': _player2Score,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maç başarıyla kaydedildi')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
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
        title: const Text('Yeni Maç'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
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
                                  child: Text('Önce oyuncu eklemelisiniz'),
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
                                      if (value == null || value.isEmpty) {
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
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Lütfen 2. oyuncuyu seçin';
                                      }
                                      if (value == _selectedPlayer1) {
                                        return 'Aynı oyuncuyu seçemezsiniz';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Skor',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      _selectedPlayer1 ?? '1. Oyuncu',
                                      style: const TextStyle(fontSize: 16),
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
                                          icon: const Icon(Icons.remove_circle),
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
                                          icon: const Icon(Icons.add_circle),
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
                                      style: const TextStyle(fontSize: 16),
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
                                          icon: const Icon(Icons.remove_circle),
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
                                          icon: const Icon(Icons.add_circle),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _saveGame,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Kaydediliyor...' : 'Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
