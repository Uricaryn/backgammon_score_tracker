import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/backgammon_board.dart';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';

class BackgroundBoard extends StatelessWidget {
  final Widget child;

  const BackgroundBoard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.getBackgroundGradientColors(context),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackgammonBoard(
              opacity: isDark ? 0.15 : 0.3,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.5),
                        ]
                      : [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.3),
                        ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
