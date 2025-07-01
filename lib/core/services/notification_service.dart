import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Sosyal bildirim ID'leri
  static const int _morningReminderId = 1001;
  static const int _afternoonReminderId = 1002;
  static const int _eveningReminderId = 1003;

  // Sosyal bildirim saatleri
  static const int _morningHour = 10; // 10:00
  static const int _afternoonHour = 15; // 15:00
  static const int _eveningHour = 20; // 20:00

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android ayarları
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS ayarları
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Genel ayarlar
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
    } catch (e) {
      throw Exception(ErrorService.notificationServiceUnavailable);
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    NotificationType type = NotificationType.general,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        throw Exception(ErrorService.notificationPermissionDenied);
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'backgammon_channel',
        'Tavla Bildirimleri',
        channelDescription: 'Tavla skor takip uygulaması bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      throw Exception(ErrorService.notificationSendFailed);
    }
  }

  Future<void> showScheduledNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationType type = NotificationType.general,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        throw Exception(ErrorService.notificationPermissionDenied);
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'backgammon_reminder_channel',
        'Tavla Hatırlatıcıları',
        channelDescription: 'Tavla oyun hatırlatıcı bildirimleri',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      throw Exception(ErrorService.notificationSendFailed);
    }
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Burada bildirime tıklandığında yapılacak işlemler
    // Örneğin: Belirli bir sayfaya yönlendirme
  }

  // Bildirim kanallarını oluştur
  Future<void> createNotificationChannels() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
        'backgammon_channel',
        'Tavla Bildirimleri',
        description: 'Tavla skor takip uygulaması ana bildirimleri',
        importance: Importance.high,
      );

      const AndroidNotificationChannel reminderChannel =
          AndroidNotificationChannel(
        'backgammon_reminder_channel',
        'Tavla Hatırlatıcıları',
        description: 'Tavla oyun hatırlatıcı bildirimleri',
        importance: Importance.defaultImportance,
      );

      const AndroidNotificationChannel socialChannel =
          AndroidNotificationChannel(
        'backgammon_social_channel',
        'Tavla Sosyal Bildirimleri',
        description: 'Tavla sosyal etkileşim bildirimleri',
        importance: Importance.defaultImportance,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(mainChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(reminderChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(socialChannel);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  // Sosyal bildirimleri ayarla
  Future<void> setupSocialNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Önceki sosyal bildirimleri iptal et
      await cancelNotification(_morningReminderId);
      await cancelNotification(_afternoonReminderId);
      await cancelNotification(_eveningReminderId);

      // Günlük sosyal bildirimleri ayarla
      await _scheduleDailySocialNotification(
        _morningReminderId,
        _morningHour,
        'Günaydın! 🎲',
        'Yeni bir tavla günü başladı! Arkadaşlarınızla oyun oynamaya ne dersiniz?',
      );

      await _scheduleDailySocialNotification(
        _afternoonReminderId,
        _afternoonHour,
        'Öğleden Sonra Molası ☕',
        'Tavla oynayarak stres atmanın tam zamanı! Hemen bir oyun başlatın.',
      );

      await _scheduleDailySocialNotification(
        _eveningReminderId,
        _eveningHour,
        'Akşam Vakti 🏆',
        'Günün sonunda tavla şampiyonluğunu kim kazanacak? Hemen oynamaya başlayın!',
      );
    } catch (e) {
      print('Sosyal bildirimler ayarlanırken hata: $e');
    }
  }

  // Günlük sosyal bildirim zamanla
  Future<void> _scheduleDailySocialNotification(
    int id,
    int hour,
    String title,
    String body,
  ) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return;

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour);

      // Eğer bugünün saati geçtiyse, yarına ayarla
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'backgammon_social_channel',
        'Tavla Sosyal Bildirimleri',
        channelDescription: 'Tavla sosyal etkileşim bildirimleri',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'social_reminder',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Günlük bildirim zamanlanırken hata: $e');
    }
  }

  // Sosyal bildirimleri durdur
  Future<void> stopSocialNotifications() async {
    await cancelNotification(_morningReminderId);
    await cancelNotification(_afternoonReminderId);
    await cancelNotification(_eveningReminderId);
  }

  // Sosyal bildirim durumunu kontrol et
  Future<bool> areSocialNotificationsActive() async {
    try {
      final pendingNotifications =
          await _localNotifications.pendingNotificationRequests();
      return pendingNotifications.any((notification) =>
          notification.id == _morningReminderId ||
          notification.id == _afternoonReminderId ||
          notification.id == _eveningReminderId);
    } catch (e) {
      return false;
    }
  }
}
