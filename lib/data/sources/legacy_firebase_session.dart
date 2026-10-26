import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// The Firebase sign-in a 4.2.x install left on the device.
class LegacyFirebaseUser {
  const LegacyFirebaseUser(
      {required this.uid, required this.anonymous, this.email});
  final String uid;
  final bool anonymous;
  final String? email;
}

/// The Firebase session can never produce a token again.
class LegacySessionGone implements Exception {
  const LegacySessionGone();
}

abstract class LegacyFirebaseSession {
  Future<LegacyFirebaseUser?> current();

  /// A freshly refreshed ID token. Throws [LegacySessionGone] once the account
  /// is deleted, disabled or its sessions were revoked.
  Future<String> idToken();
  Future<void> signOut();
}

class SdkLegacyFirebaseSession implements LegacyFirebaseSession {
  SdkLegacyFirebaseSession([FirebaseAuth? auth]) : _auth = auth;
  final FirebaseAuth? _auth;
  FirebaseAuth get _firebase => _auth ?? FirebaseAuth.instance;

  static const _gone = {
    'user-disabled',
    'user-not-found',
    'user-token-expired',
    'invalid-user-token',
  };

  @override
  Future<LegacyFirebaseUser?> current() async {
    // The persisted user can be restored just after Firebase initializes.
    final user = _firebase.currentUser ??
        await _firebase
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
    if (user == null) return null;
    return LegacyFirebaseUser(
        uid: user.uid, anonymous: user.isAnonymous, email: user.email);
  }

  @override
  Future<String> idToken() async {
    final user = _firebase.currentUser;
    if (user == null) throw const LegacySessionGone();
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) throw const LegacySessionGone();
      return token;
    } on FirebaseAuthException catch (error) {
      if (_gone.contains(error.code)) throw const LegacySessionGone();
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _firebase.signOut();
}
