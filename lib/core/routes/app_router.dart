import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/home_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/statistics_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/splash_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/notifications_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String newGame = '/new-game';
  static const String statistics = '/statistics';
  static const String notifications = '/notifications';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? splash;

    switch (name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
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
