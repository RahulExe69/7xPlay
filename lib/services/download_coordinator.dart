import 'dart:async';

import '../functions/language_names.dart';
import '../models/offline_download.dart';
import '../video_providers/common.dart';
import '../video_providers/names.dart';
import '../video_providers/provider_loader.dart';
import 'offline_download_service.dart';
import 'unified_playback_language_service.dart';

class DownloadCandidate {
  const DownloadCandidate({
    required this.provider,
    required this.link,
    required this.languageCode,
    required this.quality,
    required this.format,
    required this.providerIndex,
    required this.linkIndex,
    this.estimatedBytes,
    this.audioTrack,
    this.source,
  });

  final VideoProvider provider;
  final RegularVideoLinks link;
  final String languageCode;
  final String quality;
  final String format;
  final int providerIndex;
  final int linkIndex;
  final int? estimatedBytes;
  final OfflineAudioTrack? audioTrack;
  final OfflineDownloadSource? source;

  String get url => link.url!.trim();
  Map<String, String> get headers =>
      Map<String, String>.unmodifiable(link.headers ?? const {});
  String get sourceIdentity =>
      UnifiedPlaybackLanguageService.sourceIdentityForLink(link);
  String get formatIdentity => quality.trim().toLowerCase();

  /// Distinguishes provider-specific size tokens even when providers expose
  /// the same CDN URL and headers.
  String get estimateKey =>
      '${provider.codeName}|$formatIdentity|$sourceIdentity';

  DownloadCandidate copyWith({
    int? estimatedBytes,
    OfflineAudioTrack? audioTrack,
  }) {
    return DownloadCandidate(
      provider: provider,
      link: link,
      languageCode: languageCode,
      quality: quality,
      format: format,
      providerIndex: providerIndex,
      linkIndex: linkIndex,
      estimatedBytes: estimatedBytes ?? this.estimatedBytes,
      audioTrack: audioTrack ?? this.audioTrack,
      source: source,
    );
  }

  Map<String, Object?> toFallbackMap() => {
        'providerName': provider.displayName,
        'url': url,
        'format': format,
        'quality': quality,
        'headers': headers,
        if (audioTrack != null) 'audioTrack': audioTrack!.selection,
        if (audioTrack != null) 'audioTrackName': audioTrack!.name,
        if (source != null) 'source': source!.toMap(),
      };
}

class DownloadFormatOption {
  const DownloadFormatOption({
    required this.key,
    required this.label,
    required this.candidates,
    required this.deliveryTypes,
  });

  final String key;
  final String label;
  final List<DownloadCandidate> candidates;
  final List<String> deliveryTypes;

  int? get smallestSizeBytes =>
      candidates.firstWhere(
        (candidate) => candidate.estimatedBytes != null,
        orElse: () => candidates.first,
      ).estimatedBytes;

  int get sourceCount => candidates.length;

  String get deliveryDescription => deliveryTypes
      .map((format) => switch (format) {
            'hls' => 'HLS',
            'dash' => 'DASH',
            'progressive' => 'MP4',
            _ => format.toUpperCase(),
          })
      .join(' · ');
}

/// Provider discovery, language matching, format grouping and source ranking.
abstract final class DownloadCoordinator {
  static const int defaultConcurrency = 4;
  static const Duration defaultProviderTimeout = Duration(seconds: 25);
  static const Duration audioInspectionTimeout = Duration(seconds: 9);

