import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';

class SessionService {
  static const String _lastActivityKey = 'last_activity_timestamp';
  static const String _sessionTimeoutKey = 'session_timeout_minutes';
  static const int _defaultTimeoutMinutes = 2880; // 2 gün

  Timer? _sessionTimer;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  /// Session'ı başlat
  Future<void> startSession() async {
    await _updateLastActivity();
    _startSessionTimer();
  }

  /// Son aktivite zamanını güncelle
  Future<void> _updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActivityKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Session timer'ını başlat
  void _startSessionTimer() {
    _sessionTimer?.cancel();

    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _checkSessionTimeout();
    });
  }

  /// Session timeout kontrolü
  Future<void> _checkSessionTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getInt(_lastActivityKey);
    final timeoutMinutes =
        prefs.getInt(_sessionTimeoutKey) ?? _defaultTimeoutMinutes;

    if (lastActivity != null) {
      final lastActivityTime =
          DateTime.fromMillisecondsSinceEpoch(lastActivity);
      final currentTime = DateTime.now();
      final difference = currentTime.difference(lastActivityTime);

      if (difference.inMinutes >= timeoutMinutes) {
        await logout();
      }
    }
  }

  /// Kullanıcı aktivitesini kaydet
  Future<void> recordActivity() async {
    await _updateLastActivity();
  }

  /// Session timeout süresini ayarla
  Future<void> setSessionTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionTimeoutKey, minutes);

    // Timer'ı başlat
    _startSessionTimer();
  }

  /// Session timeout süresini al
  Future<int> getSessionTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sessionTimeoutKey) ?? _defaultTimeoutMinutes;
  }

  /// Son aktivite zamanını al
  Future<DateTime?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getInt(_lastActivityKey);
    if (lastActivity != null) {
      return DateTime.fromMillisecondsSinceEpoch(lastActivity);
    }
    return null;
  }

  /// Kalan session süresini hesapla
  Future<int> getRemainingSessionTime() async {
    final lastActivity = await getLastActivity();
    final timeoutMinutes = await getSessionTimeout();

    if (lastActivity != null) {
      final currentTime = DateTime.now();
      final difference = currentTime.difference(lastActivity);
      final remaining = timeoutMinutes - difference.inMinutes;
      return remaining > 0 ? remaining : 0;
    }
    return timeoutMinutes;
  }

  /// Session'ı durdur
  void stopSession() {
    _sessionTimer?.cancel();
  }

  /// Çıkış yap
  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _clearSessionData();

      // Premium cache'ini temizle
      final premiumService = PremiumService();
      await premiumService.clearPremiumCache();

      stopSession();
    } catch (e) {
      // Handle error
    }
  }

  /// Session verilerini temizle
  Future<void> _clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActivityKey);
  }

  /// Kullanıcının giriş yapmış olup olmadığını kontrol et
  bool isUserLoggedIn() {
    final user = _auth.currentUser;
    return user != null;
  }

  /// Session'ın aktif olup olmadığını kontrol et
  Future<bool> isSessionActive() async {
    final isLoggedIn = isUserLoggedIn();

    if (!isLoggedIn) return false;

    final remainingTime = await getRemainingSessionTime();
    return remainingTime > 0;
  }

  /// Session'ı yenile
  Future<void> refreshSession() async {
    if (isUserLoggedIn()) {
      await recordActivity();
      _startSessionTimer(); // Timer'ı yeniden başlat
    }
  }
}
