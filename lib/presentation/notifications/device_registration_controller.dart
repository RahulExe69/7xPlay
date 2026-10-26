import 'dart:async';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/data/repositories/device_repository.dart';
import 'package:flixquest/data/sources/push_messaging_client.dart';
import 'package:flixquest/presentation/session/session_view_model.dart';

class DeviceRegistrationController {
  DeviceRegistrationController(
      this.repository, this.session, this.store, this.messaging,
      {required this.platform,
      required this.appVersion,
      this.provider = 'fcm'});
  final DeviceRepository repository;
  final SessionViewModel session;
  final KvStore store;
  final PushMessagingClient messaging;
  final String platform;
  final String provider;
  final String appVersion;
  static const _receiptKey = 'notifications.device.registration';
  StreamSubscription<String>? _subscription;
  Future<void>? _inFlight;
  String? _token;
  String? _owner;
  String? _sessionToken;
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;
  bool _pending = false;
  bool _forceRegistration = true;

  Future<void> boot() {
    if (_disposed) return Future.value();
    if (!_started) {
      _started = true;
      _owner = session.accountId.value;
      _sessionToken = session.token;
      session.addListener(_sessionChanged);
      try {
        _subscription = messaging.tokenRefresh.listen((token) {
          if (token == _token) return;
          if (provider != 'onesignal') _token = token;
          _generation++;
          unawaited(_refresh());
        }, onError: (_) {});
      } catch (_) {/* Push may be unavailable on this device. */}
    }
    return _refresh();
  }

  void _sessionChanged() {
    if (_owner == session.accountId.value && _sessionToken == session.token) {
      return;
    }
    _owner = session.accountId.value;
    _sessionToken = session.token;
    _generation++;
    _forceRegistration = true;
    unawaited(_refresh());
  }

  Future<void> onResume() => boot();

  Future<void> _refresh() {
    if (_disposed) return Future.value();
    _pending = true;
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    do {
      _pending = false;
      final owner = session.accountId.value;
      final authToken = session.token;
      if (_disposed || owner == null || authToken == null) return;
      final generation = _generation;
      try {
        final token = provider == 'onesignal'
            ? await messaging.getToken()
            : _token ?? await messaging.getToken();
        if (_disposed ||
            generation != _generation ||
            session.accountId.value != owner ||
            session.token != authToken) {
          continue;
        }
        if (token == null || token.trim().isEmpty) {
          final receipt = store.getJson(_receiptKey);
          final previous = _token ??
              (receipt is Map &&
                      receipt['provider'] == provider &&
                      receipt['owner'] == owner
                  ? receipt['token'] as String?
                  : null);
          _token = null;
          _forceRegistration = true;
          if (provider == 'onesignal' &&
              previous != null &&
              previous.isNotEmpty) {
            await repository.unregister(previous, owner: owner);
          }
          return;
        }
        _token = token;
        final receipt = {
          'owner': owner,
          'provider': provider,
          'token': token,
          'platform': platform,
          'app_version': appVersion,
        };
        final previous = store.getJson(_receiptKey);
        if (!_forceRegistration &&
            previous is Map &&
            receipt.entries
                .every((entry) => previous[entry.key] == entry.value)) {
          continue;
        }
        final result = await repository.register(token, platform, appVersion,
            owner: owner, provider: provider);
        if (!_disposed &&
            generation == _generation &&
            session.accountId.value == owner &&
            session.token == authToken &&
            result is Ok<void>) {
          await store.setJson(_receiptKey, receipt);
          _forceRegistration = false;
        }
      } catch (_) {
        /* A failed registration retries on resume or token change. */
      }
    } while (_pending && !_disposed);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    if (_started) session.removeListener(_sessionChanged);
    unawaited(_subscription?.cancel());
  }
}
