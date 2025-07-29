import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:backgammon_score_tracker/core/services/ad_service.dart';
import 'package:backgammon_score_tracker/core/services/premium_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isPremium = false;
  final _premiumService = PremiumService();

  @override
  void initState() {
    super.initState();
    _checkPremiumAndLoadAd();
  }

  Future<void> _checkPremiumAndLoadAd() async {
    try {
      final hasPremium = await _premiumService.hasPremiumAccess();
      if (hasPremium) {
        setState(() {
          _isPremium = true;
        });
        return; // Premium kullanıcılar için reklam yükleme
      }

      _loadBannerAd();
    } catch (e) {
      _loadBannerAd(); // Hata durumunda reklam yükle
    }
  }

  void _loadBannerAd() {
    final adService = AdService();
    _bannerAd = adService.createBannerAd();

    _bannerAd?.load().then((_) {
      if (mounted) {
        setState(() {
          _isLoaded = true;
        });
        print('✅ Banner ad widget başarıyla yüklendi');
      }
    }).catchError((error) {
      print('❌ Banner ad widget yükleme hatası: $error');
      if (mounted) {
        setState(() {
          _isLoaded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Premium kullanıcılar için reklam gösterme
    if (_isPremium) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom + 8,
        ),
        child: Container(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
