import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/home_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/statistics_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/splash_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/notifications_screen.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String newGame = '/new-game';
  static const String statistics = '/statistics';
  static const String notifications = '/notifications';

  // İstatistik sayfaları listesi
  static const List<String> _statisticsRoutes = [
    statistics,
  ];

  // Misafir kullanıcılar için kısıtlı route'lar
  static bool _isStatisticsRoute(String? routeName) {
    return _statisticsRoutes.contains(routeName);
  }

  // Misafir kullanıcı kontrolü
  static bool _isGuestUser() {
    final firebaseService = FirebaseService();
    return firebaseService.isCurrentUserGuest();
  }

  // Misafir kullanıcılar için login sayfasına yönlendirme
  static Route<dynamic> _redirectToLogin() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'Bu özellik için oturum açmanız gerekiyor',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(_, login);
                },
                child: const Text('Oturum Aç'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? splash;

    // Misafir kullanıcı kontrolü - istatistik sayfalarına erişimi kısıtla
    if (_isGuestUser() && _isStatisticsRoute(name)) {
      return _redirectToLogin();
    }

    switch (name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        final showSignUp = settings.arguments as bool? ?? false;
        return MaterialPageRoute(
            builder: (_) => LoginScreen(showSignUp: showSignUp));
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case newGame:
        return MaterialPageRoute(builder: (_) => const NewGameScreen());
      case statistics:
        return MaterialPageRoute(builder: (_) => const StatisticsScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for $name'),
            ),
          ),
        );
    }
  }
}
