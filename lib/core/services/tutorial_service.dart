import 'package:shared_preferences/shared_preferences.dart';

/// Cihaz bazlı uygulama turu (coach marks) tamamlanma durumu.
class TutorialService {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  static const String _completedVersionKey = 'tutorial_completed_version';
  static const int currentVersion = 1;

  Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getInt(_completedVersionKey) ?? 0;
      return completed < currentVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_completedVersionKey, currentVersion);
    } catch (_) {}
  }

  Future<void> resetForReplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_completedVersionKey);
    } catch (_) {}
  }
}
