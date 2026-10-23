import 'package:dio/dio.dart';
import 'package:flixquest/data/sources/legacy_firebase_session.dart';
import 'package:flixquest/presentation/session/firebase_session_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

class FakeLegacySession implements LegacyFirebaseSession {
  FakeLegacySession(this.user, {this.token = 'firebase-id-token'});
  LegacyFirebaseUser? user;
  Object token;
  int reads = 0;
  int signOuts = 0;

  @override
  Future<LegacyFirebaseUser?> current() async {
    reads++;
    return user;
  }

  @override
  Future<String> idToken() async {
    final value = token;
    if (value is Exception) throw value;
    return value as String;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    user = null;
  }
}

const _account = LegacyFirebaseUser(
    uid: 'fb-uid', anonymous: false, email: 'old@example.com');

void main() {
  late SessionHarness harness;
  late List<(String, String)> moves;

  setUp(() async {
    harness = await SessionHarness.create();
    await harness.session.restore();
    moves = [];
  });
  tearDown(() => harness.dispose());

  FirebaseSessionBridge bridge(FakeLegacySession legacy) =>
      FirebaseSessionBridge(
        session: harness.session,
        legacy: legacy,
        preferences: harness.preferences,
        moveLocalOwner: (from, to) async => moves.add((from, to)),
      );

  bool done() =>
      harness.preferences.getBool(FirebaseSessionBridge.doneKey) ?? false;

  test('a signed-in 4.2.x account stays signed in through the exchange',
      () async {
    harness.adapter.enqueueJson(authFixture());
    final legacy = FakeLegacySession(_account);

    await bridge(legacy).run();

    final request = harness.adapter.requests.single;
    expect(request.path, 'auth/firebase/exchange');
    expect(request.data, {'id_token': 'firebase-id-token'});
    expect(request.headers['Authorization'], isNull);
    expect(harness.session.user?.id, 7);
    expect(harness.tokens.value, '7|sanitized-test-token');
    expect(moves, [('user:fb-uid', 'user:7')]);
    expect(legacy.signOuts, 1);
    expect(done(), isTrue);
    expect(FirebaseSessionBridge.emailHint(harness.preferences), isNull);

    await bridge(legacy).run();
    expect(legacy.reads, 1, reason: 'a finished bridge never runs again');
  });

  test('4.2.x guests keep browsing instead of seeing sign-in', () async {
    final legacy = FakeLegacySession(
        const LegacyFirebaseUser(uid: 'anon', anonymous: true));

    await bridge(legacy).run();

    expect(
        harness.session.state
            .maybeWhen(guest: (browsing) => browsing, orElse: () => false),
        isTrue);
    expect(harness.adapter.requests, isEmpty);
    expect(legacy.signOuts, 1);
    expect(done(), isTrue);
  });

  test('fresh installs finish without touching Firebase or Laravel', () async {
    final legacy = FakeLegacySession(null);

    await bridge(legacy).run();

    expect(harness.adapter.requests, isEmpty);
    expect(legacy.signOuts, 0);
    expect(done(), isTrue);
  });

  for (final (status, code) in [
    (401, 'firebase_session_invalid'),
    (409, 'firebase_account_conflict'),
  ]) {
    test('a $status exchange stops and prefills the sign-in email', () async {
      harness.adapter.enqueueJson(
          {'success': false, 'message': 'No', 'code': code},
          statusCode: status);
      final legacy = FakeLegacySession(_account);

      await bridge(legacy).run();

      expect(harness.session.user, isNull);
      expect(legacy.signOuts, 1);
      expect(done(), isTrue);
      expect(FirebaseSessionBridge.emailHint(harness.preferences),
          'old@example.com');
      expect(moves, isEmpty);
    });
  }

  test('a Firebase account that is gone stops without calling Laravel',
      () async {
    final legacy =
        FakeLegacySession(_account, token: const LegacySessionGone());

    await bridge(legacy).run();

    expect(harness.adapter.requests, isEmpty);
    expect(legacy.signOuts, 1);
    expect(done(), isTrue);
    expect(FirebaseSessionBridge.emailHint(harness.preferences),
        'old@example.com');
  });

  test('offline and server failures keep the Firebase session for a retry',
      () async {
    harness.adapter
      ..enqueueError()
      ..enqueueJson({'success': false, 'message': 'Try later'}, statusCode: 503)
      ..enqueueJson(authFixture());
    final legacy = FakeLegacySession(_account);
    final subject = bridge(legacy);

    await subject.run();
    await subject.run();
    expect(legacy.signOuts, 0);
    expect(done(), isFalse);
    expect(harness.session.user, isNull);

    await subject.run();
    expect(harness.session.user?.id, 7);
    expect(legacy.signOuts, 1);
    expect(done(), isTrue);
  });

  test('a Firebase token refresh failure retries later', () async {
    final legacy =
        FakeLegacySession(_account, token: Exception('network-request-failed'));

    await bridge(legacy).run();

    expect(harness.adapter.requests, isEmpty);
    expect(legacy.signOuts, 0);
    expect(done(), isFalse);
  });

  test('an existing Laravel session only clears the leftover Firebase one',
      () async {
    harness.adapter.enqueueJson(authFixture(id: 9));
    await harness.session.signInWithFirebaseSession('earlier-token');
    final legacy = FakeLegacySession(_account);

    await bridge(legacy).run();

    expect(harness.adapter.requests, hasLength(1));
    expect(harness.session.user?.id, 9);
    expect(moves, isEmpty,
        reason: 'local data of a different identity is not adopted');
    expect(legacy.signOuts, 1);
    expect(done(), isTrue);
  });

  test('launch and resume share one exchange in flight', () async {
    harness.adapter.enqueueJson(authFixture());
    final legacy = FakeLegacySession(_account);
    final subject = bridge(legacy);

    final first = subject.run();
    final second = subject.run();
    await Future.wait([first, second]);

    expect(
        harness.adapter.requests
            .where((RequestOptions r) => r.path == 'auth/firebase/exchange'),
        hasLength(1));
    expect(legacy.reads, 1);
  });
}
