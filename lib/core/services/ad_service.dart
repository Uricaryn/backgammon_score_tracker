import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:backgammon_score_tracker/core/services/tracking_transparency_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Test Ad Unit ID'leri (geliştirme için)
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // Gerçek Ad Unit ID'leri
  static const String _bannerAdUnitId =
      'ca-app-pub-4377193604784253/9909213755'; // Banner reklam için yeni ID
  // YENİ AD UNIT ID'Sİ BURAYA EKLENECEK: ca-app-pub-4377193604784253/[YENİ_ID]
  static const String _interstitialAdUnitId =
      'ca-app-pub-4377193604784253/3104132255'; // Geçiş reklamı için mevcut ID
  static const String _rewardedAdUnitId =
      'ca-app-pub-4377193604784253/3104132255';

  bool _isInitialized = false;
  Future<void>? _initializeFuture;
  bool _isTestMode = false; // Gerçek reklamlar için false - Test modunu kapatın
  final _trackingTransparencyService = TrackingTransparencyService();

  // Test modunu kontrol etmek için
  bool get isTestMode => _isTestMode;
  void setTestMode(bool value) => _isTestMode = value;

  // AdMob'u başlat
  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      await _trackingTransparencyService.requestIfNeeded();
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdMob başarıyla başlatıldı');
    } catch (e) {
      debugPrint('AdMob başlatma hatası: $e');
    }
  }

  Future<AdRequest> _adRequest() {
    return _trackingTransparencyService.createAdRequest();
  }

  // Banner reklam oluştur
  Future<BannerAd> createBannerAd() async {
    await initialize();
    final adUnitId = _isTestMode ? _testBannerAdUnitId : _bannerAdUnitId;

    debugPrint('Banner Ad Unit ID: $adUnitId');
    debugPrint('Test Mode: $_isTestMode');

    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: await _adRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner reklam başarıyla yüklendi');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner reklam yüklenemedi: $error');
          debugPrint('❌ Error Code: ${error.code}');
          debugPrint('❌ Error Message: ${error.message}');
          debugPrint('❌ Error Domain: ${error.domain}');
          ad.dispose();
        },
        onAdOpened: (ad) {
          debugPrint('📱 Banner reklam açıldı');
        },
        onAdClosed: (ad) {
          debugPrint('🔒 Banner reklam kapandı');
        },
        onAdImpression: (ad) {
          debugPrint('👁️ Banner reklam gösterildi');
        },
      ),
    );
  }

  // Interstitial reklam oluştur
  Future<InterstitialAd?> createInterstitialAd() async {
    await initialize();
    final adUnitId =
        _isTestMode ? _testInterstitialAdUnitId : _interstitialAdUnitId;

    try {
      final adRequest = await _adRequest();
      Completer<InterstitialAd?> completer = Completer<InterstitialAd?>();

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: adRequest,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            completer.complete(null);
          },
        ),
      );

      return await completer.future;
    } catch (e) {
      debugPrint('Interstitial reklam oluşturma hatası: $e');
      return null;
    }
  }

  // Rewarded reklam oluştur
  Future<RewardedAd?> createRewardedAd() async {
    await initialize();
    final adUnitId = _isTestMode ? _testRewardedAdUnitId : _rewardedAdUnitId;

    try {
      final adRequest = await _adRequest();
      RewardedAd? rewardedAd;
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: adRequest,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('Rewarded reklam yüklendi');
            rewardedAd = ad;
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded reklam yüklenemedi: $error');
            rewardedAd = null;
          },
        ),
      );
      return rewardedAd;
    } catch (e) {
      debugPrint('Rewarded reklam oluşturma hatası: $e');
      return null;
    }
  }

  // Reklamları temizle
  void dispose() {
    // Gerekirse burada temizlik işlemleri yapılabilir
  }
}
