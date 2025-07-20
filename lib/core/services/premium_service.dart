import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logService = LogService();

  // Premium durum cache key'leri
  static const String _premiumStatusKey = 'premium_status';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _lastCheckKey = 'last_premium_check';

  // Premium özellik limitleri
  static const int _freeFriendLimit = 3;
  static const int _freeSocialTournamentLimit =
      0; // Ücretsiz kullanıcılar sosyal turnuva oluşturamaz

  // TEMPORARY: Premium system disabled for deployment
  static const bool _premiumSystemDisabled = true;

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

      // Önce cache'den kontrol et
      final prefs = await SharedPreferences.getInstance();
      final cachedStatus = prefs.getBool(_premiumStatusKey);
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Cache 1 saat geçerli
      if (cachedStatus != null && (now - lastCheck) < 3600000) {
        return cachedStatus;
      }

      // Server-side doğrulama çağır
      final functions = FirebaseFunctions.instance;
      final result =
          await functions.httpsCallable('checkPremiumStatus').call({});

      final hasValidPremium = result.data['isPremium'] ?? false;

      // Cache'i güncelle
      await prefs.setBool(_premiumStatusKey, hasValidPremium);
      await prefs.setInt(_lastCheckKey, now);

      _logService.info('Premium status checked: $hasValidPremium',
          tag: 'Premium');
      return hasValidPremium;
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
    } catch (e) {
      _logService.error('Failed to clear premium cache',
          tag: 'Premium', error: e);
    }
  }
}
