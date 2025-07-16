import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_container.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _logService = LogService();
  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  String? _availabilityMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.length < 3) return;

    setState(() {
      _isCheckingAvailability = true;
      _availabilityMessage = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      setState(() {
        _isCheckingAvailability = false;
        if (querySnapshot.docs.isNotEmpty) {
          _availabilityMessage = 'Bu kullanıcı adı zaten kullanılıyor';
        } else {
          _availabilityMessage = 'Kullanıcı adı uygun ✓';
        }
      });
    } catch (e) {
      setState(() {
        _isCheckingAvailability = false;
        _availabilityMessage = 'Kontrol edilemiyor';
      });
    }
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim().toLowerCase();

      // Son kez kontrol et
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu kullanıcı adı zaten kullanılıyor')),
        );
        return;
      }

      // Username'i kaydet
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'username': username,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logService.info('Username set successfully: $username', tag: 'Auth');

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      }
    } catch (e) {
      _logService.error('Failed to save username', tag: 'Auth', error: e);
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Kullanıcı adı gerekli';
    }

    final username = value.trim();

    if (username.length < 3) {
      return 'Kullanıcı adı en az 3 karakter olmalı';
    }

    if (username.length > 20) {
      return 'Kullanıcı adı en fazla 20 karakter olabilir';
    }

    // Sadece harf, rakam ve alt çizgi
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!regex.hasMatch(username)) {
      return 'Sadece harf, rakam ve alt çizgi kullanılabilir';
    }

    // İlk karakter harf olmalı
    if (!RegExp(r'^[a-zA-Z]').hasMatch(username)) {
      return 'İlk karakter harf olmalı';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundBoard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: StyledContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Kullanıcı Adı Belirle',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Arkadaşlarınızın sizi bulabilmesi için bir kullanıcı adı seçmeniz gerekiyor.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                TextFormField(
                                  controller: _usernameController,
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    labelText: 'Kullanıcı Adı',
                                    hintText: 'örn: ahmet123',
                                    prefixIcon:
                                        const Icon(Icons.alternate_email),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: _isCheckingAvailability
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : _availabilityMessage != null
                                            ? Icon(
                                                _availabilityMessage!
                                                        .contains('✓')
                                                    ? Icons.check_circle
                                                    : Icons.error,
                                                color: _availabilityMessage!
                                                        .contains('✓')
                                                    ? Colors.green
                                                    : Colors.red,
                                              )
                                            : null,
                                  ),
                                  validator: _validateUsername,
                                  onChanged: (value) {
                                    if (value.trim().length >= 3) {
                                      _checkUsernameAvailability(value.trim());
                                    } else {
                                      setState(() {
                                        _availabilityMessage = null;
                                      });
                                    }
                                  },
                                ),
                                if (_availabilityMessage != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _availabilityMessage!,
                                    style: TextStyle(
                                      color: _availabilityMessage!.contains('✓')
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ||
                                            _isCheckingAvailability ||
                                            (_availabilityMessage != null &&
                                                !_availabilityMessage!
                                                    .contains('✓'))
                                        ? null
                                        : _saveUsername,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                    ),
                                    child: _isLoading
                                        ? const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text('Kaydediliyor...'),
                                            ],
                                          )
                                        : const Text('Devam Et'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '• 3-20 karakter arası\n• Harf, rakam ve alt çizgi kullanılabilir\n• İlk karakter harf olmalı',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
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
}
