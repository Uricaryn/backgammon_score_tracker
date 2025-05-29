import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:provider/provider.dart';
import 'package:backgammon_score_tracker/core/providers/theme_provider.dart';
import 'dart:ui';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _usernameController.text = data['username'] ?? '';
        });

        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        themeProvider.setUseSystemTheme(data['useSystemTheme'] ?? true);
        themeProvider.setThemeMode(data['themeMode'] ?? 'system');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.generalError)),
        );
      }
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

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

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'username': _usernameController.text,
        'useSystemTheme': themeProvider.useSystemTheme,
        'themeMode': themeProvider.themeMode,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ErrorService.successProfileUpdated)),
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
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Profil Bilgileri',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    (_usernameController.text.isNotEmpty
                                            ? _usernameController.text[0]
                                            : 'K')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _usernameController
                                                      .text.isNotEmpty
                                                  ? _usernameController.text
                                                  : 'Kullanıcı Adı',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'Kullanıcı Adını Düzenle'),
                                                  content: TextFormField(
                                                    controller:
                                                        _usernameController,
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          'Kullanıcı Adı',
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                    ),
                                                    validator: ValidationService
                                                        .validateUsername,
                                                    autofocus: true,
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child:
                                                          const Text('İptal'),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () {
                                                        if (ValidationService
                                                                .validateUsername(
                                                                    _usernameController
                                                                        .text) ==
                                                            null) {
                                                          _saveUserData();
                                                          Navigator.pop(
                                                              context);
                                                        }
                                                      },
                                                      child:
                                                          const Text('Kaydet'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        user?.email ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _saveUserData,
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.settings,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sistem Ayarları',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SwitchListTile(
                              title: const Text('Sistem Temasını Kullan'),
                              subtitle:
                                  const Text('Cihazın tema ayarını takip et'),
                              value: themeProvider.useSystemTheme,
                              onChanged: (value) async {
                                await themeProvider.setUseSystemTheme(value);
                                _saveUserData();
                              },
                            ),
                            if (!themeProvider.useSystemTheme) ...[
                              const SizedBox(height: 16),
                              ListTile(
                                title: const Text('Tema'),
                                subtitle: Row(
                                  children: [
                                    const Icon(Icons.light_mode),
                                    Expanded(
                                      child: Slider(
                                        value: themeProvider.themeMode == 'dark'
                                            ? 1.0
                                            : 0.0,
                                        onChanged: (value) async {
                                          final mode =
                                              value > 0.5 ? 'dark' : 'light';
                                          await themeProvider
                                              .setThemeMode(mode);
                                          _saveUserData();
                                        },
                                        divisions: 1,
                                        semanticFormatterCallback: (value) {
                                          return value > 0.5
                                              ? 'Karanlık'
                                              : 'Aydınlık';
                                        },
                                      ),
                                    ),
                                    const Icon(Icons.dark_mode),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
