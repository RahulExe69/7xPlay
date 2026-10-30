import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../video_providers/common.dart';

/// A small local index of manifest language metadata.
///
/// Signed stream URLs often change between visits. The cache fingerprint
/// therefore excludes query parameters and stores only a one-way hash of the
/// stable provider/host/path/quality identity. No stream URL or auth header is
/// written to preferences.
abstract final class ProviderAudioLanguageCache {
  static const _storageKey = '7xplay.provider_audio_languages.v1';
  static const _ttl = Duration(days: 7);
  static const _maximumEntries = 350;

  static Map<String, _CachedLanguages>? _memory;
  static Future<void> _writes = Future<void>.value();

  static Future<Map<String, _CachedLanguages>> _load() async {
    final existing = _memory;
    if (existing != null) return existing;
    final preferences = await SharedPreferences.getInstance();
    Object? decoded;
    try {
      decoded = jsonDecode(preferences.getString(_storageKey) ?? '{}');
    } on FormatException {
      decoded = const <String, Object?>{};
    }
    final result = <String, _CachedLanguages>{};
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final value = Map<String, dynamic>.from(entry.value as Map);
        final cached = _CachedLanguages.fromJson(value);
        if (cached != null &&
            DateTime.now().difference(cached.savedAt) <= _ttl) {
          result[entry.key.toString()] = cached;
        }
      }
    }
    _memory = result;
    return result;
  }

  static Future<Set<String>?> read({
    required String providerCode,
    required RegularVideoLinks link,
  }) async {
    final cache = await _load();
    final fingerprint = _fingerprint(providerCode, link);
    final value = cache[fingerprint];
    if (value == null || value.languages.isEmpty) return null;
    if (DateTime.now().difference(value.savedAt) > _ttl) {
      cache.remove(fingerprint);
      return null;
    }
    return Set<String>.unmodifiable(value.languages);
  }

  static Future<void> invalidate({
    required String providerCode,
    required RegularVideoLinks link,
  }) {
    final fingerprint = _fingerprint(providerCode, link);
    final operation = _writes.then((_) async {
      final cache = await _load();
      if (cache.remove(fingerprint) == null) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode({
          for (final entry in cache.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  static Future<void> write({
    required String providerCode,
    required RegularVideoLinks link,
    required Iterable<String> languages,
  }) {
    final codes = languages
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty && code != 'und')
        .toSet();
    if (codes.isEmpty) return Future<void>.value();

    final fingerprint = _fingerprint(providerCode, link);
    final operation = _writes.then((_) async {
      final cache = await _load();
      cache[fingerprint] = _CachedLanguages(
        savedAt: DateTime.now(),
        languages: codes,
      );
      final now = DateTime.now();
      cache.removeWhere(
        (_, value) => now.difference(value.savedAt) > _ttl,
      );
      if (cache.length > _maximumEntries) {
        final oldestFirst = cache.entries.toList()
          ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));
        for (final entry in oldestFirst.take(cache.length - _maximumEntries)) {
          cache.remove(entry.key);
        }
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode({
          for (final entry in cache.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  static String _fingerprint(String providerCode, RegularVideoLinks link) {
    final uri = Uri.tryParse(link.url?.trim() ?? '');
    final authority = uri == null
        ? ''
        : uri.hasPort
            ? '${uri.host.toLowerCase()}:${uri.port}'
            : uri.host.toLowerCase();
    final stableUrl = uri == null
        ? (link.url?.split('?').first ?? '')
        : '${uri.scheme.toLowerCase()}://$authority${uri.path}';
    final headerNames = link.headers?.keys
            .map((key) => key.toLowerCase())
            .toList()
          ?..sort();
    final identity = [
      providerCode,
      stableUrl,
      link.server?.trim() ?? '',
      link.quality?.trim() ?? '',
      link.isM3U8 == true ? 'hls' : '',
      link.isDash == true ? 'dash' : '',
      headerNames?.join(',') ?? '',
    ].join('|');

    // Deterministic FNV-1a 32-bit hash. The original URL/headers are never
    // stored, while identical signed URLs with rotated query tokens reuse
    // the same language metadata.
    var hash = 0x811c9dc5;
    for (final unit in identity.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _CachedLanguages {
  const _CachedLanguages({required this.savedAt, required this.languages});

  final DateTime savedAt;
  final Set<String> languages;

  Map<String, Object?> toJson() => {
        'savedAt': savedAt.millisecondsSinceEpoch,
        'languages': languages.toList()..sort(),
      };

  static _CachedLanguages? fromJson(Map<String, dynamic> json) {
    final millis = json['savedAt'];
    final rawLanguages = json['languages'];
    if (millis is! num || rawLanguages is! List) return null;
    final languages = rawLanguages
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty && value != 'und')
        .toSet();
    if (languages.isEmpty) return null;
    return _CachedLanguages(
      savedAt: DateTime.fromMillisecondsSinceEpoch(millis.toInt()),
      languages: languages,
    );
  }
}
