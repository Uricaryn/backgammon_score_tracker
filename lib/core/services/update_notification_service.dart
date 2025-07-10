import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';

class UpdateNotificationService {
  static final UpdateNotificationService _instance =
      UpdateNotificationService._internal();
  factory UpdateNotificationService() => _instance;
  UpdateNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logService = LogService();
  final NotificationService _notificationService = NotificationService();

  // Update notification constants
  static const String _updateNotificationTopic = 'app_updates_beta';
  static const String _updateNotificationChannel = 'update_notifications';

  /// Initialize update notification system
  Future<void> initialize() async {
    try {
      await _subscribeToUpdateNotifications();
      await _setupUpdateNotificationHandlers();
      _logService.info('Update notification service initialized',
          tag: 'UpdateNotification');
    } catch (e) {
      _logService.error('Failed to initialize update notification service',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Subscribe beta users to update notifications
  Future<void> _subscribeToUpdateNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Subscribe to update topic
        await FirebaseMessaging.instance
            .subscribeToTopic(_updateNotificationTopic);

        // Mark user as beta subscriber in Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'isBetaUser': true,
          'subscribedToUpdates': true,
          'lastUpdateCheck': FieldValue.serverTimestamp(),
        });

        _logService.info('User subscribed to update notifications',
            tag: 'UpdateNotification');
      }
    } catch (e) {
      _logService.error('Failed to subscribe to update notifications',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Setup handlers for update notifications
  Future<void> _setupUpdateNotificationHandlers() async {
    try {
      // Listen for foreground update notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleUpdateNotification(message);
      });

      // Listen for background update notifications
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleUpdateNotificationTap(message);
      });

      _logService.info('Update notification handlers setup complete',
          tag: 'UpdateNotification');
    } catch (e) {
      _logService.error('Failed to setup update notification handlers',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Handle incoming update notification
  Future<void> _handleUpdateNotification(RemoteMessage message) async {
    try {
      final data = message.data;

      // Check if this is an update notification
      if (data['type'] == 'app_update') {
        final String newVersion = data['new_version'] ?? '';
        final String updateMessage =
            data['update_message'] ?? 'Yeni güncelleme mevcut!';
        final bool forceUpdate = data['force_update'] == 'true';
        final String downloadUrl = data['download_url'] ?? '';

        // Create payload with download URL for local notification tap handling
        final payload = {
          'type': 'update_notification',
          'download_url': downloadUrl,
          'new_version': newVersion,
          'update_message': updateMessage,
          'force_update': forceUpdate.toString(),
        };

        // Show local notification
        await _notificationService.showNotification(
          title: '🚀 Yeni Güncelleme Mevcut!',
          body: 'Sürüm $newVersion • $updateMessage',
          payload: payload.toString(),
          saveToFirebase: true, // Save to user's notifications collection
        );

        // Save update info for later use
        await _saveUpdateInfo(
            newVersion, updateMessage, forceUpdate, downloadUrl);

        _logService.info('Update notification processed: $newVersion',
            tag: 'UpdateNotification');
      }
    } catch (e) {
      _logService.error('Failed to handle update notification',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Handle update notification tap
  Future<void> _handleUpdateNotificationTap(RemoteMessage message) async {
    try {
      final data = message.data;

      if (data['type'] == 'app_update') {
        final String downloadUrl = data['download_url'] ?? '';
        if (downloadUrl.isNotEmpty) {
          await _launchDownloadUrl(downloadUrl);
        }
      }
    } catch (e) {
      _logService.error('Failed to handle update notification tap',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Save update information locally
  Future<void> _saveUpdateInfo(String version, String message, bool forceUpdate,
      String downloadUrl) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'pendingUpdate': {
            'version': version,
            'message': message,
            'forceUpdate': forceUpdate,
            'downloadUrl': downloadUrl,
            'receivedAt': FieldValue.serverTimestamp(),
            'isShown': false,
          }
        });
      }
    } catch (e) {
      _logService.error('Failed to save update info',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Check for pending updates and show dialog
  Future<void> checkForPendingUpdates(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final pendingUpdate =
          userDoc.data()?['pendingUpdate'] as Map<String, dynamic>?;

      if (pendingUpdate != null && pendingUpdate['isShown'] != true) {
        final String version = pendingUpdate['version'] ?? '';
        final String message = pendingUpdate['message'] ?? '';
        final bool forceUpdate = pendingUpdate['forceUpdate'] ?? false;
        final String downloadUrl = pendingUpdate['downloadUrl'] ?? '';

        // Check if this version is newer than current
        if (await _isNewerVersion(version)) {
          _showUpdateDialog(
              context, version, message, forceUpdate, downloadUrl);

          // Mark as shown
          await _firestore.collection('users').doc(user.uid).update({
            'pendingUpdate.isShown': true,
          });
        }
      }
    } catch (e) {
      _logService.error('Failed to check pending updates',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Check if the given version is newer than current
  Future<bool> _isNewerVersion(String newVersion) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Simple version comparison (you might want to use a more robust method)
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final newParts = newVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final current = i < currentParts.length ? currentParts[i] : 0;
        final latest = i < newParts.length ? newParts[i] : 0;

        if (latest > current) return true;
        if (latest < current) return false;
      }

      return false;
    } catch (e) {
      _logService.error('Failed to compare versions',
          tag: 'UpdateNotification', error: e);
      return false;
    }
  }

  /// Show update dialog to user
  void _showUpdateDialog(BuildContext context, String version, String message,
      bool forceUpdate, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => AlertDialog(
        title: Row(
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
                Icons.system_update_alt,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚀 Yeni Güncelleme!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Sürüm $version',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.new_releases,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (forceUpdate) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu güncelleme zorunludur. Uygulamayı kullanmaya devam etmek için güncellemelisiniz.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'En son özellikleri ve güvenlik güncellemelerini almak için uygulamayı güncelleyin.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!forceUpdate) ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Daha Sonra'),
            ),
          ],
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _launchDownloadUrl(downloadUrl);
            },
            icon: const Icon(Icons.download),
            label: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  /// Launch download URL
  Future<void> _launchDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logService.info('Download URL opened: $url',
            tag: 'UpdateNotification');
      } else {
        _logService.error('Cannot launch download URL: $url',
            tag: 'UpdateNotification');
      }
    } catch (e) {
      _logService.error('Failed to launch download URL',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Admin method: Send update notification to all beta users
  /// This should be called from an admin panel or backend service
  Future<void> sendUpdateNotificationToAllBetaUsers({
    required String newVersion,
    required String updateMessage,
    required String downloadUrl,
    bool forceUpdate = false,
  }) async {
    try {
      // Create notification request document for Cloud Function to process
      await _firestore.collection('admin_notifications').add({
        'type': 'app_update',
        'targetAudience': 'beta_users',
        'data': {
          'new_version': newVersion,
          'update_message': updateMessage,
          'download_url': downloadUrl,
          'force_update': forceUpdate,
        },
        'topic': _updateNotificationTopic,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'createdBy': _auth.currentUser?.uid ?? 'system',
      });

      _logService.info(
          'Update notification queued for all beta users: $newVersion',
          tag: 'UpdateNotification');
    } catch (e) {
      _logService.error('Failed to send update notification to beta users',
          tag: 'UpdateNotification', error: e);
      throw e;
    }
  }

  /// Unsubscribe from update notifications
  Future<void> unsubscribeFromUpdateNotifications() async {
    try {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic(_updateNotificationTopic);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'subscribedToUpdates': false,
        });
      }

      _logService.info('User unsubscribed from update notifications',
          tag: 'UpdateNotification');
    } catch (e) {
      _logService.error('Failed to unsubscribe from update notifications',
          tag: 'UpdateNotification', error: e);
    }
  }

  /// Get update notification preferences
  Future<bool> isSubscribedToUpdateNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['subscribedToUpdates'] ?? false;
    } catch (e) {
      _logService.error('Failed to get update notification preferences',
          tag: 'UpdateNotification', error: e);
      return false;
    }
  }
}
