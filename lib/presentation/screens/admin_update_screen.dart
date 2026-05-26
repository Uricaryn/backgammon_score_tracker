import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/services/update_notification_service.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';
import 'package:backgammon_score_tracker/core/services/cloud_functions_safe_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';

class AdminUpdateScreen extends StatefulWidget {
  const AdminUpdateScreen({super.key});

  @override
  State<AdminUpdateScreen> createState() => _AdminUpdateScreenState();
}

class _AdminUpdateScreenState extends State<AdminUpdateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Update Notification Form
  final _updateFormKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _updateMessageController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _updateNotificationService = UpdateNotificationService();
  bool _forceUpdate = false;

  // General Notification Form
  final _generalFormKey = GlobalKey<FormState>();
  final _generalTitleController = TextEditingController();
  final _generalMessageController = TextEditingController();
  String _targetAudience = 'all_users';

  // Scheduled Notification Form
  final _scheduledFormKey = GlobalKey<FormState>();
  final _scheduledTitleController = TextEditingController();
  final _scheduledMessageController = TextEditingController();
  DateTime? _scheduledTime;
  String _scheduledTargetAudience = 'all_users';

  bool _isLoading = false;
  List<Map<String, dynamic>> _scheduledNotifications = [];
  final _cloudFunctionsSafe = CloudFunctionsSafeService();

  // User Management
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = false;
  final PremiumService _premiumService = PremiumService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // 5 tab'a çıkar
    _verifyAdminAccess();
    _loadScheduledNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();

    // Update controllers
    _versionController.dispose();
    _updateMessageController.dispose();
    _downloadUrlController.dispose();

    // General controllers
    _generalTitleController.dispose();
    _generalMessageController.dispose();

    // Scheduled controllers
    _scheduledTitleController.dispose();
    _scheduledMessageController.dispose();

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

  // Show success message
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Load scheduled notifications
  Future<void> _loadScheduledNotifications() async {
    if (!await _cloudFunctionsSafe.isEnabled()) {
      setState(() => _scheduledNotifications = []);
      return;
    }
    try {
      final result = await _cloudFunctionsSafe.call('getScheduledNotifications');
      if (result == null || result.data is! Map) {
        setState(() => _scheduledNotifications = []);
        return;
      }
      final data = result.data as Map;
      if (data['success'] == true) {
        setState(() {
          final notifications = data['notifications'] as List?;
          if (notifications != null) {
            _scheduledNotifications = notifications
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          } else {
            _scheduledNotifications = [];
          }
        });
      } else {
        setState(() => _scheduledNotifications = []);
      }

      if (result.data['success']) {
        setState(() {
          // Safe casting for Firebase Cloud Functions data
          final notifications = result.data['notifications'] as List?;
          if (notifications != null) {
            _scheduledNotifications = notifications
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          } else {
            _scheduledNotifications = [];
          }
        });
      } else {
        // If collection doesn't exist yet, initialize with empty list
        setState(() {
          _scheduledNotifications = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading scheduled notifications: $e');

      // Initialize with empty list if there's an error
      setState(() {
        _scheduledNotifications = [];
      });

      // Only show error for critical issues, not for empty collection
      if (e.toString().contains('not found') ||
          e.toString().contains('INTERNAL')) {
        debugPrint('Scheduled notifications collection not yet initialized');
      } else {
        _showError('Zamanlanmış bildirimler yüklenemedi: $e');
      }
    }
  }

  // Send update notification
  Future<void> _sendUpdateNotification() async {
    if (!_updateFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _updateNotificationService.sendUpdateNotificationToAllBetaUsers(
        newVersion: _versionController.text.trim(),
        updateMessage: _updateMessageController.text.trim(),
        downloadUrl: _downloadUrlController.text.trim(),
        forceUpdate: _forceUpdate,
      );

      _showSuccess('Güncelleme bildirimi başarıyla gönderildi!');
      _updateFormKey.currentState!.reset();
      _versionController.clear();
      _updateMessageController.clear();
      _downloadUrlController.clear();
      setState(() => _forceUpdate = false);
    } catch (e) {
      _showError('Güncelleme bildirimi gönderilemedi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Send general notification
  Future<void> _sendGeneralNotification() async {
    if (!_generalFormKey.currentState!.validate()) return;
    if (!await _cloudFunctionsSafe.isEnabled()) {
      _showError(
          'Genel bildirim bu platformda geçici olarak devre dışı.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _cloudFunctionsSafe.call(
        'sendGeneralNotification',
        data: {
          'title': _generalTitleController.text.trim(),
          'message': _generalMessageController.text.trim(),
          'targetAudience': _targetAudience,
        },
      );

      if (result != null && result.data is Map && (result.data as Map)['success'] == true) {
        final map = result.data as Map;
        _showSuccess(
            'Genel bildirim başarıyla gönderildi! (${map['totalSent']} kullanıcı)');
        _generalFormKey.currentState!.reset();
        _generalTitleController.clear();
        _generalMessageController.clear();
        setState(() {
          _targetAudience = 'all_users';
        });
      } else {
        _showError('Genel bildirim gönderilemedi');
      }
    } catch (e) {
      _showError('Genel bildirim gönderilemedi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Schedule notification
  Future<void> _scheduleNotification() async {
    if (!_scheduledFormKey.currentState!.validate()) return;
    if (!await _cloudFunctionsSafe.isEnabled()) {
      _showError(
          'Zamanlanmış bildirim bu platformda geçici olarak devre dışı.');
      return;
    }
    if (_scheduledTime == null) {
      _showError('Lütfen bir tarih ve saat seçin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _cloudFunctionsSafe.call(
        'scheduleNotification',
        data: {
          'title': _scheduledTitleController.text.trim(),
          'message': _scheduledMessageController.text.trim(),
          'scheduledTime': _scheduledTime!.toIso8601String(),
          'targetAudience': _scheduledTargetAudience,
        },
      );

      if (result != null && result.data is Map && (result.data as Map)['success'] == true) {
        _showSuccess('Bildirim başarıyla zamanlandı!');
        _scheduledFormKey.currentState!.reset();
        _scheduledTitleController.clear();
        _scheduledMessageController.clear();
        setState(() {
          _scheduledTime = null;
          _scheduledTargetAudience = 'all_users';
        });
        _loadScheduledNotifications();
      } else {
        _showError('Bildirim zamanlanamadı');
      }
    } catch (e) {
      _showError('Bildirim zamanlanamadı: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Cancel scheduled notification
  Future<void> _cancelScheduledNotification(String notificationId) async {
    if (!await _cloudFunctionsSafe.isEnabled()) {
      _showError('Bu özellik geçici olarak bakımda.');
      return;
    }
    try {
      final result = await _cloudFunctionsSafe.call(
        'cancelScheduledNotification',
        data: {'notificationId': notificationId},
      );

      if (result != null && result.data is Map && (result.data as Map)['success'] == true) {
        _showSuccess('Zamanlanmış bildirim iptal edildi!');
        _loadScheduledNotifications();
      } else {
        _showError('Bildirim iptal edilemedi');
      }
    } catch (e) {
      _showError('Bildirim iptal edilemedi: $e');
    }
  }

  // Run user migration
  Future<void> _runUserMigration() async {
    if (!await _cloudFunctionsSafe.isEnabled()) {
      _showError('Migration işlemi geçici olarak bakımda.');
      return;
    }
    if (!mounted) return;
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcı Verilerini Düzelt'),
        content: const Text(
          'Bu işlem tüm kullanıcılara isActive field\'ını ekleyecek. '
          'Bu işlem geri alınamaz. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await _cloudFunctionsSafe.call('migrateUserActiveField');

      if (result != null && result.data is Map && (result.data as Map)['success'] == true) {
        final map = result.data as Map;
        _showSuccess(
          'Migration tamamlandı! ${map['updatedUsers']} kullanıcı güncellendi. '
          'Toplam kullanıcı: ${map['totalUsers']}',
        );
      } else {
        _showError('Migration başarısız oldu');
      }
    } catch (e) {
      _showError('Migration hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Admin Bildirim Paneli'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.system_update), text: 'Güncelleme'),
            Tab(icon: Icon(Icons.notifications), text: 'Genel'),
            Tab(icon: Icon(Icons.schedule), text: 'Zamanlanmış'),
            Tab(icon: Icon(Icons.people), text: 'Kullanıcılar'),
            Tab(icon: Icon(Icons.star), text: 'Premium'),
          ],
        ),
      ),
      body: BackgroundBoard(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildUpdateNotificationTab(),
            _buildGeneralNotificationTab(),
            _buildScheduledNotificationTab(),
            _buildUserManagementTab(),
            _buildPremiumManagementTab(),
          ],
        ),
      ),
    );
  }

  // Update Notification Tab
  Widget _buildUpdateNotificationTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _updateFormKey,
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
                        Icons.system_update,
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
                          color: Colors.white.withValues(alpha: 0.2),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _updateMessageController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Güncelleme Mesajı',
                          hintText: 'Yeni özellikler ve düzeltmeler...',
                          prefixIcon: Icon(Icons.message),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _downloadUrlController,
                        decoration: const InputDecoration(
                          labelText: 'İndirme Linki',
                          hintText: 'https://example.com/download',
                          prefixIcon: Icon(Icons.download),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'İndirme linki gerekli';
                          }
                          if (Uri.tryParse(value.trim())?.hasAbsolutePath !=
                              true) {
                            return 'Geçerli bir URL girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Zorunlu Güncelleme'),
                        subtitle:
                            const Text('Kullanıcılar eski sürümü kullanamaz'),
                        value: _forceUpdate,
                        onChanged: (value) =>
                            setState(() => _forceUpdate = value ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Send Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendUpdateNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Güncelleme Bildirimi Gönder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  // General Notification Tab
  Widget _buildGeneralNotificationTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _generalFormKey,
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
                        Colors.blue,
                        Colors.purple,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tüm Kullanıcılara\nGenel Bildirim Gönder',
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Anında Gönderim',
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

              // Notification Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit_notifications,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bildirim İçeriği',
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
                        controller: _generalTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Bildirim Başlığı',
                          hintText: 'Önemli Duyuru',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Başlık gerekli';
                          }
                          if (value.trim().length < 3) {
                            return 'Başlık en az 3 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _generalMessageController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Bildirim Mesajı',
                          hintText:
                              'Kullanıcılarınıza göndermek istediğiniz mesaj...',
                          prefixIcon: Icon(Icons.message),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mesaj gerekli';
                          }
                          if (value.trim().length < 10) {
                            return 'Mesaj en az 10 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Target Audience
                      Text(
                        'Hedef Kitle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _targetAudience,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'all_users',
                              child: Text('Tüm Kullanıcılar')),
                          DropdownMenuItem(
                              value: 'beta_users',
                              child: Text('Beta Kullanıcıları')),
                          DropdownMenuItem(
                              value: 'active_users',
                              child: Text('Aktif Kullanıcılar')),
                        ],
                        onChanged: (value) =>
                            setState(() => _targetAudience = value!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Migration Card
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.build,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kullanıcı Verisi Düzeltme',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Eğer "No active users found" hatası alıyorsanız, kullanıcılara isActive field\'ını eklemek için migration çalıştırın.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _runUserMigration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('Kullanıcı Verilerini Düzelt'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Send Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendGeneralNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Bildirim Gönder',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Scheduled Notification Tab
  Widget _buildScheduledNotificationTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                      Colors.orange,
                      Colors.red,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Zamanlanmış Bildirimler',
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Otomatik Gönderim',
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

            // Schedule New Notification Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _scheduledFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_alarm,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Yeni Zamanlanmış Bildirim',
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
                        controller: _scheduledTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Bildirim Başlığı',
                          hintText: 'Hatırlatma',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Başlık gerekli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _scheduledMessageController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Bildirim Mesajı',
                          hintText: 'Zamanlanmış mesaj içeriği...',
                          prefixIcon: Icon(Icons.message),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mesaj gerekli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date Time Picker
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() {
                                _scheduledTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text(
                                _scheduledTime == null
                                    ? 'Tarih ve Saat Seçin'
                                    : '${_scheduledTime!.day}/${_scheduledTime!.month}/${_scheduledTime!.year} ${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: _scheduledTime == null
                                      ? Colors.grey
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Target Audience
                      DropdownButtonFormField<String>(
                        initialValue: _scheduledTargetAudience,
                        decoration: const InputDecoration(
                          labelText: 'Hedef Kitle',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'all_users',
                              child: Text('Tüm Kullanıcılar')),
                          DropdownMenuItem(
                              value: 'beta_users',
                              child: Text('Beta Kullanıcıları')),
                          DropdownMenuItem(
                              value: 'active_users',
                              child: Text('Aktif Kullanıcılar')),
                        ],
                        onChanged: (value) =>
                            setState(() => _scheduledTargetAudience = value!),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _scheduleNotification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Bildirimi Zamanla',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Scheduled Notifications List
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.list,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Zamanlanmış Bildirimler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadScheduledNotifications,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_scheduledNotifications.isEmpty)
                      const Center(
                        child: Text(
                          'Zamanlanmış bildirim yok',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _scheduledNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = _scheduledNotifications[index];
                          final scheduledTime =
                              DateTime.parse(notification['scheduledTime']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.schedule,
                                  color: Colors.orange),
                              title: Text(
                                notification['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification['message']),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _cancelScheduledNotification(
                                    notification['id']),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Load users
  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _users = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      });
    } catch (e) {
      _showError('Kullanıcılar yüklenemedi: $e');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  // Toggle user active status
  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isActive': !currentStatus});

      _showSuccess('Kullanıcı durumu güncellendi');
      _loadUsers();
    } catch (e) {
      _showError('Kullanıcı durumu güncellenemedi: $e');
    }
  }

  // Delete user account
  Future<void> _deleteUser(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcı Hesabını Sil'),
        content: Text(
            '$email hesabını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete user document from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        // Delete user's games
        final gamesQuery = await FirebaseFirestore.instance
            .collection('games')
            .where('userId', isEqualTo: userId)
            .get();

        for (var doc in gamesQuery.docs) {
          await doc.reference.delete();
        }

        // Delete user's players
        final playersQuery = await FirebaseFirestore.instance
            .collection('players')
            .where('userId', isEqualTo: userId)
            .get();

        for (var doc in playersQuery.docs) {
          await doc.reference.delete();
        }

        _showSuccess('Kullanıcı hesabı ve tüm verileri silindi');
        _loadUsers();
      } catch (e) {
        _showError('Kullanıcı silinemedi: $e');
      }
    }
  }

  // Show user details dialog
  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person),
            SizedBox(width: 8),
            Text('Kullanıcı Detayları'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user['email'] ?? 'N/A'),
              _buildDetailRow(
                  'Durum', (user['isActive'] ?? true) ? 'Aktif' : 'Pasif'),
              _buildDetailRow(
                  'Admin', (user['isAdmin'] ?? false) ? 'Evet' : 'Hayır'),
              _buildDetailRow('Beta Kullanıcısı',
                  (user['isBetaUser'] ?? false) ? 'Evet' : 'Hayır'),
              _buildDetailRow(
                  'Oluşturma Tarihi', _formatDate(user['createdAt'])),
              _buildDetailRow('Son Giriş', _formatDate(user['lastLoginAt'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  // User Management Tab
  Widget _buildUserManagementTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                      Icons.people,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kullanıcı Yönetimi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toplam ${_users.length} kullanıcı',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingUsers ? null : _loadUsers,
                    icon: _isLoadingUsers
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Yenile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runUserMigration,
                    icon: const Icon(Icons.build),
                    label: const Text('Migration'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Toplam Kullanıcı',
                    _users.length.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Aktif Kullanıcı',
                    _users
                        .where((u) => u['isActive'] ?? true)
                        .length
                        .toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Admin Kullanıcı',
                    _users
                        .where((u) => u['isAdmin'] ?? false)
                        .length
                        .toString(),
                    Icons.admin_panel_settings,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Beta Kullanıcı',
                    _users
                        .where((u) => u['isBetaUser'] ?? false)
                        .length
                        .toString(),
                    Icons.science,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Users List
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.list,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kullanıcı Listesi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingUsers)
                      const Center(child: CircularProgressIndicator())
                    else if (_users.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Kullanıcı bulunamadı\nYenilemek için yukarıdaki butonu kullanın',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isActive = user['isActive'] ?? true;
                          final isAdmin = user['isAdmin'] ?? false;
                          final isBeta = user['isBetaUser'] ?? false;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                child: Icon(
                                  isActive ? Icons.person : Icons.person_off,
                                  color: isActive ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                user['email'] ?? 'Email not found',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${user['id']}'),
                                  Row(
                                    children: [
                                      if (isAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.purple.withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text('Admin',
                                              style: TextStyle(fontSize: 10)),
                                        ),
                                      if (isBeta) ...[
                                        if (isAdmin) const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.orange.withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text('Beta',
                                              style: TextStyle(fontSize: 10)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    onTap: () => Future.delayed(
                                      Duration.zero,
                                      () => _showUserDetails(user),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info),
                                        SizedBox(width: 8),
                                        Text('Detaylar'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    onTap: () => Future.delayed(
                                      Duration.zero,
                                      () => _toggleUserStatus(
                                          user['id'], isActive),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isActive
                                            ? Icons.block
                                            : Icons.check_circle),
                                        const SizedBox(width: 8),
                                        Text(isActive
                                            ? 'Pasifleştir'
                                            : 'Aktifleştir'),
                                      ],
                                    ),
                                  ),
                                  if (!isAdmin) // Don't allow deleting admin users
                                    PopupMenuItem(
                                      onTap: () => Future.delayed(
                                        Duration.zero,
                                        () => _deleteUser(
                                            user['id'], user['email'] ?? ''),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Hesabı Sil',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Premium Management Tab
  Widget _buildPremiumManagementTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                      Colors.amber[700]!,
                      Colors.amber[500]!,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Premium Kullanıcı Yönetimi',
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Admin Paneli',
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

            // Premium Features Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Premium Özellikler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPremiumFeatureItem('Sınırsız arkadaş ekleme'),
                    _buildPremiumFeatureItem('Sosyal turnuva oluşturma'),
                    _buildPremiumFeatureItem('Öncelikli destek'),
                    _buildPremiumFeatureItem('Reklamsız deneyim'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Premium User Management
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
                        const SizedBox(width: 8),
                        Text(
                          'Premium Kullanıcı Yönetimi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kullanıcıların premium durumunu yönetmek için önce kullanıcı listesini yükleyin.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingUsers ? null : _loadUsers,
                        icon: const Icon(Icons.refresh),
                        label: Text(_isLoadingUsers
                            ? 'Yükleniyor...'
                            : 'Kullanıcıları Yükle'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Premium Users List
            if (_users.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Premium Kullanıcılar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isPremium = user['isPremium'] ?? false;
                          final premiumExpiry = user['premiumExpiry'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPremium
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                child: Icon(
                                  isPremium ? Icons.star : Icons.star_border,
                                  color: isPremium
                                      ? Colors.amber[700]
                                      : Colors.grey,
                                ),
                              ),
                              title: Text(
                                user['email'] ?? 'Email not found',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${user['id']}'),
                                  if (isPremium && premiumExpiry != null)
                                    Text(
                                      'Premium Bitiş: ${_formatPremiumDate(premiumExpiry)}',
                                      style: TextStyle(
                                        color: _isExpired(premiumExpiry)
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    onTap: () => Future.delayed(
                                      Duration.zero,
                                      () => _showPremiumUserDetails(user),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info),
                                        SizedBox(width: 8),
                                        Text('Detaylar'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    onTap: () => Future.delayed(
                                      Duration.zero,
                                      () => _togglePremiumStatus(
                                          user['id'], isPremium),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isPremium
                                            ? Icons.star_border
                                            : Icons.star),
                                        const SizedBox(width: 8),
                                        Text(isPremium
                                            ? 'Premium\'ı Kaldır'
                                            : 'Premium Yap'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(feature),
        ],
      ),
    );
  }

  String _formatPremiumDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
    }
    return 'Bilinmeyen';
  }

  bool _isExpired(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().isBefore(DateTime.now());
    }
    return false;
  }

  void _showPremiumUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Kullanıcı Detayları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user['email']}'),
            Text('ID: ${user['id']}'),
            Text('Premium: ${user['isPremium'] ?? false}'),
            if (user['premiumExpiry'] != null)
              Text(
                  'Premium Bitiş: ${_formatPremiumDate(user['premiumExpiry'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePremiumStatus(String userId, bool currentStatus) async {
    try {
      if (currentStatus) {
        // Premium'ı kaldır
        await _premiumService.updatePremiumStatus(userId, false);
        _showSuccess('Premium durumu kaldırıldı');
      } else {
        // Premium yap - 1 yıl süreyle
        final expiryDate = DateTime.now().add(const Duration(days: 365));
        await _premiumService.updatePremiumStatus(userId, true,
            expiryDate: expiryDate);
        _showSuccess('Kullanıcı premium yapıldı (1 yıl)');
      }

      // Kullanıcı listesini yenile
      _loadUsers();
    } catch (e) {
      _showError('Premium durumu güncellenemedi: $e');
    }
  }
}
