import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _guestDataService = GuestDataService();
  String? _selectedPlayer1;
  String? _selectedPlayer2;
  int _player1Score = 0;
  int _player2Score = 0;
  bool _isLoading = false;
  bool _isGuestUser = false;

  // Sihirbaz adımları için state
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Adım başlıkları
  final List<String> _stepTitles = [
    'Oyuncu Seçimi',
    'Skor Girişi',
    'Önizleme',
    'Kaydetme'
  ];

  // Adım açıklamaları
  final List<String> _stepDescriptions = [
    'Maç için iki oyuncu seçin',
    'Her oyuncunun skorunu girin',
    'Maç detaylarını kontrol edin',
    'Maçı kaydedin'
  ];

  @override
  void initState() {
    super.initState();
    _checkUserType();
  }

  void _checkUserType() {
    _isGuestUser = _firebaseService.isCurrentUserGuest();
  }

  Widget _buildGuestPlayersList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _guestDataService.getGuestPlayers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hata: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final players = snapshot.data ?? [];

        if (players.isEmpty) {
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

        final playerNames =
            players.map((player) => player['name'] as String).toList();

        return Column(
          children: [
            // Son Oyuncular Hızlı Seçim
            if (playerNames.isNotEmpty) ...[
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: playerNames.take(4).map((player) {
                        final isSelected1 = _selectedPlayer1 == player;
                        final isSelected2 = _selectedPlayer2 == player;
                        final isSelected = isSelected1 || isSelected2;

                        return FilterChip(
                          label: Text(player),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              if (_selectedPlayer1 == null) {
                                setState(() {
                                  _selectedPlayer1 = player;
                                });
                              } else if (_selectedPlayer2 == null &&
                                  _selectedPlayer1 != player) {
                                setState(() {
                                  _selectedPlayer2 = player;
                                });
                              }
                            } else {
                              if (_selectedPlayer1 == player) {
                                setState(() {
                                  _selectedPlayer1 = null;
                                });
                              } else if (_selectedPlayer2 == player) {
                                setState(() {
                                  _selectedPlayer2 = null;
                                });
                              }
                            }
                          },
                          avatar: isSelected1
                              ? const Icon(Icons.person, size: 16)
                              : isSelected2
                                  ? const Icon(Icons.person_outline, size: 16)
                                  : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Dropdown Seçimi
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedPlayer1,
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
                items: playerNames
                    .map((player) => DropdownMenuItem(
                          value: player,
                          child: Text(
                            player,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlayer1 = value;
                  });
                },
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
                value: _selectedPlayer2,
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
                items: playerNames
                    .map((player) => DropdownMenuItem(
                          value: player,
                          child: Text(
                            player,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlayer2 = value;
                  });
                },
              ),
            ),
          ],
        );
      },
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
            if (_isGuestUser) ...[
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
      if (_isGuestUser) {
        await _guestDataService.saveGuestPlayer(name);
      } else {
        await _firebaseService.savePlayer(name);
      }

      if (mounted) {
        Navigator.pop(context);
        setState(() {}); // Misafir kullanıcılar için listeyi yenile
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGuestUser
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

  // Adım yönetimi metodları
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      setState(() {
        _currentStep = step;
      });
    }
  }

  bool _canGoToNextStep() {
    switch (_currentStep) {
      case 0: // Oyuncu seçimi
        return _selectedPlayer1 != null && _selectedPlayer2 != null;
      case 1: // Skor girişi
        return _player1Score >= 0 && _player2Score >= 0;
      case 2: // Önizleme
        return true;
      default:
        return false;
    }
  }

  Future<void> _saveGame() async {
    if (_selectedPlayer1 == null || _selectedPlayer2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen iki oyuncu da seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isGuestUser) {
        await _guestDataService.saveGuestGame(
          player1: _selectedPlayer1!,
          player2: _selectedPlayer2!,
          player1Score: _player1Score,
          player2Score: _player2Score,
        );
      } else {
        await _firebaseService.saveGame(
          player1: _selectedPlayer1!,
          player2: _selectedPlayer2!,
          player1Score: _player1Score,
          player2Score: _player2Score,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGuestUser
                ? 'Maç başarıyla kaydedildi! (Yerel olarak)'
                : 'Maç başarıyla kaydedildi!'),
            backgroundColor: Colors.green,
          ),
        );

        // Ana sayfaya yönlendir
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
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
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Maç'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // Adım bilgisi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adım ${_currentStep + 1} / $_totalSteps',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _stepTitles[_currentStep],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: Column(
            children: [
              // Adım içeriği
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: _buildStepContent(),
                ),
              ),
              // Navigasyon butonları
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          child: const Text('Geri'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      child: _currentStep == _totalSteps - 1
                          ? FilledButton.icon(
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
                              label: Text(
                                  _isLoading ? 'Kaydediliyor...' : 'Kaydet'),
                            )
                          : FilledButton(
                              onPressed: _canGoToNextStep() ? _nextStep : null,
                              child: const Text('İleri'),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPlayerSelectionStep();
      case 1:
        return _buildScoreInputStep();
      case 2:
        return _buildPreviewStep();
      case 3:
        return _buildSaveStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPlayerSelectionStep() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        // Oyuncu Seçimi Kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Oyuncu Seçimi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Maç için iki oyuncu seçin',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _isGuestUser
                    ? _buildGuestPlayersList()
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('players')
                            .where('userId', isEqualTo: userId)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Hata: ${snapshot.error}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Henüz oyuncu eklenmemiş',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Aşağıdaki "Yeni Oyuncu Ekle" butonunu kullanarak ilk oyuncunuzu ekleyin.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          final players = snapshot.data!.docs
                              .map((doc) => doc.data() as Map<String, dynamic>)
                              .map((data) => data['name'] as String)
                              .toList();

                          return Column(
                            children: [
                              // Son Oyuncular Hızlı Seçim
                              if (players.isNotEmpty) ...[
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Son Oyuncular',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: players.take(4).map((player) {
                                          final isSelected1 =
                                              _selectedPlayer1 == player;
                                          final isSelected2 =
                                              _selectedPlayer2 == player;
                                          final isSelected =
                                              isSelected1 || isSelected2;

                                          return FilterChip(
                                            label: Text(player),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              if (selected) {
                                                if (_selectedPlayer1 == null) {
                                                  setState(() {
                                                    _selectedPlayer1 = player;
                                                  });
                                                } else if (_selectedPlayer2 ==
                                                        null &&
                                                    _selectedPlayer1 !=
                                                        player) {
                                                  setState(() {
                                                    _selectedPlayer2 = player;
                                                  });
                                                }
                                              } else {
                                                if (_selectedPlayer1 ==
                                                    player) {
                                                  setState(() {
                                                    _selectedPlayer1 = null;
                                                  });
                                                } else if (_selectedPlayer2 ==
                                                    player) {
                                                  setState(() {
                                                    _selectedPlayer2 = null;
                                                  });
                                                }
                                              }
                                            },
                                            avatar: isSelected1
                                                ? const Icon(Icons.person,
                                                    size: 16)
                                                : isSelected2
                                                    ? const Icon(
                                                        Icons.person_outline,
                                                        size: 16)
                                                    : null,
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              // Dropdown Seçimi
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPlayer1,
                                  decoration: InputDecoration(
                                    labelText: '1. Oyuncu',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    prefixIcon: Icon(
                                      Icons.person,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  items: players
                                      .map((player) => DropdownMenuItem(
                                            value: player,
                                            child: Text(
                                              player,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPlayer1 = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPlayer2,
                                  decoration: InputDecoration(
                                    labelText: '2. Oyuncu',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    prefixIcon: Icon(
                                      Icons.person,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  items: players
                                      .map((player) => DropdownMenuItem(
                                            value: player,
                                            child: Text(
                                              player,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPlayer2 = value;
                                    });
                                  },
                                ),
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
        // Hızlı Oyuncu Ekle Butonu Kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hızlı Oyuncu Ekle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showQuickAddPlayerDialog();
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Yeni Oyuncu Ekle'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreInputStep() {
    return Column(
      children: [
        // Oyuncu bilgileri kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Oyuncu Bilgileri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedPlayer1 ?? '1. Oyuncu',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedPlayer2 ?? '2. Oyuncu',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
        // Skor girişi kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.scoreboard,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Skor Girişi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '1. Oyuncu Skoru',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<int>(
                              value: _player1Score,
                              underline: const SizedBox(),
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              items: List.generate(16, (index) => index)
                                  .map((score) => DropdownMenuItem<int>(
                                        value: score,
                                        child: Text(
                                          score.toString(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _player1Score = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '2. Oyuncu Skoru',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<int>(
                              value: _player2Score,
                              underline: const SizedBox(),
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              items: List.generate(16, (index) => index)
                                  .map((score) => DropdownMenuItem<int>(
                                        value: score,
                                        child: Text(
                                          score.toString(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _player2Score = value;
                                  });
                                }
                              },
                            ),
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
        // Toplam skor gösterimi kartı
        if (_player1Score > 0 || _player2Score > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calculate,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Toplam Skor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_player1Score + _player2Score}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    final winner =
        _player1Score > _player2Score ? _selectedPlayer1 : _selectedPlayer2;
    final winnerScore =
        _player1Score > _player2Score ? _player1Score : _player2Score;

    return Column(
      children: [
        // Maç özeti kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Maç Özeti',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                // Oyuncu karşılaştırması
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: _player1Score > _player2Score
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2)
                                : Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.person,
                              size: 30,
                              color: _player1Score > _player2Score
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedPlayer1 ?? '1. Oyuncu',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_player1Score',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _player1Score > _player2Score
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: _player2Score > _player1Score
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2)
                                : Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.person,
                              size: 30,
                              color: _player2Score > _player1Score
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedPlayer2 ?? '2. Oyuncu',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_player2Score',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _player2Score > _player1Score
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Kazanan bilgisi
                if (winner != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$winner kazandı! ($winnerScore puan)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // Toplam skor
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Toplam Skor: ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_player1Score + _player2Score}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Bilgi kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Maç detaylarını kontrol edin. Kaydet butonuna tıklayarak maçı kaydedebilirsiniz.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveStep() {
    return Column(
      children: [
        // Başarı kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Başarı ikonu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                // Başlık
                Text(
                  'Maç Hazır!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // Açıklama
                Text(
                  'Maç detayları doğru görünüyor. Kaydet butonuna tıklayarak maçı kaydedebilirsiniz.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Maç özeti kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.summarize,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Maç Detayları',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1. Oyuncu:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_selectedPlayer1 ?? "Seçilmedi"}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '2. Oyuncu:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_selectedPlayer2 ?? "Seçilmedi"}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Skor:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$_player1Score - $_player2Score',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_player1Score + _player2Score}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
