import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditPlayerScreen extends StatefulWidget {
  final String playerId;
  final String playerName;

  const EditPlayerScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updatePlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Start a batch write
      final batch = FirebaseFirestore.instance.batch();

      // Update the player document
      final playerRef =
          FirebaseFirestore.instance.collection('players').doc(widget.playerId);
      batch.update(playerRef, {
        'name': _nameController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get all matches where this player is either player1 or player2
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('userId', isEqualTo: userId)
          .where(Filter.or(
            Filter('player1', isEqualTo: widget.playerName),
            Filter('player2', isEqualTo: widget.playerName),
          ))
          .get();

      // Update each match that references this player
      for (var doc in gamesQuery.docs) {
        final data = doc.data();
        final updates = <String, dynamic>{};

        if (data['player1'] == widget.playerName) {
          updates['player1'] = _nameController.text;
        }
        if (data['player2'] == widget.playerName) {
          updates['player2'] = _nameController.text;
        }

        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
        }
      }

      // Commit all updates
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Oyuncu ve ilgili maçlar başarıyla güncellendi')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyuncuyu Düzenle'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Oyuncu Adı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen oyuncu adını girin';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _updatePlayer,
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
    );
  }
}
