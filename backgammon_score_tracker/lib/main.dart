import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/home_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/splash_screen.dart';
import 'package:backgammon_score_tracker/core/providers/theme_provider.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B4513), // Kahverengi
        primary: const Color(0xFF8B4513),
        secondary: const Color(0xFFDEB887), // Bej
        tertiary: const Color(0xFFD2691E), // Koyu Turuncu
        brightness: Brightness.light,
      ),
      cardColor: Colors.white,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B4513),
        primary: const Color(0xFF8B4513),
        secondary: const Color(0xFFDEB887),
        tertiary: const Color(0xFFD2691E),
        brightness: Brightness.dark,
      ),
      cardColor: const Color(0xFF1E1E1E),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            title: 'Tavla Skor Takip',
            theme: lightTheme,
            darkTheme: darkTheme,
            initialRoute: AppRouter.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        }

        if (snapshot.hasData) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasData) {
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                final useSystemTheme = userData?['useSystemTheme'] ?? true;
                final themeMode = userData?['themeMode'] ?? 'system';

                ThemeMode selectedThemeMode;
                switch (themeMode) {
                  case 'dark':
                    selectedThemeMode = ThemeMode.dark;
                    break;
                  case 'light':
                    selectedThemeMode = ThemeMode.light;
                    break;
                  default:
                    selectedThemeMode = ThemeMode.system;
                }

                return MaterialApp(
                  title: 'Tavla Skor Takip',
                  theme: lightTheme,
                  darkTheme: darkTheme,
                  themeMode: selectedThemeMode,
                  initialRoute: AppRouter.home,
                  onGenerateRoute: AppRouter.onGenerateRoute,
                );
              }
              return MaterialApp(
                title: 'Tavla Skor Takip',
                theme: lightTheme,
                darkTheme: darkTheme,
                initialRoute: AppRouter.home,
                onGenerateRoute: AppRouter.onGenerateRoute,
              );
            },
          );
        }

        return MaterialApp(
          title: 'Tavla Skor Takip',
          theme: lightTheme,
          darkTheme: darkTheme,
          initialRoute: AppRouter.login,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
