import 'dart:collection';

import '../functions/language_names.dart';
import '../services/offline_download_service.dart';
import '../video_providers/common.dart';
import '../video_providers/provider_loader.dart';

class UnifiedPlaybackLanguageOption {
  const UnifiedPlaybackLanguageOption({
    required this.code,
    required this.label,
    required this.providerCodes,
  });

  final String code;
  final String label;
  final List<String> providerCodes;
}

class UnifiedPlaybackLanguageDiscovery {
  const UnifiedPlaybackLanguageDiscovery({
    required this.options,
    required this.providerCodesByLanguage,
    required this.unknownProviderCodes,
  });

  final List<UnifiedPlaybackLanguageOption> options;
  final Map<String, List<String>> providerCodesByLanguage;
  final Map<String, Map<String, List<String>>> sourceKeysByLanguage;
  final List<String> unknownProviderCodes;

  List<String> providerCodesFor(String languageCode) {
    if (languageCode == 'und') return unknownProviderCodes;
    return providerCodesByLanguage[languageCode] ?? const <String>[];
  }

  List<String> sourceKeysFor(String languageCode, String providerCode) =>
      sourceKeysByLanguage[languageCode]?[providerCode] ?? const <String>[];

}

String _sourceIdentity(RegularVideoLinks link) {
  final url = link.url?.trim() ?? '';
  final entries = link.headers?.entries.toList() ?? [];
  entries.sort((a, b) =>
      a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  final headerKey = entries
      .map((entry) => '${entry.key.toLowerCase()}:${entry.value}')
      .join('&');
  return '$url|headers:$headerKey';
}

/// Discovers languages only from provider metadata or parsed HLS/DASH audio
/// tracks. Progressive streams and inaccessible manifests remain unverified.
abstract final class UnifiedPlaybackLanguageService {
  /// Restricts every successful provider result to URLs actually verified for
  /// the selected language. Failed attempts stay intact for diagnostics.
  static List<ProviderAttempt> filterAttemptsForLanguage({
    required List<ProviderAttempt> attempts,
    required UnifiedPlaybackLanguageDiscovery discovery,
    required String languageCode,
  }) {
    return List<ProviderAttempt>.unmodifiable(
      attempts.map((attempt) {
        if (!attempt.hasPlayableSources) return attempt;
        final keys = discovery
            .sourceKeysFor(languageCode, attempt.provider.codeName)
            .toSet();
        if (keys.isEmpty) return attempt;
        final original = attempt.result;
        final links = (original.videoLinks ?? const <RegularVideoLinks>[])
            .where((link) => keys.contains(_sourceIdentity(link)))
            .toList(growable: false);
        if (links.isEmpty) return attempt;
        return ProviderAttempt(
          index: attempt.index,
          provider: attempt.provider,
          result: ProviderLoadResult(
            success: true,
            videoLinks: links,
            subtitleLinks: original.subtitleLinks,
          ),
        );
      }),
    );
  }

  static Future<UnifiedPlaybackLanguageDiscovery> discover(
    List<ProviderAttempt> attempts, {
    int candidatesPerProvider = 3,
    int concurrency = 4,
    Duration probeTimeout = const Duration(seconds: 8),
  }) async {
    final successful = attempts
        .where((attempt) => attempt.hasPlayableSources)
        .toList(growable: false);
    final labelsByProvider = <String, Set<String>>{};
    final sourceKeysByLanguage = <String, Map<String, LinkedHashSet<String>>>{};
    final unknown = <String>{};
    final jobs = <Future<void> Function()>[];

    void record(String providerCode, RegularVideoLinks link, String? code) {
      if (code == null || code == 'und') return;
      labelsByProvider.putIfAbsent(providerCode, () => <String>{}).add(code);
      sourceKeysByLanguage
          .putIfAbsent(code, () => <String, LinkedHashSet<String>>{})
          .putIfAbsent(providerCode, LinkedHashSet<String>.new)
          .add(_sourceIdentity(link));
    }

    for (final attempt in successful) {
      final links = (attempt.result.videoLinks ?? const <RegularVideoLinks>[])
          .where((link) => link.url?.trim().isNotEmpty == true)
          .take(candidatesPerProvider)
          .toList(growable: false);

      for (final link in links) {
        final explicitCode = languageCodeForLabel(link.audioLanguage);
        if (explicitCode != null) {
          record(attempt.provider.codeName, link, explicitCode);
          continue;
        }

        final url = link.url!.trim();
        final lowerUrl = url.toLowerCase();
        final format = link.isDash == true || lowerUrl.contains('.mpd')
            ? 'dash'
            : link.isM3U8 == true || lowerUrl.contains('.m3u8')
                ? 'hls'
                : null;

        // Do not try to parse progressive files as HLS. Their language stays
        // unknown unless the provider explicitly reports it.
        if (format == null) continue;
        final resolvedFormat = format;

        jobs.add(() async {
          final headers = link.headers?.isNotEmpty == true
              ? Map<String, String>.of(link.headers!)
              : const <String, String>{};
          try {
            final tracks = await OfflineDownloadService.instance
                .getAudioTracks(
                  url: url,
                  format: resolvedFormat,
                  headers: headers,
                )
                .timeout(probeTimeout);
            for (final track in tracks) {
              final code = languageCodeForLabel(
                    track.selection['language']?.toString(),
                  ) ??
                  languageCodeForLabel(track.name);
              record(attempt.provider.codeName, link, code);
            }
          } catch (_) {
            // Some providers deny manifest inspection. Their result remains
            // available as Original / unverified, never falsely labelled.
          }
        });
      }
    }

    var cursor = 0;
    final workerCount = concurrency.clamp(1, 8).toInt();
    final workers = List<Future<void>>.generate(
      workerCount,
      (_) async {
        while (cursor < jobs.length) {
          final job = jobs[cursor++];
          await job();
        }
      },
      growable: false,
    );
    await Future.wait(workers);

    for (final attempt in successful) {
      if (labelsByProvider[attempt.provider.codeName]?.isNotEmpty != true) {
        unknown.add(attempt.provider.codeName);
      }
    }

    return fromDetectedLanguages(
      attempts: successful,
      detectedByProvider: labelsByProvider,
      unknownProviderCodes: unknown,
      sourceKeysByLanguage: sourceKeysByLanguage,
    );
  }

  /// Pure catalogue builder used by tests and by deterministic provider data.
  static UnifiedPlaybackLanguageDiscovery fromDetectedLanguages({
    required List<ProviderAttempt> attempts,
    required Map<String, Set<String>> detectedByProvider,
    Set<String> unknownProviderCodes = const <String>{},
    Map<String, Map<String, LinkedHashSet<String>>>? sourceKeysByLanguage,
  }) {
    final providerCodesByLanguage = <String, LinkedHashSet<String>>{};
    for (final attempt in attempts) {
      for (final rawCode
          in detectedByProvider[attempt.provider.codeName] ?? const <String>{}) {
        final code = languageCodeForLabel(rawCode);
        if (code == null) continue;
        providerCodesByLanguage
            .putIfAbsent(code, LinkedHashSet<String>.new)
            .add(attempt.provider.codeName);
      }
    }

    final normalizedSourceKeys = <String, Map<String, LinkedHashSet<String>>>{};
    if (sourceKeysByLanguage != null) {
      for (final entry in sourceKeysByLanguage.entries) {
        normalizedSourceKeys[entry.key] = {
          for (final providerEntry in entry.value.entries)
            providerEntry.key: LinkedHashSet<String>.of(providerEntry.value),
        };
      }
    } else {
      // Unit tests and deterministic metadata can express provider-level
      // language support. In that case every returned link is compatible.
      for (final attempt in attempts) {
        for (final code in detectedByProvider[attempt.provider.codeName] ??
            const <String>{}) {
          final normalizedCode = languageCodeForLabel(code);
          if (normalizedCode == null) continue;
          normalizedSourceKeys
              .putIfAbsent(
                normalizedCode,
                () => <String, LinkedHashSet<String>>{},
              )
              .putIfAbsent(
                attempt.provider.codeName,
                LinkedHashSet<String>.new,
              )
              .addAll(
                (attempt.result.videoLinks ?? const <RegularVideoLinks>[])
                    .where((link) => link.url?.trim().isNotEmpty == true)
                    .map(_sourceIdentity),
              );
        }
      }
    }

    final options = <UnifiedPlaybackLanguageOption>[];
    for (final language in appLanguages) {
      final codes = providerCodesByLanguage[language.code];
      if (codes == null || codes.isEmpty) continue;
      options.add(
        UnifiedPlaybackLanguageOption(
          code: language.code,
          label: languageNameForCode(language.code),
          providerCodes: List<String>.unmodifiable(codes),
        ),
      );
    }

    final successfulCodes =
        attempts.map((attempt) => attempt.provider.codeName).toSet();
    final reportedUnknownCodes = unknownProviderCodes
        .where(successfulCodes.contains)
        .toSet();
    final unverifiedCodes =
        options.isEmpty ? successfulCodes : reportedUnknownCodes;
    if (unverifiedCodes.isNotEmpty) {
      final unverifiedSources = <String, LinkedHashSet<String>>{};
      for (final attempt in attempts) {
        if (!unverifiedCodes.contains(attempt.provider.codeName)) continue;
        unverifiedSources[attempt.provider.codeName] = LinkedHashSet<String>.of(
          (attempt.result.videoLinks ?? const <RegularVideoLinks>[])
              .where((link) => link.url?.trim().isNotEmpty == true)
              .map(_sourceIdentity),
        );
      }
      normalizedSourceKeys['und'] = unverifiedSources;
      options.add(
        UnifiedPlaybackLanguageOption(
          code: 'und',
          label: languageNameForCode('und'),
          providerCodes: List<String>.unmodifiable(unverifiedCodes),
        ),
      );
    }

    return UnifiedPlaybackLanguageDiscovery(
      options: List<UnifiedPlaybackLanguageOption>.unmodifiable(options),
      providerCodesByLanguage: {
        for (final entry in providerCodesByLanguage.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      },
      sourceKeysByLanguage: {
        for (final entry in normalizedSourceKeys.entries)
          entry.key: {
            for (final providerEntry in entry.value.entries)
              providerEntry.key:
                  List<String>.unmodifiable(providerEntry.value),
          },
      },
      unknownProviderCodes: List<String>.unmodifiable(unverifiedCodes),
    );
  }
}