  static Future<List<ProviderAttempt>> loadProviders({
    required Iterable<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    int concurrency = defaultConcurrency,
    Duration timeout = defaultProviderTimeout,
  }) async {
    final unique = <VideoProvider>[];
    final seen = <String>{};
    for (final provider in providers) {
      if (seen.add(provider.codeName)) unique.add(provider);
    }
    if (unique.isEmpty) return const [];

    final results = List<ProviderAttempt?>.filled(unique.length, null);
    var cursor = 0;
    final workerCount = concurrency.clamp(1, unique.length).toInt();

    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= unique.length) return;
        final provider = unique[index];
        ProviderLoadResult result;
        try {
          result = await load(provider).timeout(timeout);
        } catch (error) {
          result = ProviderLoadResult(errorMessage: error.toString());
        }
        results[index] = ProviderAttempt(
          index: index,
          provider: provider,
          result: result,
        );
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return List<ProviderAttempt>.unmodifiable(
      results.whereType<ProviderAttempt>(),
    );
  }

  static List<DownloadCandidate> candidatesForLanguage({
    required List<ProviderAttempt> attempts,
    required UnifiedPlaybackLanguageDiscovery discovery,
    required String languageCode,
    required String scraperApiUrl,
    Map<String, int?> estimatedSizes = const {},
  }) {
    final deduplicated = <String, DownloadCandidate>{};
    for (final attempt in attempts) {
      if (!attempt.hasPlayableSources) continue;
      final providerCode = attempt.provider.codeName;
      final allowed =
          discovery.sourceKeysFor(languageCode, providerCode).toSet();
      if (allowed.isEmpty) continue;

      final links = attempt.result.videoLinks ?? const <RegularVideoLinks>[];
      for (var index = 0; index < links.length; index++) {
        final link = links[index];
        final url = link.url?.trim() ?? '';
        final identity =
            UnifiedPlaybackLanguageService.sourceIdentityForLink(link);
        if (url.isEmpty || !allowed.contains(identity)) continue;
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !const {'http', 'https'}.contains(uri.scheme) ||
            uri.host.isEmpty) {
          continue;
        }

        final quality = normalizeQuality(link.quality);
        final format = OfflineDownloadService.inferFormat(
          url: url,
          isHls: link.isM3U8 == true,
          isDash: link.isDash == true,
        );
        final source = OfflineDownloadSource.forSelection(
          provider: attempt.provider,
          apiBaseUrl: scraperApiUrl,
          links: [link],
          url: url,
          headers: link.headers,
        );
        final candidate = DownloadCandidate(
          provider: attempt.provider,
          link: link,
          languageCode: languageCode,
          quality: quality,
          format: format,
          providerIndex: attempt.index,
          linkIndex: index,
          estimatedBytes: estimatedSizes[identity],
          source: source,
        );

        final key =
            '${providerCode}|${candidate.formatIdentity}|${candidate.sourceIdentity}';
        final previous = deduplicated[key];
        if (previous == null ||
            (candidate.estimatedBytes != null &&
                (previous.estimatedBytes == null ||
                    candidate.estimatedBytes! < previous.estimatedBytes!))) {
          deduplicated[key] = candidate;
        }
      }
    }
    final candidates = deduplicated.values.toList()..sort(compareCandidates);
    return List<DownloadCandidate>.unmodifiable(candidates);
  }

  static Future<List<DownloadCandidate>> inspectAudioTracks({
    required List<DownloadCandidate> candidates,
    required String languageCode,
    required Future<List<OfflineAudioTrack>> Function(
      DownloadCandidate candidate,
    ) inspect,
    Map<String, List<OfflineAudioTrack>> cachedTracks = const {},
    int concurrency = defaultConcurrency,
    Duration timeout = audioInspectionTimeout,
  }) async {
    if (candidates.isEmpty) return const [];
    final results = List<DownloadCandidate?>.filled(candidates.length, null);
    var cursor = 0;
    final workerCount = concurrency.clamp(1, candidates.length).toInt();

    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= candidates.length) return;
        final candidate = candidates[index];
        final declaredLanguage =
            languageCodeForLabel(candidate.link.audioLanguage);

        if (languageCode == 'und') {
          results[index] = candidate;
          continue;
        }
        if (candidate.format == 'progressive') {
          if (declaredLanguage == languageCode) results[index] = candidate;
          continue;
        }

        try {
          final cached = cachedTracks[candidate.sourceIdentity];
          final tracks = cached ??
              await inspect(candidate).timeout(timeout);
          if (tracks.isEmpty) continue;
          OfflineAudioTrack? selected;
          for (final track in tracks) {
            final code = languageCodeForLabel(
                  track.selection['language']?.toString(),
                ) ??
                languageCodeForLabel(track.name);
            if (code == languageCode) {
              selected = track;
              break;
            }
          }
          if (selected != null) {
            results[index] = candidate.copyWith(audioTrack: selected);
          }
        } catch (_) {
          // No safe audio-track identity was obtained; omit this candidate.
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    final ready = results.whereType<DownloadCandidate>().toList()
      ..sort(compareCandidates);
    return List<DownloadCandidate>.unmodifiable(ready);
  }

  static List<DownloadFormatOption> buildFormats(
    Iterable<DownloadCandidate> candidates,
  ) {
    final grouped = <String, List<DownloadCandidate>>{};
    for (final candidate in candidates) {
      grouped
          .putIfAbsent(candidate.formatIdentity, () => <DownloadCandidate>[])
          .add(candidate);
    }

    final options = grouped.entries.map((entry) {
      final sources = List<DownloadCandidate>.of(entry.value)
        ..sort(compareCandidates);
      final deliveryTypes = sources.map((item) => item.format).toSet().toList()
        ..sort();
      return DownloadFormatOption(
        key: entry.key,
        label: sources.first.quality,
        candidates: List<DownloadCandidate>.unmodifiable(sources),
        deliveryTypes: List<String>.unmodifiable(deliveryTypes),
      );
    }).toList();

    options.sort((left, right) {
      final leftHeight = resolutionHeight(left.label);
      final rightHeight = resolutionHeight(right.label);
      if (leftHeight != rightHeight) return rightHeight.compareTo(leftHeight);
      return left.label.toLowerCase().compareTo(right.label.toLowerCase());
    });
    return List<DownloadFormatOption>.unmodifiable(options);
  }

  static String normalizeQuality(String? value) {
    final normalized = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    return normalized.isEmpty ? 'Unknown quality' : normalized;
  }

  static int resolutionHeight(String quality) {
    final match = RegExp(r'(\d{3,4})').firstMatch(quality);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static int compareCandidates(
    DownloadCandidate left,
    DownloadCandidate right,
  ) {
    final leftSize = left.estimatedBytes;
    final rightSize = right.estimatedBytes;
    if (leftSize != null && rightSize != null && leftSize != rightSize) {
      return leftSize.compareTo(rightSize);
    }
    if (leftSize != null && rightSize == null) return -1;
    if (leftSize == null && rightSize != null) return 1;
    final providerOrder = left.providerIndex.compareTo(right.providerIndex);
    if (providerOrder != 0) return providerOrder;
    return left.linkIndex.compareTo(right.linkIndex);
  }
}
