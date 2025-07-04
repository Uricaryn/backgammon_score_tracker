import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/update_notification_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';

class AdminUpdateScreen extends StatefulWidget {
  const AdminUpdateScreen({super.key});

  @override
  State<AdminUpdateScreen> createState() => _AdminUpdateScreenState();
}

class _AdminUpdateScreenState extends State<AdminUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _messageController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _updateNotificationService = UpdateNotificationService();

  bool _isLoading = false;
  bool _forceUpdate = false;

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  @override
  void dispose() {
    _versionController.dispose();
    _messageController.dispose();
    _downloadUrlController.dispose();
    super.dispose();
  }

  // 🔒 Verify admin access on screen entry
  Future<void> _verifyAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _exitWithError('Oturum açılmamış');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data()?['isAdmin'] != true) {
        _exitWithError('Admin yetkisi gereklidir');
        return;
      }
    } catch (e) {
      _exitWithError('Yetki kontrolü başarısız');
    }
  }

  // Exit screen with error message
  void _exitWithError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Erişim reddedildi: $message'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    }
  }

  // Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Hata: $message')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Admin - Güncelleme Bildirimi'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  Card(
                    elevation: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Beta Kullanıcılarına\nGüncelleme Bildirimi Gönder',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Kapalı Beta',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Version Input
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.new_releases,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Yeni Sürüm Bilgileri',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _versionController,
                            decoration: const InputDecoration(
                              labelText: 'Sürüm Numarası',
                              hintText: 'Örn: 1.2.0',
                              prefixIcon: Icon(Icons.tag),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Sürüm numarası gerekli';
                              }
                              if (!RegExp(r'^\d+\.\d+\.\d+$')
                                  .hasMatch(value.trim())) {
                                return 'Geçerli format: x.y.z (örn: 1.2.0)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Input
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.message,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Güncelleme Mesajı',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _messageController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Güncelleme Açıklaması',
                              hintText:
                                  'Örn: Yeni özellikler ve hata düzeltmeleri...',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Güncelleme mesajı gerekli';
                              }
                              if (value.trim().length < 10) {
                                return 'Mesaj en az 10 karakter olmalı';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Download URL Input
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.download,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'İndirme Linki',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _downloadUrlController,
                            decoration: const InputDecoration(
                              labelText: 'APK İndirme URL\'si',
                              hintText: 'https://example.com/app-v1.2.0.apk',
                              prefixIcon: Icon(Icons.link),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'İndirme URL\'si gerekli';
                              }
                              final uri = Uri.tryParse(value.trim());
                              if (uri == null || !uri.hasAbsolutePath) {
                                return 'Geçerli bir URL girin';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Firebase Storage, Google Drive veya güvenli bir hosting servisinin linkini kullanın.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Force Update Option
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: _forceUpdate
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Güncelleme Seçenekleri',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Zorunlu Güncelleme'),
                            subtitle: Text(
                              _forceUpdate
                                  ? 'Kullanıcılar güncellemeden uygulamayı kullanamaz'
                                  : 'Kullanıcılar isteğe bağlı olarak güncelleyebilir',
                              style: TextStyle(
                                color: _forceUpdate
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                            value: _forceUpdate,
                            onChanged: (value) {
                              setState(() {
                                _forceUpdate = value;
                              });
                            },
                            secondary: Icon(
                              _forceUpdate
                                  ? Icons.block
                                  : Icons.check_circle_outline,
                              color: _forceUpdate
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Send Button
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _sendUpdateNotification,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _isLoading
                            ? 'Gönderiliyor...'
                            : 'Beta Kullanıcılarına Gönder',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _forceUpdate
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Warning Card
                  if (_forceUpdate) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dikkat: Zorunlu Güncelleme',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bu seçenek aktifken kullanıcılar uygulamayı güncellemeden kullanamayacaklar.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendUpdateNotification() async {
    if (!_formKey.currentState!.validate()) return;

    // 🔒 Final admin check before sending notification
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Oturum açılmamış');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data()?['isAdmin'] != true) {
        _showError('Admin yetkisi gereklidir');
        return;
      }
    } catch (e) {
      _showError('Yetki kontrolü başarısız');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _updateNotificationService.sendUpdateNotificationToAllBetaUsers(
        newVersion: _versionController.text.trim(),
        updateMessage: _messageController.text.trim(),
        downloadUrl: _downloadUrlController.text.trim(),
        forceUpdate: _forceUpdate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Güncelleme bildirimi başarıyla gönderildi!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Clear form
        _versionController.clear();
        _messageController.clear();
        _downloadUrlController.clear();
        setState(() {
          _forceUpdate = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Hata: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
}
