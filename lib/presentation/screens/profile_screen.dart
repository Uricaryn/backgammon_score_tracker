import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/providers/theme_provider.dart';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_card.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/presentation/screens/admin_update_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firebaseService = FirebaseService();
  final _guestDataService = GuestDataService();
  final _logService = LogService();
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _isAdminLoading = true; // Admin kontrolü loading state

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkAdminAccess();
  }

  // ✅ Check if user is admin - SECURE VERSION
  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isAdmin = false;
        _isAdminLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          // 🔒 ONLY trust Firestore data - no email-based access
          _isAdmin = data['isAdmin'] == true;
          _isAdminLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isAdmin = false;
          _isAdminLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Admin check error: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false; // Default to false on error
          _isAdminLoading = false;
        });
      }
    }
  }

  // 🔒 Double-check admin access before navigation
  Future<void> _verifyAdminAccessAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAccessDeniedMessage();
      return;
    }

    try {
      // Re-verify admin status from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data()?['isAdmin'] != true) {
        _showAccessDeniedMessage();
        return;
      }

      // Admin verified - navigate to admin panel
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminUpdateScreen(),
          ),
        );
      }
    } catch (e) {
      _showAccessDeniedMessage();
      debugPrint('Admin verification error: $e');
    }
  }

  // Show access denied message
  void _showAccessDeniedMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Erişim reddedildi: Admin yetkisi gereklidir'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset admin status for security
      setState(() {
        _isAdmin = false;
      });
    }
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
      if (!mounted) return;
      if (context.mounted) {
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'username': _usernameController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı bilgileri güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Güncelleme başarısız: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

  Future<void> _logout() async {
    const message = 'Çıkış yapmak istediğinizden emin misiniz?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firebaseService.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.login,
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Çıkış yapılırken hata oluştu: $e')),
          );
        }
      }
    }
  }

  // Hesap silme işlemi
  Future<void> _deleteAccount() async {
    // 1. Onay: Emin misiniz?
    final confirmed1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Hesap Silme'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hesabınızı silmek istediğinizden emin misiniz?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Bu işlem geri alınamaz ve şunları silecek:',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 4),
            Text('• Tüm oyunlarınız', style: TextStyle(fontSize: 12)),
            Text('• Tüm oyuncularınız', style: TextStyle(fontSize: 12)),
            Text('• Tüm bildirimleriniz', style: TextStyle(fontSize: 12)),
            Text('• Hesap bilgileriniz', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed1 != true) return;

    // 2. Onay: Geri alınamaz, devam?
    final confirmed2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Son Onay'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bu işlem geri alınamaz!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 16),
            Text(
              'Hesabınız kalıcı olarak silinecek ve tüm verileriniz kaybolacak.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Bu işlemi gerçekleştirmek istediğinizden emin misiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hesabımı Sil'),
          ),
        ],
      ),
    );
    if (confirmed2 != true) return;

    // Gerekirse yeniden kimlik doğrulama
    final requiresReauth =
        await _firebaseService.requiresRecentLoginForDelete();
    if (requiresReauth) {
      final reauthResult = await _showReauthenticationDialog();
      if (!reauthResult) return;
    }

    setState(() => _isLoading = true);
    try {
      await _firebaseService.deleteUserAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesabınız başarıyla silindi'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.login,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hesap silme başarısız: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Yeniden kimlik doğrulama dialog'u
  Future<bool> _showReauthenticationDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final emailController =
        TextEditingController(text: currentUser.email ?? '');
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('Güvenlik Doğrulaması'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hesap silme işlemi için kimlik doğrulaması gerekiyor.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: false, // E-posta adresi değiştirilemez
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'E-posta gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(),
                  hintText: 'Mevcut şifrenizi girin',
                ),
                obscureText: true,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifre gerekli';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final credential = EmailAuthProvider.credential(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                  await currentUser.reauthenticateWithCredential(credential);
                  Navigator.pop(context, true);
                } on FirebaseAuthException catch (e) {
                  if (!context.mounted) return;
                  String errorMessage;
                  switch (e.code) {
                    case 'wrong-password':
                      errorMessage =
                          'Şifre yanlış. Lütfen doğru şifrenizi girin.';
                      break;
                    case 'user-mismatch':
                      errorMessage = 'E-posta adresi eşleşmiyor.';
                      break;
                    case 'invalid-credential':
                      errorMessage = 'Geçersiz kimlik bilgileri.';
                      break;
                    case 'too-many-requests':
                      errorMessage =
                          'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.';
                      break;
                    default:
                      errorMessage = 'Kimlik doğrulama başarısız: ${e.message}';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Beklenmeyen hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: BackgroundBoard(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profil Bilgileri Kartı
                StyledCard(
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
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Profil Bilgileri',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _usernameController.text.isNotEmpty
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
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                  'Kullanıcı Adını Düzenle'),
                                              content: TextFormField(
                                                controller: _usernameController,
                                                decoration: InputDecoration(
                                                  labelText: 'Kullanıcı Adı',
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                                validator: ValidationService
                                                    .validateUsername,
                                                autofocus: true,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('İptal'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    if (ValidationService
                                                            .validateUsername(
                                                                _usernameController
                                                                    .text) ==
                                                        null) {
                                                      _saveUserData();
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                  child: const Text('Kaydet'),
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
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tema Ayarları Kartı
                StyledCard(
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
                                Icons.palette,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Tema Ayarları',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: const Text('Sistem Temasını Kullan'),
                          subtitle: const Text('Otomatik tema değişimi'),
                          value: themeProvider.useSystemTheme,
                          onChanged: (value) {
                            themeProvider.setUseSystemTheme(value);
                          },
                        ),
                        if (!themeProvider.useSystemTheme) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Tema Seçimi:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Açık'),
                                  value: 'light',
                                  groupValue: themeProvider.themeMode,
                                  onChanged: (value) {
                                    if (value != null) {
                                      themeProvider.setThemeMode(value);
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Koyu'),
                                  value: 'dark',
                                  groupValue: themeProvider.themeMode,
                                  onChanged: (value) {
                                    if (value != null) {
                                      themeProvider.setThemeMode(value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Admin Panel Kartı - Sadece gerçek adminlere göster
                if (!_isAdminLoading && _isAdmin) ...[
                  StyledCard(
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
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Admin Panel',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Beta kullanıcılarına güncelleme bildirimi gönderin.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                // 🔒 Double-check admin access before opening panel
                                await _verifyAdminAccessAndNavigate();
                              },
                              icon: const Icon(Icons.send),
                              label: const Text('Güncelleme Bildirimi Gönder'),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Hesap Silme Kartı
                StyledCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.delete_forever,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Hesabı Sil',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hesabınızı silmek için aşağıdaki butona tıklayın.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _deleteAccount,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_forever),
                            label: Text(
                                _isLoading ? 'Siliniyor...' : 'Hesabımı Sil'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
