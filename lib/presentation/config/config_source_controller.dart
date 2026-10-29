import 'dart:async';

import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/models/bootstrap_config.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/data/sources/remote_config_source.dart';

import 'bootstrap_view_model.dart';
import 'refresh_controller.dart';

/// Supabase runtime configuration is the primary source; Laravel's `config_source`
/// only overrides it with an explicit `laravel`. The override is revalidated
/// independently of a slow Firebase fetch, so switching to Laravel never waits
/// for the old provider to finish, and a slow Laravel never holds Firebase back.
class ConfigSourceController implements ConfigLifecycle {
  ConfigSourceController(
      this.repository, this.viewModel, this.store, this.remoteConfig,
      {this.selectorTimeout = const Duration(seconds: 6)});
  final ConfigRepository repository;
  final BootstrapViewModel viewModel;
  final KvStore store;
  final RemoteConfigSource remoteConfig;

  /// How long a refresh waits on Laravel before keeping the cached choice. A
  /// late answer is still persisted and applies on the next refresh.
  final Duration selectorTimeout;

  static const _remoteConfigCacheKey = 'config.supabase.snapshot';
  BootstrapConfig? _remoteConfigSnapshot;
  StreamSubscription<void>? _subscription;
  Future<(BootstrapConfig, int)>? _validation;
  Future<void>? _sourceWork;
  int _generation = 0;
  int _workGeneration = -1;
  bool _hintPending = false;
  bool _disposed = false;

  void _listen() {
    if (_disposed || _subscription != null) return;
    try {
      _subscription = remoteConfig.updates.listen((_) {
        unawaited(onPushData({'type': 'config_updated'}));
      }, onError: (_) {});
    } catch (_) {
      // Laravel config remains available on platforms without realtime config.
    }
  }

  BootstrapConfig? _cachedRemoteConfig() {
    if (_remoteConfigSnapshot != null) return _remoteConfigSnapshot;
    final raw = store.getJson(_remoteConfigCacheKey);
    if (raw is! Map<String, dynamic> || raw['config_source'] != 'supabase') {
      return null;
    }
    try {
      return _remoteConfigSnapshot = BootstrapConfig.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  void _apply(BootstrapConfig config) =>
      viewModel.apply(config, preserveThemeSelection: true);

  Future<void> hydrate() async {
    final config = await repository.loadCached(requireSource: true);
    if (_disposed) return;
    _apply(config.configSource == 'laravel'
        ? config
        : _cachedRemoteConfig() ?? const BootstrapConfig());
    _listen();
  }

  Future<void> refresh() => _refresh();

  @override
  Future<void> boot() => _refresh();
  @override
  Future<void> onResume() => _refresh();
  @override
  Future<void> onPushData(Map<String, dynamic> data) {
    final hint = data['refresh_config'];
    if (!{'config_updated', 'config_refresh'}.contains(data['type']) &&
        hint != true &&
        hint != 'true' &&
        hint != '1') {
      return Future.value();
    }
    if (_validation != null) _hintPending = true;
    return _refresh();
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    _listen();
    final (config, generation) = await (_validation ??= _validate());
    if (_disposed || generation != _generation) return;
    if (_workGeneration != generation) {
      _workGeneration = generation;
      _sourceWork = _applySelection(config, generation);
    }
    await _sourceWork;
  }

  Future<(BootstrapConfig, int)> _validate() async {
    final generation = ++_generation;
    try {
      BootstrapConfig config;
      do {
        _hintPending = false;
        config = await repository
            .refresh(requireSource: true, persistLegacy: false)
            .timeout(selectorTimeout,
                onTimeout: () => repository.loadCached(requireSource: true));
      } while (_hintPending && !_disposed);
      return (config, generation);
    } finally {
      // Only the HTTP decision is coalesced; a slow previous remote config fetch
      // must not block a subsequent resume or operator-directed source switch.
      _validation = null;
    }
  }

  Future<void> _applySelection(BootstrapConfig config, int generation) async {
    bool current() => !_disposed && generation == _generation;
    if (!current()) return;
    if (config.configSource == 'laravel') {
      _apply(config);
      return;
    }
    // Supabase also serves before Laravel has ever answered.
    // Apply only the selected provider's cache while fetching fresh settings.
    _apply(_cachedRemoteConfig() ?? const BootstrapConfig());
    BootstrapConfig? fresh;
    try {
      fresh = await remoteConfig.refresh();
    } catch (_) {
      return;
    }
    if (!current() || fresh == null) return;
    fresh = fresh.copyWith(configSource: 'supabase');
    _remoteConfigSnapshot = fresh;
    try {
      await store.setJson(_remoteConfigCacheKey, fresh.toJson());
    } catch (_) {
      // The live snapshot can still be used if preference persistence fails.
    }
    if (current()) _apply(fresh);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    viewModel.dispose();
  }
}
