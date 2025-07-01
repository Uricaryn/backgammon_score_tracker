import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/models/notification_model.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  bool _isInitialized = false;
  String? _fcmToken;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Bildirim izinlerini iste
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('User granted provisional permission');
      } else {
        debugPrint('User declined or has not accepted permission');
        throw Exception(ErrorService.notificationPermissionDenied);
      }

      // FCM token'ı al
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        debugPrint('FCM Token: $_fcmToken');
        await _saveFCMToken(_fcmToken!);
      }

      // Token yenilendiğinde
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMToken(newToken);
      });

      // Foreground mesajları için
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background mesajları için
      // Background handler main.dart'ta tanımlanmış

      // Bildirime tıklandığında
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Uygulama kapalıyken açıldığında
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      _isInitialized = true;
      debugPrint('Firebase Messaging initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
      throw Exception(ErrorService.notificationServiceUnavailable);
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM token saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint(
          'Message also contained a notification: ${message.notification}');

      // Yerel bildirim göster
      await _notificationService.showNotification(
        title: message.notification!.title ?? 'Yeni Bildirim',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );

      // Bildirimi Firestore'a kaydet
      await _saveNotificationToFirestore(message);
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('A new onMessageOpenedApp event was published!');
    debugPrint('Message data: ${message.data}');

    // Burada bildirime tıklandığında yapılacak işlemler
    // Örneğin: Belirli bir sayfaya yönlendirme
  }

  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('notifications').add({
          'userId': user.uid,
          'title': message.notification?.title ?? 'Yeni Bildirim',
          'body': message.notification?.body ?? '',
          'data': message.data,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': _getNotificationType(message.data),
        });
        debugPrint('Notification saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving notification to Firestore: $e');
    }
  }

  NotificationType _getNotificationType(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'social':
        return NotificationType.social;
      default:
        return NotificationType.general;
    }
  }

  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    NotificationType type = NotificationType.general,
  }) async {
    try {
      // Kullanıcının FCM token'ını al
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception(ErrorService.authUserNotFound);
      }

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null) {
        throw Exception(ErrorService.notificationTokenFailed);
      }

      // Cloud Function ile bildirim gönder
      // Bu kısım Firebase Cloud Functions gerektirir
      await _firestore.collection('notification_requests').add({
        'userId': userId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
        'type': type.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('Notification request sent for user: $userId');
    } catch (e) {
      debugPrint('Error sending notification: $e');
      throw Exception(ErrorService.notificationSendFailed);
    }
  }

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => NotificationModel.fromMap({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      throw Exception(ErrorService.notificationLoadFailed);
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      debugPrint('Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      throw Exception(ErrorService.notificationSaveFailed);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      debugPrint('Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      throw Exception(ErrorService.notificationDeleteFailed);
    }
  }

  Future<NotificationPreferences> getNotificationPreferences() async {
    try {
      debugPrint('Getting notification preferences...');

      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found for preferences');
        throw Exception(ErrorService.authUserNotFound);
      }

      debugPrint('User found: ${user.uid}');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        debugPrint(
            'User document does not exist, returning default preferences');
        return NotificationPreferences();
      }

      final data = userDoc.data()!;
      final preferences = NotificationPreferences.fromMap({
        'enabled': data['notificationEnabled'] ?? true,
        'socialNotifications': data['socialNotifications'] ?? true,
        'fcmToken': data['fcmToken'],
      });

      debugPrint(
          'Notification preferences loaded: enabled=${preferences.enabled}, socialNotifications=${preferences.socialNotifications}');
      return preferences;
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
      throw Exception(ErrorService.notificationPreferencesLoadFailed);
    }
  }

  Future<void> updateNotificationPreferences(
      NotificationPreferences preferences) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      await _firestore.collection('users').doc(user.uid).update({
        'notificationEnabled': preferences.enabled,
        'socialNotifications': preferences.socialNotifications,
        'fcmToken': preferences.fcmToken,
        'lastPreferencesUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('Notification preferences updated');
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
      throw Exception(ErrorService.notificationPreferencesSaveFailed);
    }
  }

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
}

// Background message handler main.dart'ta tanımlanmış
