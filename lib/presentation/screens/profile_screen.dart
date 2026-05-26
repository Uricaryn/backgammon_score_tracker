import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/providers/theme_provider.dart';
import 'package:backgammon_score_tracker/core/validation/validation_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_card.dart';
import 'package:backgammon_score_tracker/core/widgets/dice_switch.dart';
import 'package:backgammon_score_tracker/core/services/tutorial_service.dart';
import 'package:backgammon_score_tracker/core/constants/privacy_policy.dart';
import 'package:backgammon_score_tracker/presentation/screens/admin_update_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/premium_upgrade_screen.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';
import 'package:backgammon_score_tracker/core/services/payment_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firebaseService = FirebaseService();
  final _premiumService = PremiumService();
  final _paymentService = PaymentService();
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _isAdminLoading = true; // Admin kontrolü loading state
  bool _isGuestUser = false;
  bool _premiumLoading = true;
  bool _hasPremiumAccess = false;
  PremiumMembershipInfo? _premiumInfo;
  StreamSubscription<bool>? _premiumActivatedSub;

  @override
  void initState() {
    super.initState();
    _isGuestUser = _firebaseService.isCurrentUserGuest();
    _checkUsernameAndLoadData();
    _checkAdminAccess();
    if (!_isGuestUser) {
      _loadPremiumMembership();
      _premiumActivatedSub =
          _premiumService.premiumActivatedStream.listen((active) {
        if (active && mounted) _loadPremiumMembership();
      });
    } else {
      _premiumLoading = false;
    }
  }

  // Kullanıcı adı kontrolü ve veri yükleme
  Future<void> _checkUsernameAndLoadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firestore'da kullanıcı dokümanını kontrol et
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final username = userData?['username'] as String?;

          // Kullanıcı adı kontrolü
          if (username == null || username.isEmpty) {
            // Kullanıcı adı yoksa username setup ekranına yönlendir
            if (mounted) {
              Navigator.pushReplacementNamed(context, AppRouter.usernameSetup);
            }
            return;
          }
        }
      }

      // Kullanıcı adı varsa normal veri yükleme işlemlerini yap
      _loadUserData();
    } catch (e) {
      debugPrint('Username check error: $e');
      // Hata durumunda normal veri yükleme işlemlerini yap
      _loadUserData();
    }
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
    _premiumActivatedSub?.cancel();
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
        if (!mounted) return;
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
    if (!mounted) return;
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
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAppleUser = currentUser?.providerData
            .any((provider) => provider.providerId == 'apple.com') ??
        false;
    final requiresReauth =
        isAppleUser || await _firebaseService.requiresRecentLoginForDelete();
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
    final providerIds =
        currentUser.providerData.map((provider) => provider.providerId).toSet();
    final isAppleUser = providerIds.contains('apple.com');

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
              if (isAppleUser) ...[
                const Text(
                  'Apple hesabınızla yeniden doğrulama penceresi açılacak.',
                  textAlign: TextAlign.center,
                ),
              ] else ...[
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
              if (isAppleUser || formKey.currentState!.validate()) {
                try {
                  await _firebaseService.reauthenticateForAccountDeletion(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                  if (!context.mounted) return;
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
                    case 'credential-already-in-use':
                      errorMessage = 'Kimlik doğrulama bilgisi zaten kullanımda.';
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

  Future<void> _loadPremiumMembership() async {
    setState(() => _premiumLoading = true);
    try {
      final info = await _premiumService.fetchMembershipDetails();
      final hasAccess = await _premiumService.hasPremiumAccess();
      if (mounted) {
        setState(() {
          _premiumInfo = info;
          _hasPremiumAccess = hasAccess;
          _premiumLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Premium membership load error: $e');
      if (mounted) setState(() => _premiumLoading = false);
    }
  }

  Future<void> _openPremiumUpgrade() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PremiumUpgradeScreen(source: 'profile'),
      ),
    );
    if (!_isGuestUser) await _loadPremiumMembership();
  }

  Future<void> _restorePremiumPurchases() async {
    setState(() => _isLoading = true);
    try {
      await _paymentService.restorePurchases();
      await _premiumService.refreshPremiumStatus();
      await _loadPremiumMembership();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Satın alımlar kontrol edildi. Premium aktifse kısa süre içinde yansır.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geri yükleme başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _formatPremiumExpiry(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Future<void> _openSubscriptionManagementUrl() async {
    if (kIsWeb) return;
    final uri = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse(
            'https://play.google.com/store/account/subscriptions',
          );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mağaza bağlantısı açılamadı: $e')),
      );
    }
  }

  Future<void> _confirmCancelPremiumRenewal() async {
    final expiryNote = _formatPremiumExpiry(_premiumInfo?.expiryDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yenilemeyi iptal et'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expiryNote != null
                    ? 'Premium özellikleriniz bu hesapta $expiryNote tarihine kadar açık kalır.'
                    : 'Premium özellikleriniz mevcut üyelik süreniz dolana kadar açık kalır.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Bundan sonra yeni bir ücret tahsil edilmez; bir sonraki dönem için otomatik yenileme yapılmaz. '
                'Aboneliğinizi mağaza hesabınızdan da yönetebilirsiniz.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              _openSubscriptionManagementUrl();
            },
            child: const Text('Mağaza'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('İptali onayla'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _premiumService.setPremiumRenewalPreference(autoRenew: false);
      await _loadPremiumMembership();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yenileme iptali kaydedildi. Premium süreniz bitene kadar devam eder.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resumePremiumRenewal() async {
    setState(() => _isLoading = true);
    try {
      await _premiumService.setPremiumRenewalPreference(autoRenew: true);
      await _loadPremiumMembership();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Otomatik yenileme tekrar etkinleştirildi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPremiumMembershipSection() {
    if (_isGuestUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.star_outline,
            title: 'Premium Üyelik',
            iconColor: Colors.amber[700]!,
          ),
          const SizedBox(height: 12),
          Text(
            'Premium özellikler için kayıtlı bir hesapla giriş yapmanız gerekir.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRouter.login);
              },
              icon: const Icon(Icons.login),
              label: const Text('Giriş Yap / Kayıt Ol'),
            ),
          ),
        ],
      );
    }

    if (_premiumLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.star,
            title: 'Premium Üyelik',
            iconColor: Colors.amber[700]!,
          ),
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final info = _premiumInfo;
    final isActive = _hasPremiumAccess ||
        (info != null && info.isPremium && !info.isExpired);
    final expiryText = _formatPremiumExpiry(info?.expiryDate);
    final renewalCancelled = info?.renewalCancelled == true;
    final expiryNote =
        expiryText != null ? 'Premium $expiryText tarihine kadar devam eder.' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.star,
          title: 'Premium Üyelik',
          iconColor: Colors.amber[700]!,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isActive ? Colors.amber : Colors.grey)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isActive ? Colors.amber : Colors.grey)
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isActive ? Icons.verified : Icons.star_border,
                    color: isActive ? Colors.amber[800] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Premium Aktif' : 'Ücretsiz Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? Colors.amber[900]
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isActive && expiryText != null)
                Text(
                  'Geçerlilik: $expiryText',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else if (isActive)
                Text(
                  'Sınırsız arkadaş, sosyal turnuva ve reklamsız deneyim.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Text(
                  '3 arkadaş limiti. Sosyal turnuva oluşturma Premium ile açılır.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!isActive)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _openPremiumUpgrade,
              icon: const Icon(Icons.upgrade),
              label: const Text('Premium\'a Yükselt'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (isActive) ...[
          _premiumFeatureRow(Icons.people, 'Sınırsız arkadaş ekleme'),
          _premiumFeatureRow(Icons.emoji_events, 'Sosyal turnuva oluşturma'),
          _premiumFeatureRow(Icons.block, 'Reklamsız deneyim'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _openPremiumUpgrade,
              icon: const Icon(Icons.info_outline),
              label: const Text('Premium Ayrıntıları'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading
                  ? null
                  : (renewalCancelled
                      ? _resumePremiumRenewal
                      : _confirmCancelPremiumRenewal),
              style: FilledButton.styleFrom(
                backgroundColor:
                    renewalCancelled ? Colors.green[700] : Colors.red[700],
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                renewalCancelled ? Icons.refresh : Icons.cancel,
              ),
              label: Text(
                renewalCancelled
                    ? 'Yenilemeyi Aç'
                    : 'Yenilemeyi İptal Et',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            renewalCancelled
                ? 'Yenileme kapalı. ${expiryNote ?? 'Süreniz bitene kadar premium devam eder.'}'
                : 'Yenileme açık. İptal ederseniz premium süreniz bitene kadar devam eder.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _openSubscriptionManagementUrl,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Mağazada Abonelikleri Yönet'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.restore,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Satın Alımları Geri Yükle'),
          subtitle: const Text(
            'Daha önce satın aldıysanız App Store üzerinden geri yükleyin',
          ),
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isLoading ? null : _restorePremiumPurchases,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.refresh,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Durumu Yenile'),
          subtitle: const Text('Premium bilgisini sunucudan tekrar al'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  await _premiumService.refreshPremiumStatus();
                  await _loadPremiumMembership();
                  if (mounted) setState(() => _isLoading = false);
                },
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _premiumFeatureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  // Privacy Policy dialog'unu göster
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Gizlilik Politikası',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    PrivacyPolicy.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kapat'),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: BackgroundBoard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ana Profil Kartı - Tüm Özellikler Birleştirildi
                  StyledCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profil Bilgileri Bölümü
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
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
                                                  controller:
                                                      _usernameController,
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Section Divider
                          const SizedBox(height: 20),
                          Divider(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),

                          ListTile(
                            leading: Icon(
                              Icons.explore_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('Uygulama turu'),
                            subtitle: const Text(
                              'Ana sayfadaki özellikleri adım adım gör',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: () async {
                              await TutorialService.instance.resetForReplay();
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              Navigator.pushReplacementNamed(
                                context,
                                AppRouter.home,
                                arguments: true,
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                          Divider(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 20),

                          _buildPremiumMembershipSection(),

                          const SizedBox(height: 20),
                          Divider(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 20),

                          // Tema Ayarları Bölümü
                          _sectionHeader(
                            icon: Icons.palette,
                            title: 'Tema Ayarları',
                            iconColor: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Sistem Temasını Kullan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Otomatik tema değişimi',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                DiceSwitch(
                                  value: themeProvider.useSystemTheme,
                                  onChanged: (value) {
                                    themeProvider.setUseSystemTheme(value);
                                  },
                                  width: 70,
                                  height: 35,
                                  activeColor:
                                      Theme.of(context).colorScheme.primary,
                                  inactiveColor:
                                      Theme.of(context).colorScheme.outline,
                                ),
                              ],
                            ),
                          ),
                          if (!themeProvider.useSystemTheme) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Tema Seçimi:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'light',
                                  label: Text('Açık'),
                                ),
                                ButtonSegment<String>(
                                  value: 'dark',
                                  label: Text('Koyu'),
                                ),
                              ],
                              selected: {themeProvider.themeMode},
                              onSelectionChanged: (selection) {
                                if (selection.isNotEmpty) {
                                  themeProvider.setThemeMode(selection.first);
                                }
                              },
                            ),
                          ],

                          // Admin Panel Bölümü - Sadece adminlere göster
                          if (!_isAdminLoading && _isAdmin) ...[
                            const SizedBox(height: 20),
                            Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.3)),
                            const SizedBox(height: 20),
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
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Admin Panel',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
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
                                  await _verifyAdminAccessAndNavigate();
                                },
                                icon: const Icon(Icons.send),
                                label: const Text('Admin Paneli'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],

                          // Section Divider
                          const SizedBox(height: 20),
                          Divider(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 20),

                          // Privacy Policy Bölümü
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.privacy_tip,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Gizlilik Politikası',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Kişisel verilerinizin nasıl toplandığı, kullanıldığı ve korunduğu hakkında bilgi alın.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showPrivacyPolicy,
                              icon: const Icon(Icons.article),
                              label:
                                  const Text('Gizlilik Politikasını Görüntüle'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),

                          // Section Divider
                          const SizedBox(height: 20),
                          Divider(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 20),

                          // Hesap Silme Bölümü
                          Row(
                            children: [
                              Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Hesap Yönetimi',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hesabınızı kalıcı olarak silmek için aşağıdaki butonu kullanabilirsiniz.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _logout,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Çıkış Yap'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isLoading ? null : _deleteAccount,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Icon(Icons.delete_forever),
                                  label: Text(_isLoading
                                      ? 'Siliniyor...'
                                      : 'Hesabı Sil'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
