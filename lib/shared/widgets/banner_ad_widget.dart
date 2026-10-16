import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/services/ads_service.dart';

/// Bottom banner — Android/iOS only. Renders nothing on web so the
/// desktop layout stays clean (and ad-free, per the product decision).
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _banner;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    // Reuse the unit id resolved by AdService through a fresh load —
    // BannerAd requires its own instance per size anyway.
    _banner = BannerAd(
      size: AdSize.banner,
      // Default matches MobileAdService's test unit; production swaps
      // via --dart-define=ADMOB_BANNER_UNIT=...
      adUnitId: const String.fromEnvironment(
        'ADMOB_BANNER_UNIT',
        defaultValue: 'ca-app-pub-3940256099942544/6300978111',
      ),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _banner = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adServiceProvider);
    if (ads is NoopAdService || kIsWeb || !_loaded || _banner == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        width: _banner!.size.width.toDouble(),
        height: _banner!.size.height.toDouble(),
        child: AdWidget(ad: _banner!),
      ),
    );
  }
}
