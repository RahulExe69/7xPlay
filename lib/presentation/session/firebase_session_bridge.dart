import 'dart:async';

import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import '../../data/sources/legacy_firebase_session.dart';
import 'auth_runtime.dart';
import 'session_view_model.dart';

/// Moves a 4.2.x Firebase sign-in onto Laravel on the first launch after the
/// upgrade, so accounts stay signed in and guests keep browsing without seeing
/// sign-in. Remove with `firebase_auth` once upgrades have settled.
class FirebaseSessionBridge {
  FirebaseSessionBridge(
      {required this.session,
      required this.legacy,
      required this.preferences,
      this.moveLocalOwner});

  static const doneKey = 'migration.firebase_session.done';
  static const emailHintKey = 'migration.firebase_session.email';

  final SessionViewModel session;
  final LegacyFirebaseSession legacy;
  final KvStore preferences;

  /// Re-keys local data 4.2.x stored under the Firebase identity
  /// (`user:<firebase uid>`) to the Laravel account (`user:<id>`).
  final Future<void> Function(String from, String to)? moveLocalOwner;
  Future<void>? _running;

  /// The email of an account that could not be carried over, for sign-in.
  static String? emailHint(KvStore preferences) =>
      preferences.getString(emailHintKey);

  /// [emailHint] for the running app's sign-in screens.
  static String? get signInEmailHint {
    final session = AuthRuntime.maybeSession;
    return session == null ? null : emailHint(session.preferences);
  }

  /// Safe on every launch and resume: a finished bridge returns at once, and
  /// a retryable failure keeps the Firebase session for the next attempt.
  Future<void> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    if (preferences.getBool(doneKey) ?? false) return;
    final LegacyFirebaseUser? user;
    try {
      user = await legacy.current();
    } catch (_) {
      return;
    }
    if (user == null) return _finish();
    if (session.user != null) return _finish(signOut: true);
    if (user.anonymous) {
      // 4.2.x guests were anonymous Firebase users who already chose to browse.
      if (!session.state
          .maybeWhen(guest: (browsing) => browsing, orElse: () => false)) {
        await session.enterGuest();
      }
      return _finish(signOut: true);
    }
    final String token;
    try {
      token = await legacy.idToken();
    } on LegacySessionGone {
      return _finish(signOut: true, email: user.email);
    } catch (_) {
      return;
    }
    final result = await session.signInWithFirebaseSession(token);
    await result.when(
      ok: (auth) async {
        await moveLocalOwner?.call('user:${user!.uid}', 'user:${auth.user.id}');
        await _finish(signOut: true);
      },
      err: (failure) async {
        // Network, rate-limit and server failures retry on the next resume.
        // At the device limit the person signs in by hand, where the app
        // asks which device to sign out.
        if (failure is UnauthorizedFailure ||
            failure is ForbiddenFailure ||
            failure is ConflictFailure ||
            failure is DeviceLimitFailure) {
          await _finish(
              signOut: true, email: session.user == null ? user!.email : null);
        }
      },
    );
  }

  Future<void> _finish({bool signOut = false, String? email}) async {
    if (email != null && email.isNotEmpty) {
      await preferences.setString(emailHintKey, email);
    }
    if (signOut) {
      try {
        await legacy.signOut();
      } catch (_) {/* The done flag stops later attempts either way. */}
    }
    await preferences.setBool(doneKey, true);
  }
}
