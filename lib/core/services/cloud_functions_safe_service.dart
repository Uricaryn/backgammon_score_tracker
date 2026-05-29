import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class CloudFunctionsSafeService {
  static final CloudFunctionsSafeService _instance =
      CloudFunctionsSafeService._internal();
  factory CloudFunctionsSafeService() => _instance;
  CloudFunctionsSafeService._internal();

  static const String _enabledKey = 'cloud_functions_enabled';

  bool _initialized = false;
  bool _remoteEnabled = true;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  bool get _platformAllowed {
    if (kIsWeb) return false;
    // TestFlight crash mitigation:
    // Firebase Functions native layer is unstable in iOS release builds.
    // Keep enabled in debug for local testing, disable in TestFlight/App Store.
    if (defaultTargetPlatform == TargetPlatform.iOS && !kDebugMode) {
      return false;
    }
    return defaultTargetPlatform != TargetPlatform.macOS;
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults(const {_enabledKey: true});
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(minutes: 5),
      ));
      await rc.fetchAndActivate();
      _remoteEnabled = rc.getBool(_enabledKey);
    } catch (_) {
      // Remote Config erişilemiyorsa varsayılan davranış korunur.
      _remoteEnabled = true;
    }
  }

  Future<bool> isEnabled() async {
    await _init();
    return _platformAllowed && _remoteEnabled;
  }

  /// Callable isteklerinde Firebase Auth jetonunun hazır olmasını sağlar.
  Future<bool> _ensureAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final token = await user.getIdToken(true);
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<HttpsCallableResult<dynamic>?> call(
    String name, {
    Map<String, dynamic>? data,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!await isEnabled()) {
      debugPrint('Cloud Functions disabled for this platform/flag: $name');
      return null;
    }
    if (!await _ensureAuthToken()) {
      if (kDebugMode) {
        debugPrint('Cloud Function skipped ($name): oturum yok veya auth token hazır değil');
      }
      return null;
    }
    try {
      final callable = _functions.httpsCallable(name);
      return await callable.call(data).timeout(timeout);
    } catch (e) {
      final message = e.toString();
      if (message.contains('unauthenticated')) {
        if (kDebugMode) {
          debugPrint('Cloud Function skipped ($name): kimlik doğrulama gerekli');
        }
      } else {
        debugPrint('Cloud Function call failed ($name): $e');
      }
      return null;
    }
  }
}
