import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';

class AppWidget extends StatelessWidget {
  final String initialRoute;
  final ThemeMode themeMode;

  const AppWidget({
    super.key,
    required this.initialRoute,
    this.themeMode = ThemeMode.system,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tavla Skor Takip',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
