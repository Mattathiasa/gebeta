import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Monetization seam. Android gets real AdMob; web and unconfigured
/// builds get a no-op so gameplay never depends on ads.
///
/// Ad unit IDs come from --dart-define (see config/README.md). Defaults
/// are Google's official *test* units — swap them before publishing or
/// the account earns nothing.
abstract class AdService {
  Future<void> init();
  Future<void> showBanner();
  Future<void> maybeShowInterstitial();
  void dispose() {}
}

const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';

final _interstitialUnit = const String.fromEnvironment(
  'ADMOB_INTERSTITIAL_UNIT',
  defaultValue: _testInterstitialAndroid,
);

/// Interstitial cadence: every other finished game. Never mid-turn —
/// losing a turn to an ad is how you lose a player.
const _interstitialEveryNGames = 2;

class NoopAdService implements AdService {
  @override
  Future<void> init() async {}

  @override
  Future<void> showBanner() async {}

  @override
  Future<void> maybeShowInterstitial() async {}

  @override
  void dispose() {}
}

class MobileAdService implements AdService {
  InterstitialAd? _interstitial;
  var _gamesSinceAd = 0;

  @override
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _preloadInterstitial();
  }

  @override
  Future<void> showBanner() async {
    // Banner rendering lives in BannerAdWidget; init is all that's
    // needed here.
  }

  void _preloadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  @override
  Future<void> maybeShowInterstitial() async {
    _gamesSinceAd++;
    if (_gamesSinceAd < _interstitialEveryNGames) return;
    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return;
    }
    _gamesSinceAd = 0;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _preloadInterstitial();
      },
    );
    await ad.show();
  }

  @override
  void dispose() {
    _interstitial?.dispose();
  }
}

final adServiceProvider = Provider<AdService>((ref) {
  // google_mobile_ads has no web support; keep the web build clean.
  // defaultTargetPlatform (not dart:io) so this compiles for web too.
  final mobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (kIsWeb || !mobile) {
    return NoopAdService();
  }
  final service = MobileAdService();
  ref.onDispose(service.dispose);
  return service;
});
