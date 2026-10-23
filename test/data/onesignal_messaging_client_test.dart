import 'dart:async';
import 'package:flixquest/data/sources/onesignal_messaging_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const appId = '11111111-1111-4111-8111-111111111111';
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channelNames = [
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#user',
    'OneSignal#pushsubscription',
    'OneSignal#notifications',
    'OneSignal#inappmessages'
  ];
  late OneSignalMessagingClient client;
  Future<void> native(
      String channel, String method, Map<String, dynamic> data) async {
    final finished = Completer<void>();
    await messenger.handlePlatformMessage(
        channel,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, data)),
        (_) => finished.complete());
    await finished.future;
    await Future<void>.delayed(Duration.zero);
  }

  Map<String, dynamic> notification(Map<String, dynamic> data) => {
        'notification': {
          'notificationId': 'notification-1',
          'title': 'Notice',
          'body': 'Open it',
          'additionalData': data
        },
        'result': <String, dynamic>{}
      };
  setUp(() async {
    calls.clear();
    for (final name in channelNames) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        calls.add(call);
        if (call.method == 'OneSignal#pushSubscriptionId') return appId;
        if (call.method == 'OneSignal#pushSubscriptionOptedIn' ||
            call.method == 'OneSignal#permission') {
          return true;
        }
        return null;
      });
    }
    client = OneSignalMessagingClient();
    await client.initialize(appId, platform: 'tv');
  });
  tearDown(() async {
    await client.dispose();
    for (final name in channelNames) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
  test('initializes the SDK and platform tag without assigning account aliases',
      () async {
    expect(await client.getToken(), appId);
    expect(
        calls.any((call) =>
            call.method == 'OneSignal#initialize' &&
            call.arguments['appId'] == appId),
        isTrue);
    expect(
        calls.any((call) =>
            call.method == 'OneSignal#addTags' &&
            call.arguments['flixquest_platform'] == 'tv'),
        isTrue);
    expect(
        calls.any((call) =>
            call.method.contains('login') || call.method.contains('Alias')),
        isFalse);
  });
  test('buffers cold-start clicks and passes later clicks through once',
      () async {
    const data = {'type': 'push_message', 'message_id': appId};
    await native('OneSignal#notifications', 'OneSignal#onClickNotification',
        notification(data));
    final opened = <Map<String, dynamic>>[];
    final listener = client.openedMessages.listen(opened.add);
    expect(await client.initialMessage(), data);
    expect(await client.initialMessage(), isNull);
    await native('OneSignal#notifications', 'OneSignal#onClickNotification',
        notification(data));
    expect(opened, [data]);
    await listener.cancel();
  });
  test(
      'subscription permission loss invalidates the token and notifies Laravel registration',
      () async {
    final tokens = <String>[];
    final listener = client.tokenRefresh.listen(tokens.add);
    await native(
        'OneSignal#pushsubscription', 'OneSignal#onPushSubscriptionChange', {
      'previous': {'id': appId, 'optedIn': true},
      'current': {'id': appId, 'optedIn': false}
    });
    expect(await client.getToken(), isNull);
    expect(tokens, ['']);
    await listener.cancel();
  });
  test(
      'campaign foreground alerts retain their native notification until opened',
      () async {
    await native(
        'OneSignal#notifications',
        'OneSignal#onWillDisplayNotification',
        notification({'type': 'push_message', 'message_id': appId}));
    expect(calls.any((call) => call.method == 'OneSignal#preventDefault'),
        isFalse);
  });
  test(
      'legacy foreground notices use in-app presentation and remove listeners on disposal',
      () async {
    final received = <Map<String, dynamic>>[];
    final listener = client.foregroundMessages.listen(received.add);
    await native(
        'OneSignal#notifications',
        'OneSignal#onWillDisplayNotification',
        notification({'type': 'in_app_message', 'announcement_id': '42'}));
    expect(received.single['announcement_id'], '42');
    expect(
        calls.any((call) => call.method == 'OneSignal#preventDefault'), isTrue);
    await listener.cancel();
    await client.dispose();
    await native(
        'OneSignal#notifications',
        'OneSignal#onWillDisplayNotification',
        notification({'type': 'in_app_message'}));
    expect(received.length, 1);
  });
}
