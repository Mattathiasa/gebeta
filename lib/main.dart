import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/ads_service.dart';
import 'core/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One container for the whole app so services initialised here (ads)
  // are the same instances the widgets read.
  final container = ProviderContainer();

  // Never awaited: a slow cloud handshake must not delay the first frame.
  // Stub mode (unconfigured Firebase) returns immediately.
  await FirebaseBootstrap.initialise();

  // Ad SDK warm-up. Noop on web — see adServiceProvider.
  await container.read(adServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GebetaApp(),
    ),
  );
}
