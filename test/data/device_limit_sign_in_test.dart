import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/models/signed_in_device.dart';
import 'package:flixquest/data/repositories/auth_repository.dart';
import 'package:flixquest/data/sources/laravel_api.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_dio.dart';
import '../support/session_harness.dart';

Map<String, dynamic> _authFixture() =>
    jsonDecode(File('test/support/fixtures/auth.json').readAsStringSync())
        as Map<String, dynamic>;

const _limitReached = {
  'success': false,
  'message': 'This account is signed in on 2 devices.',
  'code': 'device_limit_reached',
  'limit': 2,
  'devices': [
    {
      'id': 4,
      'name': 'Pixel 9',
      'platform': 'android',
      'signed_in_at': '2026-10-01T10:00:00.000000Z',
      'last_used_at': '2026-10-25T18:30:00.000000Z',
      'current': false,
    },
    {
      'id': 5,
      'name': null,
      'platform': 'tv',
      'signed_in_at': '2026-10-02T10:00:00.000000Z',
      'last_used_at': null,
      'current': false,
    },
  ],
};

void main() {
  test(
      'sign-in names the device, reads a device-limit refusal and retries '
      'in place of the chosen device', () async {
    final adapter = FakeDioAdapter()
      ..enqueueJson(_limitReached, statusCode: 409)
      ..enqueueJson(_authFixture());
    final dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repository = AuthRepository(LaravelApi(dio),
        deviceFields: () async => {
              'device_id': 'install-1',
              'platform': 'android',
              'device_name': 'Galaxy S25',
            });
    const request = LoginRequest(email: 'a@example.com', password: 'secret');

    final refused = await repository.signIn(request);

    final failure = refused.when(
        ok: (_) => fail('Sign-in should be refused'), err: (f) => f);
    expect(failure, isA<DeviceLimitFailure>());
    final limit = failure as DeviceLimitFailure;
    expect(limit.limit, 2);
    expect(limit.devices.map((device) => device.id), [4, 5]);
    expect(limit.devices.first.name, 'Pixel 9');
    expect(limit.devices.first.lastUsedAt, DateTime.utc(2026, 10, 25, 18, 30));
    expect(limit.devices.last.platform, 'tv');
    expect(adapter.requests.first.data, containsPair('device_id', 'install-1'));
    expect(
        adapter.requests.first.data, containsPair('device_name', 'Galaxy S25'));
    expect(adapter.requests.first.data, isNot(contains('replace_device_id')));

    final retried = await repository.signIn(request, replaceDeviceId: 4);

    expect(retried.when(ok: (session) => session.user.id, err: (_) => null), 7);
    expect(adapter.requests.last.data, containsPair('replace_device_id', 4));
    expect(adapter.requests.last.data, containsPair('device_id', 'install-1'));
  });

  test('a Google retry after the device picker reuses the refused sign-in',
      () async {
    final harness = await SessionHarness.create();
    addTearDown(harness.dispose);
    harness.google.idToken = 'google-first';
    harness.adapter
      ..enqueueJson(_limitReached, statusCode: 409)
      ..enqueueJson(_authFixture());

    final refused = await harness.session.signInWithGoogle();
    expect(refused.when(ok: (_) => null, err: (f) => f),
        isA<DeviceLimitFailure>());

    harness.google.idToken = 'google-second';
    final retried = await harness.session.signInWithGoogle(replaceDeviceId: 5);

    expect(
        retried.when(ok: (session) => session?.user.id, err: (_) => null), 7);
    expect(harness.adapter.requests.last.data,
        containsPair('id_token', 'google-first'));
    expect(harness.adapter.requests.last.data,
        containsPair('replace_device_id', 5));
  });

  group('withinDeviceLimit', () {
    final refusal = AuthActionException.fromFailure(const Failure.deviceLimit(
        limit: 1, devices: [SignedInDevice(id: 9, name: 'Old phone')]));

    test('signs in again in place of the device the person picks', () async {
      final attempts = <int?>[];
      final result = await FlixQuestAuthService().withinDeviceLimit(
          (replaceDeviceId) async {
        attempts.add(replaceDeviceId);
        if (replaceDeviceId == null) throw refusal;
        return 'signed in';
      }, pick: (limit) async => limit.devices.single.id);

      expect(result, 'signed in');
      expect(attempts, [null, 9]);
    });

    test('gives up quietly when the person backs out of the picker', () async {
      var attempts = 0;
      final result =
          await FlixQuestAuthService().withinDeviceLimit<String>((_) async {
        attempts++;
        throw refusal;
      }, pick: (_) async => null);

      expect(result, isNull);
      expect(attempts, 1);
    });

    test('passes other sign-in failures through', () async {
      const other =
          AuthActionException(code: 'invalid-credential', message: 'Nope');

      expect(
          FlixQuestAuthService().withinDeviceLimit<String>((_) async {
            throw other;
          }, pick: (_) async => fail('No picker for other failures')),
          throwsA(same(other)));
    });
  });
}
