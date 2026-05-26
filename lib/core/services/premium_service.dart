import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/services/cloud_functions_safe_service.dart';

/// Profil ve premium yönetim ekranı için özet üyelik bilgisi.
class PremiumMembershipInfo {
  const PremiumMembershipInfo({
    required this.isPremium,
    this.expiryDate,
    this.productId,
    this.renewalCancelled = false,
  });

  final bool isPremium;
  final DateTime? expiryDate;
  final String? productId;

  /// Kullanıcı yenilemeyi iptal etti; süre dolana kadar erişim devam eder.
  final bool renewalCancelled;

  bool get isExpired {
    if (!isPremium || expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }
}

class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logService = LogService();
  final CloudFunctionsSafeService _functionsSafe = CloudFunctionsSafeService();

  String? _lastUserId; // Son kontrol edilen kullanıcı ID'si

  final StreamController<bool> _premiumActivatedController =
      StreamController<bool>.broadcast();

  /// Satın alma tamamlandığında `true` yayınlanır (UI anında güncellensin).
  Stream<bool> get premiumActivatedStream =>
      _premiumActivatedController.stream;

  // Premium durum cache key'leri
  static const String _premiumStatusKey = 'premium_status';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _lastCheckKey = 'last_premium_check';

  // Premium özellik limitleri
  static const int _freeFriendLimit = 3;
  static const int _freeSocialTournamentLimit =
      0; // Ücretsiz kullanıcılar sosyal turnuva oluşturamaz

  // Premium system enabled
  static const bool _premiumSystemDisabled = false;

