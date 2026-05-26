import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class TrackingTransparencyService {
  static final TrackingTransparencyService _instance =
      TrackingTransparencyService._internal();
  factory TrackingTransparencyService() => _instance;
  TrackingTransparencyService._internal();

  Future<TrackingStatus>? _requestFuture;
  TrackingStatus? _status;

  Future<TrackingStatus> requestIfNeeded() {
    return _requestFuture ??= _requestTrackingAuthorization();
  }

  Future<TrackingStatus> _requestTrackingAuthorization() async {
    if (kIsWeb || !Platform.isIOS) {
      _status = TrackingStatus.notSupported;
      return _status!;
    }

    try {
      _status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (_status == TrackingStatus.notDetermined) {
        // ATT must be requested while the app is active.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        _status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return _status!;
    } catch (e) {
      debugPrint('App Tracking Transparency request failed: $e');
      _status = TrackingStatus.denied;
      return _status!;
    }
  }

  Future<bool> get isTrackingAuthorized async {
    if (kIsWeb || !Platform.isIOS) return true;
    _status ??= await AppTrackingTransparency.trackingAuthorizationStatus;
    return _status == TrackingStatus.authorized;
  }

  Future<AdRequest> createAdRequest() async {
    if (kIsWeb || !Platform.isIOS) {
      return const AdRequest();
    }

    await requestIfNeeded();
    final nonPersonalizedAds = !await isTrackingAuthorized;
    return AdRequest(nonPersonalizedAds: nonPersonalizedAds);
  }
}
