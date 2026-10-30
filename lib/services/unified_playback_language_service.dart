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
    required this.sourceKeysByLanguage,
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

  /// Returns the detected language for one exact provider link.
  /// URL and headers are part of its identity so two differently protected
  /// streams are never accidentally treated as the same source.
  String? languageCodeForLink(
    RegularVideoLinks link,
    String providerCode,
  ) {
    final key = _sourceIdentity(link);
    for (final entry in sourceKeysByLanguage.entries) {
      if (entry.key == 'und') continue;
      if (entry.value[providerCode]?.contains(key) == true) {
        return entry.key;
      }
    }
    return null;
  }

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

  /// Identifies manifest formats conservatively. Explicit progressive file
  /// extensions override provider flags, because providers occasionally mark
  /// an MP4/WebM URL as HLS by mistake.
  static String? manifestFormatForLink(RegularVideoLinks link) {
    final rawUrl = link.url?.trim() ?? '';
    if (rawUrl.isEmpty) return null;
    final parsed = Uri.tryParse(rawUrl);
    final path = (parsed?.path.isNotEmpty == true
            ? parsed!.path
            : rawUrl.split('?').first)
        .toLowerCase();

    const progressiveExtensions = <String>[
      '.mp4',
      '.m4v',
      '.mov',
      '.webm',
      '.mkv',
      '.avi',
      '.mpg',
      '.mpeg',
      '.flv',
      '.wmv',
    ];
    if (progressiveExtensions.any(path.endsWith)) return null;
    if (path.endsWith('.mpd')) return 'dash';
    if (path.endsWith('.m3u8')) return 'hls';

    // Extension-less signed endpoints still rely on provider metadata.
    if (link.isDash == true) return 'dash';
    if (link.isM3U8 == true) return 'hls';
    return null;
  }

  static bool allowsProviderForSelectedLanguage({
    required String? selectedLanguageCode,
    required Iterable<String> eligibleProviderCodes,
    required String providerCode,
  }) {
    // No language selection is used by legacy entry points and downloads.
    if (selectedLanguageCode == null) return true;
    // This also constrains the explicit "Original / unverified" option to
    // providers which actually supplied an unverified source.
    return eligibleProviderCodes.contains(providerCode);
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
    final unverifiedSourcesByProvider =
        <String, LinkedHashSet<String>>{};
    final jobs = <Future<void> Function()>[];

    void record(String providerCode, RegularVideoLinks link, String? code) {
      if (code == null || code == 'und') return;
      labelsByProvider.putIfAbsent(providerCode, () => <String>{}).add(code);
      sourceKeysByLanguage
          .putIfAbsent(code, () => <String, LinkedHashSet<String>>{})
          .putIfAbsent(providerCode, LinkedHashSet<String>.new)
          .add(_sourceIdentity(link));
    }

    void recordUnverified(String providerCode, RegularVideoLinks link) {
      unverifiedSourcesByProvider
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
        final format = manifestFormatForLink(link);

        // Progressive files and unrecognised formats are never sent to
        // the HLS/DASH parser. Keep this individual source available as
        // Original / unverified, even when another link from the same
        // provider has a verified language.
        if (format == null) {
          recordUnverified(attempt.provider.codeName, link);
          continue;
        }
        final resolvedFormat = format;

        jobs.add(() async {
          final headers = link.headers?.isNotEmpty == true
              ? Map<String, String>.of(link.headers!)
              : const <String, String>{};
          var foundLanguage = false;
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
              if (code != null) {
                foundLanguage = true;
                record(attempt.provider.codeName, link, code);
              }
            }
            if (!foundLanguage) {
              recordUnverified(attempt.provider.codeName, link);
            }
          } catch (_) {
            // Some providers deny manifest inspection. Their individual
            // source remains available as Original / unverified.
            recordUnverified(attempt.provider.codeName, link);
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

    final unknownSources = <String, Map<String, LinkedHashSet<String>>>{
      if (unverifiedSourcesByProvider.isNotEmpty)
        'und': unverifiedSourcesByProvider,
    };

    return fromDetectedLanguages(
      attempts: successful,
      detectedByProvider: labelsByProvider,
      unknownProviderCodes: unverifiedSourcesByProvider.keys.toSet(),
      sourceKeysByLanguage: {
        ...sourceKeysByLanguage,
        ...unknownSources,
      },
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
    final unverifiedSourceMap = normalizedSourceKeys['und'];
    final unverifiedCodes = unverifiedSourceMap?.keys.toSet() ??
        (options.isEmpty ? successfulCodes : reportedUnknownCodes);
    if (unverifiedCodes.isNotEmpty) {
      // When discovery supplied per-source identities, preserve those exact
      // links. The legacy pure builder still supports provider-level unknowns.
      if (unverifiedSourceMap == null) {
        final unverifiedSources = <String, LinkedHashSet<String>>{};
        for (final attempt in attempts) {
          if (!unverifiedCodes.contains(attempt.provider.codeName)) continue;
          unverifiedSources[attempt.provider.codeName] =
              LinkedHashSet<String>.of(
            (attempt.result.videoLinks ?? const <RegularVideoLinks>[])
                .where((link) => link.url?.trim().isNotEmpty == true)
                .map(_sourceIdentity),
          );
        }
        normalizedSourceKeys['und'] = unverifiedSources;
      }
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
