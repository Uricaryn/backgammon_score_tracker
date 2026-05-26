import 'package:firebase_auth/firebase_auth.dart';

/// E-posta/şifre hesapları için doğrulama kuralları.
class AuthVerification {
  static bool usesEmailPassword(User user) {
    return user.providerData.any((info) => info.providerId == 'password');
  }

  /// OAuth (Google/Apple) ve misafir hesapları bu kontrolden muaf.
  static bool requiresEmailVerification(User user) {
    if (user.isAnonymous) return false;
    if (!usesEmailPassword(user)) return false;
    return !user.emailVerified;
  }
}
