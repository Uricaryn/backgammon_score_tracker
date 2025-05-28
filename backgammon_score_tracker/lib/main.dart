import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAu6HdQFHoAQo8WjnAjdzb3c3_geeiXtf8",
        appId: "1:643090063875:android:ce968e49acd930fa956436",
        messagingSenderId: "643090063875",
        projectId: "backgammon-3e34c",
        storageBucket: "backgammon-3e34c.firebasestorage.app",
      ),
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backgammon Score Tracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.splash,
    );
  }
}
