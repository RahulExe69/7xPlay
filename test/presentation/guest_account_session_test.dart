import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

Map<String, dynamic> guestFixture({int id = 41, String token = '41|guest'}) => {
      'success': true,
      'token': token,
      'user': {
        'id': id,
        'name': 'Guest',
        'email': null,
        'username': 'guest_abc',
        'is_guest': true,
        'created_at': '2026-10-24T08:00:00Z',
      },
    };

void main() {
  late SessionHarness harness;

  setUp(() async {
    harness = await SessionHarness.create();
    await harness.session.restore();
  });
  tearDown(() => harness.dispose());

  bool browsing() => harness.session.state
      .maybeWhen(guest: (browsing) => browsing, orElse: () => false);

  test('entering guest mode creates a tracked guest account', () async {
    harness.adapter.enqueueJson(guestFixture(), statusCode: 201);

    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();

    final request = harness.adapter.requests.single;
    expect(request.path, 'auth/guest');
    expect(request.headers['Authorization'], isNull);
    expect(browsing(), isTrue);
    expect(harness.session.user, isNull, reason: 'guests never sync');
    expect(harness.session.ownerId.value, isNull);
    expect(harness.session.accountId.value, 'guest:41');
    expect(harness.tokens.value, '41|guest');
  });

  test('a guest account survives a restart without a network call', () async {
    harness.adapter.enqueueJson(guestFixture(), statusCode: 201);
    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();

    await harness.session.restore();

    expect(harness.adapter.requests, hasLength(1));
    expect(browsing(), isTrue);
    expect(harness.session.accountId.value, 'guest:41');
    expect(harness.session.token, '41|guest');
  });

  test('offline guests browse now and get their account later', () async {
    harness.adapter
      ..enqueueError()
      ..enqueueJson(guestFixture(), statusCode: 201);

    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();
    expect(browsing(), isTrue);
    expect(harness.session.accountId.value, isNull);

    await harness.session.restore();
    await harness.session.ensureGuestAccount();
    expect(browsing(), isTrue);
    expect(harness.session.accountId.value, 'guest:41');
  });

  test('re-entering guest mode keeps the existing guest account', () async {
    harness.adapter.enqueueJson(guestFixture(), statusCode: 201);
    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();

    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();

    expect(harness.adapter.requests, hasLength(1));
    expect(harness.session.accountId.value, 'guest:41');
  });

  test('signing up sends the guest token so the account is upgraded', () async {
    harness.adapter
      ..enqueueJson(guestFixture(), statusCode: 201)
      ..enqueueJson(authFixture(id: 41, token: '41|member'), statusCode: 201);
    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();

    await harness.session.signUp(const RegisterRequest(
        name: 'Member',
        email: 'member@example.com',
        username: 'member',
        password: 'secret123'));

    final request = harness.adapter.requests.last;
    expect(request.path, 'auth/register');
    expect((request.data as Map)['guest_token'], '41|guest');
    expect(harness.session.user?.id, 41);
    expect(harness.session.accountId.value, 'user:41');
    expect(harness.tokens.value, '41|member');

    harness.adapter.enqueueJson(authFixture(id: 41, token: '41|member'));
    await harness.session.restore();
    expect(harness.adapter.requests.last.path, 'user/profile',
        reason: 'the upgraded session restores as an account, not a guest');
    expect(harness.session.user?.id, 41);
  });

  test('leaving guest mode keeps the account for sign-up and reuse', () async {
    harness.adapter.enqueueJson(guestFixture(), statusCode: 201);
    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();

    await harness.session.signOut();
    expect(harness.adapter.requests.map((r) => r.path), ['auth/guest'],
        reason: 'the guest token is not revoked');
    expect(browsing(), isFalse);
    expect(harness.session.accountId.value, 'guest:41');

    await harness.session.restore();
    expect(browsing(), isFalse);
    expect(harness.session.token, '41|guest');

    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();
    expect(browsing(), isTrue);
    expect(harness.adapter.requests, hasLength(1));
  });

  test('a rejected guest token is replaced without leaving guest mode',
      () async {
    harness.adapter.enqueueJson(guestFixture(), statusCode: 201);
    await harness.session.enterGuest();
    await harness.session.ensureGuestAccount();

    harness.adapter
        .enqueueJson(guestFixture(id: 42, token: '42|guest'), statusCode: 201);
    await harness.session.expire('41|guest');
    await harness.session.ensureGuestAccount();

    expect(browsing(), isTrue);
    expect(harness.session.accountId.value, 'guest:42');
    expect(harness.tokens.value, '42|guest');
  });
}
