import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flixquest/core/config/app_environment.dart';

const _supabaseConfigUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://xrupzibcjajgdemseeij.supabase.co',
);
const _supabaseConfigKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_h2BES4tDT2c4XNxaWVuhKA_gj41DN9_',
);

/// Discovers the Laravel API endpoint from the public Supabase app_config
/// table. The bundled URL remains the safe fallback when Supabase is offline.
class SupabaseBackendConfigController {
  SupabaseBackendConfigController({
    required String fallbackUrl,
    required this.onUrlChanged,
    Stream<bool>? connectivityChanges,
    http.Client? client,
    this.refreshInterval = const Duration(minutes: 15),
  })  : _fallbackUrl = AppEnvironment.normalizeLaravelApiUrl(fallbackUrl),
        _connectivityChanges = connectivityChanges,
        _client = client ?? http.Client() {
    _lastAppliedUrl = _fallbackUrl;
  }

  final String _fallbackUrl;
  final void Function(String) onUrlChanged;
  final Stream<bool>? _connectivityChanges;
  final http.Client _client;
  final Duration refreshInterval;
  late String _lastAppliedUrl;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _timer;
  Future<void>? _starting;
  bool _disposed = false;

  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    if (_disposed) return;
    final connectivity = Connectivity();
    _connectivitySubscription = (_connectivityChanges ??
            connectivity.onConnectivityChanged.map(
              (results) => results.any((r) => r != ConnectivityResult.none),
            ))
        .listen((online) {
      if (online) unawaited(refresh());
    }, onError: (_) {});
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    try {
      final uri = Uri.parse('$_supabaseConfigUrl/rest/v1/app_config').replace(
        queryParameters: {
          'select': 'key,value',
          'key': 'eq.laravel_api_url',
          'limit': '1',
        },
      );
      final response = await _client.get(uri, headers: {
        'apikey': _supabaseConfigKey,
        'Authorization': 'Bearer $_supabaseConfigKey',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty || decoded.first is! Map) return;
      final rawValue = (decoded.first as Map)['value'];
      final raw = rawValue is String
          ? rawValue.trim()
          : rawValue == null
              ? ''
              : rawValue.toString().trim();
      if (raw.isEmpty) return;
      final url = AppEnvironment.normalizeLaravelApiUrl(raw);
      if (_disposed || url == _lastAppliedUrl) return;
      onUrlChanged(url);
      _lastAppliedUrl = url;
    } catch (error) {
      if (kDebugMode) debugPrint('Supabase backend config unavailable: $error');
      // Keep the last known-good endpoint when the network/config is unavailable.
    }
  }

  Future<void> resume() => refresh();

  void pause() {}

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    _client.close();
  }
}
