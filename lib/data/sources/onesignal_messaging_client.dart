import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'push_messaging_client.dart';

/// OneSignal stays device-scoped. Laravel owns the account association.
class OneSignalMessagingClient implements PushMessagingClient {
  final _tokens = StreamController<String>.broadcast();
  final _foreground = StreamController<Map<String, dynamic>>.broadcast();
  final _opened = StreamController<Map<String, dynamic>>.broadcast();
  final _pendingClicks = <Map<String, dynamic>>[];
  bool _disposed = false;

  static bool validAppId(String value) => RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      .hasMatch(value);

  Future<void> initialize(String appId, {required String platform}) async {
    if (!validAppId(appId)) throw ArgumentError('Invalid OneSignal App ID.');
    OneSignal.Notifications.addClickListener(_onClick);
    OneSignal.Notifications.addForegroundWillDisplayListener(_onForeground);
    OneSignal.User.pushSubscription.addObserver(_onSubscription);
    await OneSignal.initialize(appId);
    await OneSignal.User.addTagWithKey('flixquest_platform', platform);
    // Laravel controls in-app presentation, avoiding a second campaign channel.
    await OneSignal.InAppMessages.paused(true);
  }

  void _onSubscription(OSPushSubscriptionChangedState state) {
    if (!_disposed) {
      _tokens.add(state.current.optedIn == true ? state.current.id ?? '' : '');
    }
  }

  Map<String, dynamic> _data(OSNotification notification) => {
        ...?notification.additionalData,
        if (notification.additionalData?['type'] != 'push_message') ...{
          'id': 'onesignal:${notification.notificationId}',
          'title': notification.title ?? '',
          'body': notification.body ?? '',
        },
      };

  void _onForeground(OSNotificationWillDisplayEvent event) {
    if (_disposed) return;
    final data = _data(event.notification);
    // Keep a system notification for a private message; its content is fetched
    // only when opened, so a failed/offline fetch does not lose the alert.
    if (data['type'] == 'push_message') return;
    event.preventDefault();
    _foreground.add(data);
  }

  void _onClick(OSNotificationClickEvent event) {
    if (_disposed) return;
    final data = _data(event.notification);
    if (_opened.hasListener) {
      _opened.add(data);
    } else {
      if (_pendingClicks.length == 20) _pendingClicks.removeAt(0);
      _pendingClicks.add(data);
    }
  }

  @override
  Future<String?> getToken() async =>
      OneSignal.User.pushSubscription.optedIn == true
          ? OneSignal.User.pushSubscription.id
          : null;
  @override
  Stream<String> get tokenRefresh => _tokens.stream;
  @override
  Stream<Map<String, dynamic>> get foregroundMessages => _foreground.stream;
  @override
  Stream<Map<String, dynamic>> get openedMessages => _opened.stream;
  @override
  Future<Map<String, dynamic>?> initialMessage() async {
    if (_pendingClicks.isEmpty) return null;
    final first = _pendingClicks.removeAt(0);
    for (final data in _pendingClicks) {
      _opened.add(data);
    }
    _pendingClicks.clear();
    return first;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    OneSignal.Notifications.removeClickListener(_onClick);
    OneSignal.Notifications.removeForegroundWillDisplayListener(_onForeground);
    OneSignal.User.pushSubscription.removeObserver(_onSubscription);
    _pendingClicks.clear();
    await Future.wait([_tokens.close(), _foreground.close(), _opened.close()]);
  }
}
