import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/services/app_remote_config.dart';
import 'package:flixquest/services/remote_config_refresh_controller.dart';

/// Backend discovery must work even when Laravel serves feature configuration
/// or its bundled address is unreachable. Startup always uses the bundled URL;
/// Firebase can replace it asynchronously for subsequent requests.
class FirebaseBackendConfigController {
  FirebaseBackendConfigController({
    required String fallbackUrl,
    required this.onUrlChanged,
    FirebaseRemoteConfig? remote,
    Stream<bool>? connectivityChanges,
    Future<bool> Function()? checkConnectivity,
  })  : _fallbackUrl = AppEnvironment.normalizeLaravelApiUrl(fallbackUrl),
        _remote = remote ?? FirebaseRemoteConfig.instance,
        _connectivityChanges = connectivityChanges,
        _checkConnectivity = checkConnectivity {
    _lastAppliedUrl = _fallbackUrl;
  }

  final String _fallbackUrl;
  final void Function(String) onUrlChanged;
  final FirebaseRemoteConfig _remote;
  final Stream<bool>? _connectivityChanges;
  final Future<bool> Function()? _checkConnectivity;
  late String _lastAppliedUrl;
  Future<void>? _starting;
  RemoteConfigRefreshController? _refresh;
  StreamSubscription<RemoteConfigUpdate>? _subscription;
  bool _disposed = false;
  bool _active = true;

  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    if (_disposed) return;
    final connectivity = Connectivity();
    _refresh = RemoteConfigRefreshController(
      fetch: _fetch,
      lastFetchTime: () => _remote.lastFetchTime,
      connectivityChanges: _connectivityChanges ??
          connectivity.onConnectivityChanged.map(
              (results) => results.any((r) => r != ConnectivityResult.none)),
      checkConnectivity: _checkConnectivity ??
          () async => (await connectivity.checkConnectivity())
              .any((r) => r != ConnectivityResult.none),
    );
    if (!_active) _refresh!.pause();
    try {
      _subscription = _remote.onConfigUpdated.listen((_) async {
        try {
          await _remote.activate();
          _apply();
        } catch (_) {/* Keep the current endpoint if activation fails. */}
      }, onError: (_) {});
    } catch (_) {/* Fetch/resume still work without realtime support. */}
    await _refresh!.refresh();
  }

  Future<bool> _fetch() async {
    try {
      await AppRemoteConfig.configure(_remote);
      await _remote.ensureInitialized();
      if (_disposed) return false;
      await _remote.activate();
      _apply();
      await _remote.fetchAndActivate();
      _apply();
      return _remote.lastFetchStatus == RemoteConfigFetchStatus.success;
    } catch (_) {
      // An offline fetch retains either the bundled URL or the activated cache.
      return false;
    }
  }

  void _apply() {
    if (_disposed) return;
    final value = _remote.getValue(AppRemoteConfig.laravelApiUrlKey);
    final raw =
        value.source == ValueSource.valueRemote ? value.asString().trim() : '';
    String url;
    try {
      url = raw.isEmpty
          ? _fallbackUrl
          : AppEnvironment.normalizeLaravelApiUrl(raw);
    } on ArgumentError {
      return; // A malformed publish must not break a working backend.
    } on FormatException {
      return;
    }
    if (url == _lastAppliedUrl) return;
    onUrlChanged(url);
    _lastAppliedUrl = url;
  }

  Future<void> refresh() async => _refresh?.refresh();

  Future<void> resume() async {
    _active = true;
    await _refresh?.resume();
  }

  void pause() {
    _active = false;
    _refresh?.pause();
  }

  void dispose() {
    _disposed = true;
    _refresh?.dispose();
    unawaited(_subscription?.cancel());
  }
}