  /// Firestore kullanıcı verisinden geçerli premium durumunu çıkarır.
  bool isPremiumFromUserData(Map<String, dynamic>? userData) {
    if (userData == null || userData['isPremium'] != true) return false;
    final expiry = _timestampToDate(userData['premiumExpiryDate']) ??
        _timestampToDate(userData['premiumExpiry']);
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  /// Satın alma sonrası önbelleği hemen premium yapar; dinleyicilere bildirir.
  Future<void> markPremiumActiveLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setBool(_premiumStatusKey, true);
      await prefs.setInt(_lastCheckKey, now);
      if (!_premiumActivatedController.isClosed) {
        _premiumActivatedController.add(true);
      }
      _logService.info('Premium marked active in local cache', tag: 'Premium');
    } catch (e) {
      _logService.error('Failed to mark premium active locally',
          tag: 'Premium', error: e);
    }
  }

  /// Kullanıcının premium durumunu kontrol et
  Future<bool> hasPremiumAccess() async {
    // TEMPORARY: Premium system disabled
    if (_premiumSystemDisabled) {
      _logService.info('Premium system temporarily disabled', tag: 'Premium');
      return false;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Kullanıcı değiştiyse cache'i temizle
      if (_lastUserId != null && _lastUserId != currentUser.uid) {
        await clearPremiumCache();
        _logService.info('User changed, premium cache cleared', tag: 'Premium');
      }
      _lastUserId = currentUser.uid;

      // Önce cache'den kontrol et
      final prefs = await SharedPreferences.getInstance();
      final cachedStatus = prefs.getBool(_premiumStatusKey);
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Yalnızca premium=true önbelleği güvenilir (1 saat).
      // false önbelleği satın alma sonrası çıkış gerektiriyordu; her zaman sunucudan doğrula.
      if (cachedStatus == true && (now - lastCheck) < 3600000) {
        return true;
      }

      final callableResult = await _functionsSafe.call('checkPremiumStatus');
      if (callableResult != null &&
          callableResult.data is Map &&
          (callableResult.data as Map)['isPremium'] != null) {
        final hasValidPremium = (callableResult.data as Map)['isPremium'] == true;
        await prefs.setBool(_premiumStatusKey, hasValidPremium);
        await prefs.setInt(_lastCheckKey, now);
        _logService.info('Premium status from function: $hasValidPremium',
            tag: 'Premium');
        return hasValidPremium;
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final isPremium = isPremiumFromUserData(userData);

        if (isPremium) {
          await prefs.setBool(_premiumStatusKey, true);
          await prefs.setInt(_lastCheckKey, now);
        } else {
          await prefs.remove(_premiumStatusKey);
          await prefs.remove(_lastCheckKey);
        }

        _logService.info('Premium status from Firestore: $isPremium',
            tag: 'Premium');
        return isPremium;
      }

      return false;
    } catch (e) {
      _logService.error('Failed to check premium status',
          tag: 'Premium', error: e);
      return false;
    }
  }

  /// Arkadaş ekleme limitini kontrol et
  Future<bool> canAddFriend() async {
    // TEMPORARY: Premium system disabled - allow all friend additions
    if (_premiumSystemDisabled) {
      return true;
    }

    try {
      final hasPremium = await hasPremiumAccess();
      if (hasPremium) return true; // Premium kullanıcılar sınırsız

      // Ücretsiz kullanıcı limit kontrolü
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final friendsSnapshot = await _firestore
          .collection('friendships')
          .where('userId1', isEqualTo: currentUser.uid)
          .get();

      final friendsCount = friendsSnapshot.docs.length;

      // Aynı kullanıcının userId2 olduğu arkadaşlıkları da kontrol et
      final reverseFriendsSnapshot = await _firestore
          .collection('friendships')
          .where('userId2', isEqualTo: currentUser.uid)
          .get();

      final totalFriends = friendsCount + reverseFriendsSnapshot.docs.length;

      return totalFriends < _freeFriendLimit;
    } catch (e) {
      _logService.error('Failed to check friend limit',
          tag: 'Premium', error: e);
      return false;
    }
  }

  /// Sosyal turnuva oluşturma yetkisini kontrol et
  Future<bool> canCreateSocialTournament() async {
    // TEMPORARY: Premium system disabled - allow all tournament creation
    if (_premiumSystemDisabled) {
      return true;
    }

    try {
      final hasPremium = await hasPremiumAccess();
      return hasPremium; // Sadece premium kullanıcılar sosyal turnuva oluşturabilir
    } catch (e) {
      _logService.error('Failed to check social tournament permission',
          tag: 'Premium', error: e);
      return false;
    }
  }

  /// Premium durumu güncelle (admin tarafından)
  Future<void> updatePremiumStatus(String userId, bool isPremium,
      {DateTime? expiryDate}) async {
    // TEMPORARY: Premium system disabled
    if (_premiumSystemDisabled) {
      _logService.info('Premium system temporarily disabled - update ignored',
          tag: 'Premium');
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'isPremium': isPremium,
        'premiumExpiry':
            expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'premiumUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Cache'i temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_premiumStatusKey);
      await prefs.remove(_lastCheckKey);

      _logService.info('Premium status updated for user: $userId',
          tag: 'Premium');
    } catch (e) {
      _logService.error('Failed to update premium status',
          tag: 'Premium', error: e);
      rethrow;
    }
  }

  /// Premium özellikler hakkında bilgi al
  Map<String, dynamic> getPremiumFeatures() {
    return {
      'freeFriendLimit': _freeFriendLimit,
      'freeSocialTournamentLimit': _freeSocialTournamentLimit,
      'premiumFeatures': [
        'Sınırsız arkadaş ekleme',
        'Sosyal turnuva oluşturma',
        'Öncelikli destek',
        'Reklamsız deneyim',
      ],
      'systemDisabled': _premiumSystemDisabled,
    };
  }

  /// Premium durumunu cache'den temizle
  Future<void> clearPremiumCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_premiumStatusKey);
      await prefs.remove(_lastCheckKey);
      await prefs.remove(_premiumExpiryKey);

      // Son kullanıcı ID'sini sıfırla
      _lastUserId = null;

      _logService.info('Premium cache cleared', tag: 'Premium');
    } catch (e) {
      _logService.error('Failed to clear premium cache',
          tag: 'Premium', error: e);
    }
  }

  /// Premium durumunu zorla yenile
  Future<bool> refreshPremiumStatus() async {
    try {
      await clearPremiumCache();
      return await hasPremiumAccess();
    } catch (e) {
      _logService.error('Failed to refresh premium status',
          tag: 'Premium', error: e);
      return false;
    }
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Firestore'dan premium üyelik detaylarını okur (profil ekranı).
  Future<PremiumMembershipInfo?> fetchMembershipDetails() async {
    if (_premiumSystemDisabled) {
      return const PremiumMembershipInfo(isPremium: false);
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        return const PremiumMembershipInfo(isPremium: false);
      }

      final data = userDoc.data();
      final isPremium = isPremiumFromUserData(data);
      final expiry = _timestampToDate(data?['premiumExpiryDate']) ??
          _timestampToDate(data?['premiumExpiry']);
      final productId = data?['productId'] as String?;

      final renewalCancelled = data?['premiumRenewalCancelled'] == true;

      return PremiumMembershipInfo(
        isPremium: isPremium,
        expiryDate: expiry,
        productId: productId,
        renewalCancelled: renewalCancelled,
      );
    } catch (e) {
      _logService.error('Failed to fetch membership details',
          tag: 'Premium', error: e);
      return null;
    }
  }

  /// Otomatik yenilemeyi iptal etmek için tercihi kaydet.
  ///
  /// Süre dolana kadar [hasPremiumAccess] true kalır (Firestore `isPremium` değişmez).
  Future<void> setPremiumRenewalPreference({required bool autoRenew}) async {
    if (_premiumSystemDisabled) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Oturum açılmamış');
    }

    if (autoRenew) {
      await _firestore.collection('users').doc(uid).set(
        {
          'premiumRenewalCancelled': false,
          'premiumRenewalCancelledAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    } else {
      await _firestore.collection('users').doc(uid).set(
        {
          'premiumRenewalCancelled': true,
          'premiumRenewalCancelledAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    _logService.info(
      'Premium renewal preference set: autoRenew=$autoRenew',
      tag: 'Premium',
    );
  }
}
