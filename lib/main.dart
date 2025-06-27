import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/providers/theme_provider.dart';
import 'package:backgammon_score_tracker/core/providers/notification_provider.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:backgammon_score_tracker/firebase_options.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';
import 'package:backgammon_score_tracker/core/services/firebase_messaging_service.dart';
import 'package:backgammon_score_tracker/core/services/session_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // LogService'i başlat
  final logService = LogService();
  await logService.initialize();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firebase messaging background handler'ı ayarla
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Bildirim servislerini başlat
  try {
    final notificationService = NotificationService();
    final messagingService = FirebaseMessagingService();

    await notificationService.initialize();
    await messagingService.initialize();
    await notificationService.createNotificationChannels();
  } catch (e) {
    // Bildirim servisleri başarısız olsa bile uygulama çalışmaya devam etsin
  }

  // Session servisini başlat
  try {
    final sessionService = SessionService();
    await sessionService.setSessionTimeout(2880); // 2 gün
  } catch (e) {
    // Bildirim servisleri başarısız olsa bile uygulama çalışmaya devam etsin
  }

  logService.info('Uygulama başlatıldı');

  // Hata yakalama
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

  runApp(const MyApp());
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
