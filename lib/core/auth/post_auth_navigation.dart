import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/auth/auth_verification.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';

/// Oturum açma/kayıt sonrası doğru ekrana yönlendirir.
class PostAuthNavigation {
  static Future<void> go(BuildContext context, {User? user}) async {
    if (!context.mounted) return;

    final activeUser = user ?? FirebaseAuth.instance.currentUser;
    if (activeUser == null) {
      Navigator.pushReplacementNamed(context, AppRouter.login);
      return;
    }

    if (AuthVerification.requiresEmailVerification(activeUser)) {
      Navigator.pushReplacementNamed(context, AppRouter.emailVerification);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(activeUser.uid)
          .get();
      if (!context.mounted) return;

      final username = userDoc.data()?['username'] as String?;
      if (username == null || username.trim().isEmpty) {
        Navigator.pushReplacementNamed(context, AppRouter.usernameSetup);
      } else {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }
}
