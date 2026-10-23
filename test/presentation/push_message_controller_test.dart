import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/repositories/announcement_repository.dart';
import 'package:flixquest/data/repositories/device_repository.dart';
import 'package:flixquest/data/repositories/push_message_repository.dart';
import 'package:flixquest/data/sources/onesignal_messaging_client.dart';
import 'package:flixquest/models/in_app_message_payload.dart';
import 'package:flixquest/presentation/notifications/device_registration_controller.dart';
import 'package:flixquest/presentation/notifications/in_app_message_controller.dart';
import 'package:flixquest/presentation/notifications/push_message_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_push_messaging.dart';
import '../support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = '11111111-1111-4111-8111-111111111111';
  const hint = {'type': 'push_message', 'message_id': id};
  late SessionHarness h;
  late InAppMessageController messages;
  late PushMessageController controller;
  late List<InAppMessagePayload> shown;
  var ready = true;
  Future<void> login(int account) async {
    h.adapter.enqueueJson(authFixture(id: account, token: 'token-$account'));
    await h.session.signIn(
        const LoginRequest(email: 'a@example.com', password: 'password'));
  }

  void content({bool private = true, String responseId = id}) =>
      h.adapter.enqueueJson({
        'success': true,
        'message': {
          'id': responseId,
          'private': private,
          'title': 'Account message',
          'body': 'Private content'
        }
      });
  setUp(() async {
    h = await SessionHarness.create();
    shown = [];
    ready = true;
    messages =
        InAppMessageController(AnnouncementRepository(h.dio), h.preferences,
            (payload, acknowledge) async {
      if (!ready) return false;
      shown.add(payload);
      await acknowledge();
      return true;
    });
    controller = PushMessageController(PushMessageRepository(h.dio), messages,
        currentOwner: () => h.session.ownerId.value,
        currentToken: () => h.session.token);
  });
  tearDown(() async {
    controller.dispose();
    messages.dispose();
    await h.dispose();
  });

  test(
      'private taps fetch through the authenticated no-store API and dedupe presentation',
      () async {
    await login(7);
    content();
    await controller.receive(hint);
    expect(shown.single.id, 'push:$id:user:7');
    final request = h.adapter.requests.last;
    expect(request.path, 'push/messages/$id');
    expect(request.headers['Authorization'], 'Bearer token-7');
    expect(request.extra['cachePolicy'], CachePolicy.noStore);
    content();
    await controller.receive(hint);
    expect(shown.length, 1);
  });
  test('account switch during content fetch discards the response', () async {
    await login(7);
    final started = Completer<void>();
    final release = Completer<void>();
    h.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      if (request.path.startsWith('push/messages')) {
        started.complete();
        await release.future;
      }
      handler.next(request);
    }));
    final work = controller.receive(hint);
    await started.future;
    await login(8);
    content();
    release.complete();
    await work;
    expect(shown, isEmpty);
  });
  test('queued private content cannot appear after switching accounts',
      () async {
    await login(7);
    ready = false;
    content();
    await controller.receive(hint);
    await login(8);
    ready = true;
    await messages.onReady();
    expect(shown, isEmpty);
    content();
    await controller.receive(hint);
    expect(shown.single.id, 'push:$id:user:8');
  });
  test('guests can open public campaigns and cannot present private content',
      () async {
    await h.session.enterGuest();
    content();
    await controller.receive(hint);
    expect(shown, isEmpty);
    content(private: false);
    await controller.receive(hint);
    expect(shown.single.id, 'push:$id');
  });
  test(
      'unknown IDs, unauthorized and malformed responses do not display content',
      () async {
    await controller
        .receive({'type': 'push_message', 'message_id': '../secret'});
    expect(h.adapter.requests, isEmpty);
    h.adapter.enqueueJson({'success': false}, statusCode: 404);
    await controller.receive(hint);
    content(responseId: 'different-id');
    await controller.receive(hint);
    h.adapter.enqueueJson({'success': true, 'message': 'invalid'});
    await controller.receive(hint);
    expect(shown, isEmpty);
  });
  test('legacy announcement payloads still use the common presentation queue',
      () async {
    await controller.receive(
        {'type': 'in_app_message', 'announcement_id': '42', 'title': 'Legacy'});
    expect(shown.single.id, '42');
  });
  test('disposed controller ignores late fetches and new hints', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    h.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      started.complete();
      await release.future;
      handler.next(request);
    }));
    content(private: false);
    final work = controller.receive(hint);
    await started.future;
    controller.dispose();
    release.complete();
    await work;
    await controller.receive(hint);
    expect(shown, isEmpty);
    expect(h.adapter.requests.length, 1);
  });
  test(
      'OneSignal registration uses subscription IDs and removes opted out associations',
      () async {
    await login(7);
    final push = FakePushMessaging()..token = id;
    final registration = DeviceRegistrationController(
        DeviceRepository(h.dio), h.session, h.preferences, push,
        platform: 'tv', appVersion: '4.3.0', provider: 'onesignal');
    addTearDown(() async {
      registration.dispose();
      await push.dispose();
    });
    h.adapter.enqueueJson({'success': true});
    await registration.boot();
    expect(h.adapter.requests.last.path, 'push/subscriptions');
    expect(h.adapter.requests.last.data,
        {'subscription_id': id, 'platform': 'tv', 'app_version': '4.3.0'});
    push.token = null;
    h.adapter.enqueueJson({'success': true});
    push.tokens.add('');
    await registration.onResume();
    expect(h.adapter.requests.last.method, 'DELETE');
    expect(h.adapter.requests.last.path, 'push/subscriptions/$id');
  });
  test('OneSignal validates public App IDs without requiring the native SDK',
      () {
    expect(OneSignalMessagingClient.validAppId(id), isTrue);
    expect(OneSignalMessagingClient.validAppId('REST_API_KEY'), isFalse);
    expect(OneSignalMessagingClient.validAppId(''), isFalse);
  });
}
