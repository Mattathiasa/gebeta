import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// True when `flutterfire configure` has not been run yet — the generated
/// [DefaultFirebaseOptions] still contains `YOUR_` placeholders.
///
/// Passing those placeholders into the native SDK raises an *uncatchable*
/// exception before any Dart try/catch can run (documented in karaoki's
/// main.dart). So we detect and fall back to stub services instead.
bool get firebaseIsConfigured => !DefaultFirebaseOptions.currentPlatform
    .toString()
    .contains('YOUR_');

abstract final class FirebaseBootstrap {
  /// Initialises Firebase when configured; otherwise the app runs in
  /// offline/stub mode so UI development never blocks on cloud setup.
  static Future<bool> initialise() async {
    if (!firebaseIsConfigured) {
      debugPrint(
        'Firebase not configured (flutterfire configure) — running in stub mode.',
      );
      return false;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } catch (e, st) {
      // Never let a cloud outage keep the player off the board.
      debugPrint('Firebase init failed, continuing offline: $e\n$st');
      return false;
    }
  }
}
