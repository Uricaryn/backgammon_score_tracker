import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  static const String _interstitialAdUnitId =
      'ca-app-pub-4377193604784253/3104132255'; // Geçiş reklamı için mevcut ID
  static const String _rewardedAdUnitId =
      'ca-app-pub-4377193604784253/3104132255';

  bool _isInitialized = false;
  bool _isTestMode = false; // Gerçek reklamlar için false

  // Test modunu kontrol etmek için
  bool get isTestMode => _isTestMode;
  void setTestMode(bool value) => _isTestMode = value;

  // AdMob'u başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      print('AdMob başarıyla başlatıldı');
    } catch (e) {
      print('AdMob başlatma hatası: $e');
    }
  }

  // Banner reklam oluştur
  BannerAd createBannerAd() {
    final adUnitId = _isTestMode ? _testBannerAdUnitId : _bannerAdUnitId;
    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner reklam yüklendi');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner reklam yüklenemedi: $error');
          ad.dispose();
        },
        onAdOpened: (ad) {
          print('Banner reklam açıldı');
        },
        onAdClosed: (ad) {
          print('Banner reklam kapandı');
        },
      ),
    );
  }

  // Interstitial reklam oluştur
  Future<InterstitialAd?> createInterstitialAd() async {
    final adUnitId =
        _isTestMode ? _testInterstitialAdUnitId : _interstitialAdUnitId;

    try {
      Completer<InterstitialAd?> completer = Completer<InterstitialAd?>();

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
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
      print('Interstitial reklam oluşturma hatası: $e');
      return null;
    }
  }

  // Rewarded reklam oluştur
  Future<RewardedAd?> createRewardedAd() async {
    final adUnitId = _isTestMode ? _testRewardedAdUnitId : _rewardedAdUnitId;

    try {
      RewardedAd? rewardedAd;
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            print('Rewarded reklam yüklendi');
            rewardedAd = ad;
          },
          onAdFailedToLoad: (error) {
            print('Rewarded reklam yüklenemedi: $error');
            rewardedAd = null;
          },
        ),
      );
      return rewardedAd;
    } catch (e) {
      print('Rewarded reklam oluşturma hatası: $e');
      return null;
    }
  }

  // Reklamları temizle
  void dispose() {
    // Gerekirse burada temizlik işlemleri yapılabilir
  }
}
