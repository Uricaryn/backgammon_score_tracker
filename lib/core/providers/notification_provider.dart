import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/models/notification_model.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  NotificationPreferences _preferences = NotificationPreferences();
  bool _isLoading = false;
  String? _error;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  NotificationPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Bildirimleri yükle
  Future<void> loadNotifications() async {
    _setLoading(true);
    _clearError();

    try {
      _notifications = await _firebaseService.getNotifications();
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationLoadFailed);
    } finally {
      _setLoading(false);
    }
  }

  // Bildirim tercihlerini yükle
  Future<void> loadPreferences() async {
    try {
      _preferences = await _firebaseService.getNotificationPreferences();
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationPreferencesLoadFailed);
    }
  }

  // Bildirim tercihlerini güncelle
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

  // Bildirimi okundu olarak işaretle
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firebaseService.markNotificationAsRead(notificationId);

      // Local state'i güncelle
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      _setError(ErrorService.notificationSaveFailed);
    }
  }

  // Bildirimi sil
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firebaseService.deleteNotification(notificationId);

      // Local state'den kaldır
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationDeleteFailed);
    }
  }

  // Tüm bildirimleri okundu olarak işaretle
  Future<void> markAllAsRead() async {
    try {
      for (final notification in _notifications) {
        if (!notification.isRead) {
          await _firebaseService.markNotificationAsRead(notification.id);
        }
      }

      // Local state'i güncelle
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (e) {
      _setError(ErrorService.notificationSaveFailed);
    }
  }

  // Tüm bildirimleri sil
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

  // Bildirim tercihlerini toggle et
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

  // Bildirimleri filtrele
  List<NotificationModel> getFilteredNotifications(NotificationType? type) {
    if (type == null) return _notifications;
    return _notifications.where((n) => n.type == type).toList();
  }

  // Okunmamış bildirimleri getir
  List<NotificationModel> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  // Okunmuş bildirimleri getir
  List<NotificationModel> get readNotifications {
    return _notifications.where((n) => n.isRead).toList();
  }

  // Sosyal bildirimleri başlat
  Future<void> startSocialNotifications() async {
    try {
      await _notificationService.setupSocialNotifications();
      // Tercihleri güncelle
      final newPreferences = _preferences.copyWith(socialNotifications: true);
      await updatePreferences(newPreferences);
    } catch (e) {
      _setError('Sosyal bildirimler başlatılamadı');
    }
  }

  // Sosyal bildirimleri durdur
  Future<void> stopSocialNotifications() async {
    try {
      await _notificationService.stopSocialNotifications();
      // Tercihleri güncelle
      final newPreferences = _preferences.copyWith(socialNotifications: false);
      await updatePreferences(newPreferences);
    } catch (e) {
      _setError('Sosyal bildirimler durdurulamadı');
    }
  }

  // Sosyal bildirim durumunu kontrol et
  Future<bool> checkSocialNotificationsStatus() async {
    try {
      return await _notificationService.areSocialNotificationsActive();
    } catch (e) {
      return false;
    }
  }

  // Private helper methods
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

  // Provider dispose
  @override
  void dispose() {
    super.dispose();
  }
}
