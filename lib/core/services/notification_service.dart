import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
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
  static const int _welcomeNotificationId = 1004;

  // Sosyal bildirim saatleri
  static const int _morningHour = 10; // 10:00
  static const int _afternoonHour = 15; // 15:00
  static const int _eveningHour = 20; // 20:00

  // Shared preferences key'leri
  static const String _lastWelcomeNotificationKey = 'last_welcome_notification';

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
    bool saveToFirebase = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        // Don't throw exception, try to show notification anyway
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

      final notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      // Firebase'e kaydet (eğer istenirse)
      if (saveToFirebase) {
        await _saveNotificationToFirebase(title, body, type, payload);
      }
    } catch (e) {
      // Don't throw exception, just log the error
      // throw Exception(ErrorService.notificationSendFailed);
    }
  }

  // Bildirimi Firebase'e kaydet
  Future<void> _saveNotificationToFirebase(
    String title,
    String body,
    NotificationType type,
    String? payload,
  ) async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final user = auth.currentUser;
      if (user != null && !user.isAnonymous) {
        await firestore.collection('notifications').add({
          'userId': user.uid,
          'title': title,
          'body': body,
          'type': type.toString().split('.').last,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'payload': payload,
            'source': 'local_notification',
            'timestamp': DateTime.now().toIso8601String(),
          },
        });
      }
    } catch (e) {
      // Hata durumunda bildirim gösterilmeye devam etsin
    }
  }

  // Update notification tap handling
  void _handleUpdateNotificationTap(String payload) {
    // Update notification tap handling - simplified
  }

  // Launch download URL
  Future<void> _launchDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {}
    } catch (e) {}
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
    // Sosyal bildirimler için Firebase'e kaydet
    if (response.payload == 'social_reminder') {
      _saveSocialNotificationToFirebase(response);
    }

    // Update notification tap handling
    if (response.payload != null &&
        response.payload!.contains('update_notification')) {
      _handleUpdateNotificationTap(response.payload!);
    }

    // Burada bildirime tıklandığında yapılacak işlemler
    // Örneğin: Belirli bir sayfaya yönlendirme
  }

  // Sosyal bildirimi Firebase'e kaydet
  Future<void> _saveSocialNotificationToFirebase(
      NotificationResponse response) async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final user = auth.currentUser;
      if (user != null && !user.isAnonymous) {
        // Notification ID'den hangi sosyal bildirim olduğunu anla
        String title = 'Sosyal Bildirim';
        String body = 'Tavla oynama zamanı!';

        final now = DateTime.now();
        if (now.hour >= 9 && now.hour <= 11) {
          title = 'Günaydın! 🎲';
          body =
              'Yeni bir tavla günü başladı! Arkadaşlarınızla oyun oynamaya ne dersiniz?';
        } else if (now.hour >= 14 && now.hour <= 16) {
          title = 'Öğleden Sonra Molası ☕';
          body =
              'Tavla oynayarak stres atmanın tam zamanı! Hemen bir oyun başlatın.';
        } else if (now.hour >= 19 && now.hour <= 21) {
          title = 'Akşam Vakti 🏆';
          body =
              'Günün sonunda tavla şampiyonluğunu kim kazanacak? Hemen oynamaya başlayın!';
        }

        await firestore.collection('notifications').add({
          'userId': user.uid,
          'title': title,
          'body': body,
          'type': NotificationType.social.toString().split('.').last,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'payload': response.payload,
            'source': 'social_notification',
            'timestamp': DateTime.now().toIso8601String(),
          },
        });
      }
    } catch (e) {}
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

      const AndroidNotificationChannel updateChannel =
          AndroidNotificationChannel(
        'update_notifications',
        'Güncelleme Bildirimleri',
        description: 'Uygulama güncelleme bildirimleri',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(mainChannel);
        await androidPlugin.createNotificationChannel(reminderChannel);
        await androidPlugin.createNotificationChannel(socialChannel);
        await androidPlugin.createNotificationChannel(updateChannel);
      } else {}
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

  // Hoşgeldin bildirimi göster
  Future<void> showWelcomeNotification({String? userName}) async {
    try {
      // Bugün zaten hoşgeldin bildirimi gösterildi mi kontrol et
      final canShowWelcome = await _canShowWelcomeNotification();
      if (!canShowWelcome) return;

      final hasPermission = await checkPermissions();
      if (!hasPermission) return;

      // Hoşgeldin mesajları listesi
      final welcomeMessages = [
        {
          'title': 'Hoşgeldin! 🎉',
          'body': userName != null
              ? 'Tekrar hoşgeldin $userName! Bugün hangi rakibini yeneceksin?'
              : 'Tekrar hoşgeldin! Bugün hangi rakibini yeneceksin?',
        },
        {
          'title': 'Yeni Gün, Yeni Zaferler! 🏆',
          'body': userName != null
              ? 'Merhaba $userName! Bugün de şampiyonluk yolunda adım atmaya hazır mısın?'
              : 'Merhaba! Bugün de şampiyonluk yolunda adım atmaya hazır mısın?',
        },
        {
          'title': 'Tavla Zamanı! 🎲',
          'body': userName != null
              ? 'Selam $userName! Yeni bir tavla günü başladı. Hadi oyuna!'
              : 'Selam! Yeni bir tavla günü başladı. Hadi oyuna!',
        },
        {
          'title': 'Geri Döndün! 🔥',
          'body': userName != null
              ? 'Harika $userName! Masalar seni bekliyor. Bugün kaç galibiyet alacaksın?'
              : 'Harika! Masalar seni bekliyor. Bugün kaç galibiyet alacaksın?',
        },
      ];

      // Rastgele bir hoşgeldin mesajı seç
      final randomIndex = DateTime.now().millisecond % welcomeMessages.length;
      final selectedMessage = welcomeMessages[randomIndex];

      await showNotification(
        title: selectedMessage['title']!,
        body: selectedMessage['body']!,
        type: NotificationType.general,
        payload: 'welcome_notification',
      );

      // Son hoşgeldin bildirimi tarihini kaydet
      await _saveLastWelcomeNotificationDate();
    } catch (e) {}
  }

  // Hoşgeldin bildirimi gösterilebilir mi kontrol et
  Future<bool> _canShowWelcomeNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWelcomeDate = prefs.getString(_lastWelcomeNotificationKey);

      if (lastWelcomeDate == null) return true;

      final lastDate = DateTime.parse(lastWelcomeDate);
      final today = DateTime.now();

      // Eğer son hoşgeldin bildirimi bugün gösterilmediyse, göster
      return lastDate.year != today.year ||
          lastDate.month != today.month ||
          lastDate.day != today.day;
    } catch (e) {
      return true; // Hata durumunda bildirimi göster
    }
  }

  // Son hoşgeldin bildirimi tarihini kaydet
  Future<void> _saveLastWelcomeNotificationDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _lastWelcomeNotificationKey, DateTime.now().toIso8601String());
    } catch (e) {}
  }

  // Hoşgeldin bildirimi ayarlarını sıfırla (test için)
  Future<void> resetWelcomeNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastWelcomeNotificationKey);
    } catch (e) {}
  }
}
