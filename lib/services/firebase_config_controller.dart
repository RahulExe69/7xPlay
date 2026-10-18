import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/app_remote_config.dart';
import 'package:flixquest/services/remote_config_refresh_controller.dart';

/// Firebase-only rollback path while FLIXQUEST_MIGRATION omits `config`.
/// Laravel-selected config has its own lifecycle and never races this writer.
class FirebaseConfigController {
  FirebaseConfigController(this.dependencies);
  final AppDependencyProvider dependencies;
  final FirebaseRemoteConfig _remote = FirebaseRemoteConfig.instance;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<RemoteConfigUpdate>? _subscription;
  RemoteConfigRefreshController? _refresh;
  bool _disposed = false;
  bool _active = true;

  Future<void> start() async {
    _refresh = RemoteConfigRefreshController(
      fetch: _fetch,
      lastFetchTime: () => _remote.lastFetchTime,
      connectivityChanges: _connectivity.onConnectivityChanged
          .map((results) => results.any((r) => r != ConnectivityResult.none)),
      checkConnectivity: () async => (await _connectivity.checkConnectivity())
          .any((r) => r != ConnectivityResult.none),
    );
    if (!_active) _refresh!.pause();
    await _refresh!.refresh();
    if (_disposed) return;
    _subscription = _remote.onConfigUpdated.listen((_) async {
      try {
        await _remote.activate();
        if (!_disposed) AppRemoteConfig.apply(_remote, dependencies);
      } catch (_) {/* Retain the last activated configuration. */}
    }, onError: (_) {});
  }

  Future<bool> _fetch() async {
    try {
      await AppRemoteConfig.configure(_remote);
      await _remote.ensureInitialized();
      if (_disposed) return false;
      // Apply activated values before a slow/offline fetch completes.
      AppRemoteConfig.apply(_remote, dependencies);
      await _remote.fetchAndActivate();
      if (!_disposed) AppRemoteConfig.apply(_remote, dependencies);
      return _remote.lastFetchStatus == RemoteConfigFetchStatus.success;
    } catch (error) {
      if (kDebugMode) debugPrint('[RemoteConfig] fetch failed: $error');
      return false;
    }
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
