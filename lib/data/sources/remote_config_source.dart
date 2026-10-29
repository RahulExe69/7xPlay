import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flixquest/data/models/bootstrap_config.dart';

/// Public Supabase configuration. These are client-safe values; never place a
/// service-role/secret key in a mobile app.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://xrupzibcjajgdemseeij.supabase.co',
);
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_h2BES4tDT2c4XNxaWVuhKA_gj41DN9_',
);

abstract interface class RemoteConfigSource {
  Stream<void> get updates;
  Future<BootstrapConfig?> refresh();
}

/// Reads public runtime settings from Supabase's read-only app_config table.
/// If Supabase is offline or the table has not been populated yet, callers
/// retain their cached configuration and the existing Laravel fallback.
class SupabaseRemoteConfigSource implements RemoteConfigSource {
  SupabaseRemoteConfigSource({
    http.Client? client,
    this.refreshInterval = const Duration(minutes: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration refreshInterval;
  Stream<void>? _updates;

  @override
  Stream<void> get updates => _updates ??= Stream<void>.periodic(
        refreshInterval,
        (_) {},
      );

  @override
  Future<BootstrapConfig?> refresh() async {
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/app_config').replace(
        queryParameters: {'select': 'key,value', 'order': 'key.asc'},
      );
      final response = await _client.get(
        uri,
        headers: {
          'apikey': _supabasePublishableKey,
          'Authorization': 'Bearer $_supabasePublishableKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('Supabase app_config returned HTTP ${response.statusCode}');
        }
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;
      final published = <String, dynamic>{};
      for (final row in decoded) {
        if (row is Map && row['key'] is String && row.containsKey('value')) {
          published[row['key'] as String] = row['value'];
        }
      }
      if (published.isEmpty) return null;
      return runtimeConfigSnapshot(published);
    } catch (error) {
      if (kDebugMode) debugPrint('Supabase runtime config unavailable: $error');
      return null;
    }
  }

  void dispose() => _client.close();
}

/// Converts Supabase JSON values into the app's existing bootstrap DTO.
BootstrapConfig runtimeConfigSnapshot(Map<String, dynamic> published) {
  Map<String, dynamic> section(List<String> keys) => {
        for (final key in keys)
          if (published.containsKey(key)) key: published[key],
      };

  return BootstrapConfig.fromJson({
    'config_source': 'supabase',
    'runtime_settings': published,
    'features': section([
      'enable_stream',
      'enable_download',
      'enable_live_tv',
      'enable_ott',
    ]),
    'branding': section(['app_logo_url', 'cinemax_logo']),
    'updates': section([
      'forced_update',
      'latest_version',
      'latest_build_number',
      'min_build_number',
      'app_download_url',
      'change_log',
    ]),
    'network': section([
      'flixquest_api_instances',
      'flixquest_api_url_v2',
      'tmdb_api_key',
      'tmdb_proxy',
    ]),
    'ads': section([
      'banner_ad_network',
      'hosted_banner_mode',
      'unity_game_id_android',
      'unity_banner_placement_id',
      'unity_test_mode',
    ]),
    if (published.containsKey('banners')) 'banners': published['banners'],
    if (published.containsKey('occasional_theme'))
      'occasional_theme': published['occasional_theme'],
  });
}
