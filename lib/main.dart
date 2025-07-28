import 'dart:async';
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
import 'package:backgammon_score_tracker/core/services/payment_service.dart';
import 'package:backgammon_score_tracker/core/services/ad_service.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background'da bildirim göster
  try {
    // Timezone initialize (bildirimler için gerekli)
    tz.initializeTimeZones();

    // Notification service'i initialize et
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.createNotificationChannels();

    String title = 'Yeni Bildirim';
    String body = '';

    if (message.notification != null) {
      // Notification payload varsa onu kullan
      title = message.notification!.title ?? 'Yeni Bildirim';
      body = message.notification!.body ?? '';
      print('Background notification with notification payload: $title');
    } else {
      // Data-only message için data'dan al
      title = message.data['title'] as String? ??
          message.data['message'] as String? ??
          'Yeni Bildirim';
      body = message.data['message'] as String? ??
          message.data['body'] as String? ??
          '';
      print('Background notification with data payload: $title');
    }

    if (title.isNotEmpty && body.isNotEmpty) {
      // Bildirimi göster
      await notificationService.showNotification(
        title: title,
        body: body,
        payload: message.data.toString(),
        saveToFirebase: false, // Background'da Firebase'e kaydetme
      );

      print('Background notification shown: $title');
    } else {
      print('No valid title/body found in background message');
    }
  } catch (e) {
    print('Error showing background notification: $e');
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
        // Payment service
        _initializePaymentService(),
        // AdMob service
        _initializeAdService(),
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

// Payment service initialize
Future<void> _initializePaymentService() async {
  try {
    final paymentService = PaymentService();
    await paymentService.initialize();
  } catch (e) {
    debugPrint('Payment service initialization error: $e');
  }
}

// AdMob service initialize
Future<void> _initializeAdService() async {
  try {
    final adService = AdService();
    await adService.initialize();
  } catch (e) {
    debugPrint('AdMob service initialization error: $e');
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PremiumService _premiumService = PremiumService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthStateListener();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthStateListener() {
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        // Kullanıcı çıkış yaptığında premium cache'i temizle
        _premiumService.clearPremiumCache();
      }
    });
  }

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
            builder: (context, child) {
              return SafeArea(
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
