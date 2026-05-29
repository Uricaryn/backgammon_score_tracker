import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/models/notification_model.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    FirebaseService? firebaseService,
    NotificationService? notificationService,
    FirebaseFirestore? firestore,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _notificationService = notificationService ?? NotificationService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseService _firebaseService;
  final NotificationService _notificationService;
  final FirebaseFirestore _firestore;

  List<NotificationModel> _notifications = [];
  NotificationPreferences _preferences = NotificationPreferences();
  bool _isLoading = false;
  String? _error;
  int _unreadBadgeCount = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unreadSubscription;
  String? _badgeUserId;

  List<NotificationModel> get notifications => _notifications;
  NotificationPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get unreadBadgeCount => _unreadBadgeCount;

  void attachUnreadBadgeListener([String? userId]) {
    final resolvedUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUserId == null || resolvedUserId == _badgeUserId) {
      return;
    }

    _unreadSubscription?.cancel();
    _badgeUserId = resolvedUserId;

    _unreadSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: resolvedUserId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        final count = snapshot.docs.length;
        if (_unreadBadgeCount != count) {
          _unreadBadgeCount = count;
          notifyListeners();
        }
      },
      onError: (_) {},
    );
  }

  void detachUnreadBadgeListener() {
    _unreadSubscription?.cancel();
    _unreadSubscription = null;
    _badgeUserId = null;
    if (_unreadBadgeCount != 0) {
      _unreadBadgeCount = 0;
      notifyListeners();
    }
  }

  Future<void> loadNotifications() async {
    _setLoading(true);
    _clearError();

    try {
      _notifications = await _firebaseService.getNotifications();
      _unreadBadgeCount = unreadCount;
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationLoadFailed);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPreferences() async {
    try {
      _preferences = await _firebaseService.getNotificationPreferences();
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationPreferencesLoadFailed);
    }
  }

  Future<void> updatePreferences(NotificationPreferences newPreferences) async {
    _setLoading(true);
    _clearError();

    try {
      await _firebaseService.updateNotificationPreferences(newPreferences);
      _preferences = newPreferences;
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationPreferencesSaveFailed);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firebaseService.markNotificationAsRead(notificationId);

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      _setError(ErrorService.notificationSaveFailed);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firebaseService.deleteNotification(notificationId);

      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationDeleteFailed);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      for (final notification in _notifications) {
        if (!notification.isRead) {
          await _firebaseService.markNotificationAsRead(notification.id);
        }
      }

      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationSaveFailed);
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      for (final notification in _notifications) {
        await _firebaseService.deleteNotification(notification.id);
      }

      _notifications.clear();
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationDeleteFailed);
    }
  }

  Future<void> toggleNotificationType(String type) async {
    NotificationPreferences newPreferences;

    switch (type) {
      case 'enabled':
        newPreferences = _preferences.copyWith(enabled: !_preferences.enabled);
        await updatePreferences(newPreferences);
        break;
      default:
        return;
    }
  }

  List<NotificationModel> getFilteredNotifications(NotificationType? type) {
    if (type == null) return _notifications;
    return _notifications.where((n) => n.type == type).toList();
  }

  List<NotificationModel> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  List<NotificationModel> get readNotifications {
    return _notifications.where((n) => n.isRead).toList();
  }

  Future<void> startSocialNotifications() async {
    try {
      await _notificationService.setupSocialNotifications();
      final newPreferences = _preferences.copyWith(socialNotifications: true);
      await updatePreferences(newPreferences);
    } catch (e) {
      _setError('Sosyal bildirimler başlatılamadı');
    }
  }

  Future<void> stopSocialNotifications() async {
    try {
      await _notificationService.stopSocialNotifications();
      final newPreferences = _preferences.copyWith(socialNotifications: false);
      await updatePreferences(newPreferences);
    } catch (e) {
      _setError('Sosyal bildirimler durdurulamadı');
    }
  }

  Future<bool> checkSocialNotificationsStatus() async {
    try {
      return await _notificationService.areSocialNotificationsActive();
    } catch (e) {
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
