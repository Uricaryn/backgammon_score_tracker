import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/widgets/notification_badge.dart';
import 'package:backgammon_score_tracker/presentation/screens/profile_screen.dart';

class HomeAppBarActions extends StatelessWidget {
  const HomeAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NotificationBadge(),
        IconButton(
          icon: const Icon(Icons.person),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
