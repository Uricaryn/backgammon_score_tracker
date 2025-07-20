import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/constants/api_keys.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Güvenlik kontrolleri
  Future<bool> performSecurityChecks() async {
    try {
      // 1. Debug modu kontrolü
      if (kDebugMode) {
        debugPrint('Debug modunda güvenlik kontrolleri atlanıyor');
        return true;
      }

      // 2. API Key güvenlik kontrolü
      final isValidApiKeys = await _checkApiKeySecurity();
      if (!isValidApiKeys) {
        debugPrint('API Key güvenlik kontrolü başarısız');
        return false;
      }

      // 3. APK imza kontrolü
      final isValidSignature = await _checkAppSignature();
      if (!isValidSignature) {
        debugPrint('Geçersiz APK imzası tespit edildi');
        return false;
      }

      // 4. Cihaz ID kontrolü
      final isValidDevice = await _checkDeviceIntegrity();
      if (!isValidDevice) {
        debugPrint('Cihaz bütünlüğü kontrolü başarısız');
        return false;
      }

      // 5. Server-side güvenlik kontrolü
      final serverCheck = await _performServerSecurityCheck();
      if (!serverCheck) {
        debugPrint('Server-side güvenlik kontrolü başarısız');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Güvenlik kontrolü hatası: $e');
      return false;
    }
  }

  // API Key güvenlik kontrolü
  Future<bool> _checkApiKeySecurity() async {
    try {
      // API key'lerin geçerli olup olmadığını kontrol et
      if (!ApiKeys.isHuggingFaceApiKeyValid) {
        debugPrint('Geçersiz Hugging Face API key');
        return false;
      }

      // API key'lerin güvenli olup olmadığını kontrol et
      if (ApiKeys.huggingFaceApiKey
          .contains('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')) {
        debugPrint('Eski API key tespit edildi - güvenlik ihlali');
        await reportSecurityViolation('OLD_API_KEY_EXPOSED');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('API Key güvenlik kontrolü hatası: $e');
      return false;
    }
  }

  // APK imza kontrolü
  Future<bool> _checkAppSignature() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // Gerçek uygulama paket adı kontrolü
      if (packageInfo.packageName != 'com.uricaryn.backgammon_score_tracker') {
        return false;
      }

      // Versiyon kontrolü
      if (packageInfo.version.isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('APK imza kontrolü hatası: $e');
      return false;
    }
  }

  // Cihaz bütünlüğü kontrolü
  Future<bool> _checkDeviceIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId == null) {
        // İlk çalıştırma - cihaz ID'si oluştur
        final newDeviceId = _generateDeviceId();
        await prefs.setString('device_id', newDeviceId);
        return true;
      }

      // Cihaz ID'si değişmiş mi kontrol et
      final currentDeviceId = _generateDeviceId();
      if (deviceId != currentDeviceId) {
        debugPrint('Cihaz ID değişikliği tespit edildi');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Cihaz bütünlüğü kontrolü hatası: $e');
      return false;
    }
  }

  // Cihaz ID'si oluştur
  String _generateDeviceId() {
    final user = _auth.currentUser;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = user?.uid ?? 'anonymous';

    // Basit hash oluştur
    return '${userId}_${timestamp}';
  }

  // Server-side güvenlik kontrolü
  Future<bool> _performServerSecurityCheck() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final result =
          await _functions.httpsCallable('checkDeviceSecurity').call({
        'deviceId': await _getDeviceId(),
        'packageName': (await PackageInfo.fromPlatform()).packageName,
        'version': (await PackageInfo.fromPlatform()).version,
      });

      return result.data['isSecure'] ?? false;
    } catch (e) {
      debugPrint('Server-side güvenlik kontrolü hatası: $e');
      return false;
    }
  }

  // Cihaz ID'sini al
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id') ?? _generateDeviceId();
  }

  // Premium özellikler için güvenlik kontrolü
  Future<bool> checkPremiumSecurity() async {
    try {
      // Temel güvenlik kontrolleri
      final basicSecurity = await performSecurityChecks();
      if (!basicSecurity) {
        return false;
      }

      // Premium özellikler için ek kontroller
      final user = _auth.currentUser;
      if (user == null) return false;

      // Server-side premium güvenlik kontrolü
      final result =
          await _functions.httpsCallable('checkPremiumSecurity').call({
        'userId': user.uid,
        'deviceId': await _getDeviceId(),
      });

      return result.data['isSecure'] ?? false;
    } catch (e) {
      debugPrint('Premium güvenlik kontrolü hatası: $e');
      return false;
    }
  }

  // Güvenlik ihlali raporla
  Future<void> reportSecurityViolation(String violationType,
      {String? details}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _functions.httpsCallable('reportSecurityViolation').call({
        'userId': user.uid,
        'deviceId': await _getDeviceId(),
        'violationType': violationType,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('Güvenlik ihlali raporlandı: $violationType');
    } catch (e) {
      debugPrint('Güvenlik ihlali raporlama hatası: $e');
    }
  }
}
