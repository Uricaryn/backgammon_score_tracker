import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/presentation/screens/login_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/home_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/new_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/statistics_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/splash_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/notifications_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/match_history_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/friends_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/tournaments_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/friend_detail_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/scoreboard_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/premium_upgrade_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/username_setup_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/email_verification_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/game_lobby_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/live_game_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/players_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/profile_screen.dart';
import 'package:backgammon_score_tracker/presentation/screens/edit_game_screen.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String newGame = '/new-game';
  static const String statistics = '/statistics';
  static const String notifications = '/notifications';
  static const String scoreboard = '/scoreboard';
  static const String matchHistory = '/match-history';
  static const String tournaments = '/tournaments';
  static const String friends = '/friends';
  static const String friendDetail = '/friend-detail';
  static const String premiumUpgrade = '/premium-upgrade';
  static const String usernameSetup = '/username-setup';
  static const String emailVerification = '/email-verification';
  static const String gameLobby = '/game-lobby';
  static const String liveGame = '/live-game';
  static const String players = '/players';
  static const String profile = '/profile';
  static const String editGame = '/edit-game';

  static final FirebaseService _firebaseService = FirebaseService();

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
    return _firebaseService.isCurrentUserGuest();
  }

  // Misafir kullanıcılar için login sayfasına yönlendirme
  static Route<dynamic> _redirectToLogin() {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
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
                  Navigator.pushReplacementNamed(context, login);
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
        final startTutorial = settings.arguments as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => HomeScreen(startTutorial: startTutorial),
        );
      case newGame:
        return MaterialPageRoute(builder: (_) => const NewGameScreen());
      case statistics:
        return MaterialPageRoute(builder: (_) => const StatisticsScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case scoreboard:
        return MaterialPageRoute(builder: (_) => const ScoreboardScreen());
      case matchHistory:
        return MaterialPageRoute(builder: (_) => const MatchHistoryScreen());
      case friends:
        return MaterialPageRoute(builder: (_) => const FriendsScreen());
      case friendDetail:
        final friend = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => FriendDetailScreen(friend: friend ?? {}),
        );
      case tournaments:
        return MaterialPageRoute(builder: (_) => const TournamentsScreen());
      case premiumUpgrade:
        final source = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => PremiumUpgradeScreen(source: source),
        );
      case usernameSetup:
        return MaterialPageRoute(builder: (_) => const UsernameSetupScreen());
      case emailVerification:
        return MaterialPageRoute(
          builder: (_) => const EmailVerificationScreen(),
        );
      case gameLobby:
        return MaterialPageRoute(builder: (_) => const GameLobbyScreen());
      case liveGame:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final roomId = args['roomId'] as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => LiveGameScreen(roomId: roomId),
        );
      case players:
        return MaterialPageRoute(builder: (_) => const PlayersScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case editGame:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => EditGameScreen(
            gameId: args['gameId'] as String? ?? '',
            player1: args['player1'] as String? ?? '',
            player2: args['player2'] as String? ?? '',
            player1Score: args['player1Score'] as int? ?? 0,
            player2Score: args['player2Score'] as int? ?? 0,
          ),
        );
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
