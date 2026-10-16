import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_bootstrap.dart';

/// Identity for online play. Anonymous by design — no email, no
/// password, nothing to forget. Upgrade-to-account can come later.
abstract class AuthService {
  Future<String> uid();
}

/// Firebase anonymous auth (used when the project is configured).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<String> uid() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }
}

/// Offline/demo identity: a random local id. Lets the lobby and stub
/// room flow work before `flutterfire configure` has been run.
class StubAuthService implements AuthService {
  var _cached = '';

  @override
  Future<String> uid() async {
    if (_cached.isNotEmpty) return _cached;
    final random = Random.secure();
    _cached = 'local-${List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join()}';
    return _cached;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  if (!firebaseIsConfigured) return StubAuthService();
  try {
    return FirebaseAuthService(FirebaseAuth.instance);
  } catch (e) {
    debugPrint('FirebaseAuth unavailable, using stub identity: $e');
    return StubAuthService();
  }
});

final uidProvider = FutureProvider<String>((ref) {
  return ref.watch(authServiceProvider).uid();
});
