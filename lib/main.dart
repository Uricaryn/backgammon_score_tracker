import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/providers/theme_provider.dart';
import 'package:backgammon_score_tracker/core/providers/notification_provider.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:backgammon_score_tracker/firebase_options.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';
import 'package:backgammon_score_tracker/core/services/firebase_messaging_service.dart';
import 'package:backgammon_score_tracker/core/services/update_notification_service.dart';
import 'package:backgammon_score_tracker/core/services/session_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background'da bildirim göster
  if (message.notification != null) {
    try {
      // Timezone initialize (bildirimler için gerekli)
      tz.initializeTimeZones();

      // Notification service'i initialize et
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.createNotificationChannels();

      // Bildirimi göster
      await notificationService.showNotification(
        title: message.notification!.title ?? 'Yeni Bildirim',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
        saveToFirebase: false, // Background'da Firebase'e kaydetme
      );

      print('Background notification shown: ${message.notification!.title}');
    } catch (e) {
      print('Error showing background notification: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Optimize initialization - only critical services
  await _initializeCriticalServices();

  // ✅ UI'yi başlat
  runApp(const MyApp());

  // ✅ Ağır initialization'ları daha sonra yap
  _initializeHeavyServicesOptimized();
}

// Kritik servisler - UI başlamadan önce gerekli
Future<void> _initializeCriticalServices() async {
  try {
    // ✅ Paralel initialization
    await Future.wait([
      // Firebase - kritik
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      // Timezone - bildirimler için gerekli
      Future.microtask(() => tz.initializeTimeZones()),
    ]);

    // Firebase messaging background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Critical services initialization error: $e');
  }
}

// ✅ Optimized heavy services initialization
void _initializeHeavyServicesOptimized() {
  // ✅ Daha da gecikme ile başlat
  Future.delayed(const Duration(seconds: 1), () async {
    final logService = LogService();

    try {
      // ✅ Paralel initialization
      await Future.wait([
        // Log service
        logService.initialize(),
        // Bildirim servisleri
        _initializeNotificationServicesOptimized(),
        // Session service
        _initializeSessionService(),
      ]);

      logService.info('Tüm servisler başarıyla başlatıldı');
    } catch (e) {
      debugPrint('Heavy services initialization error: $e');
    }
  });

  // ✅ Hata yakalama daha erken ayarla
  _setupErrorHandling();
}

// ✅ Optimized notification services
Future<void> _initializeNotificationServicesOptimized() async {
  try {
    final notificationService = NotificationService();
    final messagingService = FirebaseMessagingService();
    final updateNotificationService = UpdateNotificationService();

    // ✅ Paralel initialization
    await Future.wait([
      notificationService.initialize(),
      messagingService.initialize(),
      updateNotificationService.initialize(),
    ]);

    // ✅ Channel creation ayrı task olarak
    await notificationService.createNotificationChannels();

    // ✅ Sosyal bildirimleri daha da gecikme ile ayarla
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        await notificationService.setupSocialNotifications();
      } catch (e) {
        debugPrint('Social notifications setup error: $e');
      }
    });
  } catch (e) {
    debugPrint('Notification services initialization error: $e');
  }
}

// Session service initialize
Future<void> _initializeSessionService() async {
  try {
    final sessionService = SessionService();
    await sessionService.setSessionTimeout(2880); // 2 gün
  } catch (e) {
    debugPrint('Session service initialization error: $e');
  }
}

// Hata yakalama kurulumu
void _setupErrorHandling() {
  final logService = LogService();

  // Flutter hata yakalama
  FlutterError.onError = (FlutterErrorDetails details) {
    logService.fatal(
      'Flutter hatası: ${details.exception}',
      tag: 'Crash',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Platform hata yakalama
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    logService.fatal(
      'Platform hatası: $error',
      tag: 'Crash',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Tavla Skor Takip',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.getThemeMode(),
            initialRoute: AppRouter.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
