import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/backgammon_board.dart';

class BackgroundBoard extends StatelessWidget {
  final Widget child;

  const BackgroundBoard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
            Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: BackgammonBoard(
              opacity: 0.3,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.4),
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
