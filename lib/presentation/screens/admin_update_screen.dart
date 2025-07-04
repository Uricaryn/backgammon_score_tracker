import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:backgammon_score_tracker/core/services/update_notification_service.dart';
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
  bool _sendToAll = false;

  // Scheduled Notification Form
  final _scheduledFormKey = GlobalKey<FormState>();
  final _scheduledTitleController = TextEditingController();
  final _scheduledMessageController = TextEditingController();
  DateTime? _scheduledTime;
  String _scheduledTargetAudience = 'all_users';

  bool _isLoading = false;
  List<Map<String, dynamic>> _scheduledNotifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getScheduledNotifications');

      // Add timeout to prevent hanging
      final result = await callable.call().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'İstek zaman aşımına uğradı', const Duration(seconds: 10));
        },
      );

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
      print('Error loading scheduled notifications: $e');

      // Initialize with empty list if there's an error
      setState(() {
        _scheduledNotifications = [];
      });

      // Only show error for critical issues, not for empty collection
      if (e.toString().contains('not found') ||
          e.toString().contains('INTERNAL')) {
        print('Scheduled notifications collection not yet initialized');
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

    setState(() => _isLoading = true);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendGeneralNotification');
      final result = await callable.call({
        'title': _generalTitleController.text.trim(),
        'message': _generalMessageController.text.trim(),
        'targetAudience': _targetAudience,
        'sendToAll': _sendToAll,
      });

      if (result.data['success']) {
        _showSuccess(
            'Genel bildirim başarıyla gönderildi! (${result.data['totalSent']} kullanıcı)');
        _generalFormKey.currentState!.reset();
        _generalTitleController.clear();
        _generalMessageController.clear();
        setState(() {
          _targetAudience = 'all_users';
          _sendToAll = false;
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
    if (_scheduledTime == null) {
      _showError('Lütfen bir tarih ve saat seçin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('scheduleNotification');
      final result = await callable.call({
        'title': _scheduledTitleController.text.trim(),
        'message': _scheduledMessageController.text.trim(),
        'scheduledTime': _scheduledTime!.toIso8601String(),
        'targetAudience': _scheduledTargetAudience,
      });

      if (result.data['success']) {
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
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('cancelScheduledNotification');
      final result = await callable.call({'notificationId': notificationId});

      if (result.data['success']) {
        _showSuccess('Zamanlanmış bildirim iptal edildi!');
        _loadScheduledNotifications();
      } else {
        _showError('Bildirim iptal edilemedi');
      }
    } catch (e) {
      _showError('Bildirim iptal edilemedi: $e');
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
                          color: Colors.white.withOpacity(0.2),
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
                        value: _targetAudience,
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
                      const SizedBox(height: 16),

                      CheckboxListTile(
                        title: const Text('Herkese Gönder'),
                        subtitle: const Text(
                            'Aktif olmayan kullanıcıları da dahil et'),
                        value: _sendToAll,
                        onChanged: (value) =>
                            setState(() => _sendToAll = value ?? false),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Genel Bildirim Gönder',
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
                        color: Colors.white.withOpacity(0.2),
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
                        value: _scheduledTargetAudience,
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
}
