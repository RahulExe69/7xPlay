import 'dart:async';

import 'package:flutter/foundation.dart';

import 'common.dart';
import 'names.dart';
import 'scraper_api.dart';
import 'vixsrc.dart';

typedef ProviderLoaderResult = ProviderLoadResult;
typedef ProviderResultCallback = void Function(
  int index,
  VideoProvider provider,
  ProviderLoadResult result,
);

class ProviderAttempt {
  const ProviderAttempt({
    required this.index,
    required this.provider,
    required this.result,
  });

  final int index;
  final VideoProvider provider;
  final ProviderLoadResult result;

  bool get hasPlayableSources =>
      result.success &&
      result.videoLinks?.any((link) => link.url?.trim().isNotEmpty == true) ==
          true;
}

class ProviderSelection {
  const ProviderSelection({
    required this.index,
    required this.provider,
    required this.result,
    this.attempts = const <ProviderAttempt>[],
  });

  final int index;
  final VideoProvider provider;
  final ProviderLoadResult result;
  final List<ProviderAttempt> attempts;
}

/// A provider batch that exposes the first usable result immediately while
/// continuing to collect the full result for diagnostics and audio alternatives.
class ProviderLoadSession {
  const ProviderLoadSession({
    required this.firstPlayable,
    required this.allSuccessful,
  });

  final Future<ProviderAttempt?> firstPlayable;
  final Future<ProviderSelection?> allSuccessful;
}

/// Single loading boundary for direct and API-backed stream providers.
abstract final class ProviderLoader {
  /// Tries providers one at a time in configured order, starting the next only
  /// after the current provider fails or returns no playable links.
  static Future<ProviderSelection?> loadFirstSuccessful({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    ProviderResultCallback? onResult,
  }) async {
    for (var index = 0; index < providers.length; index++) {
      final provider = providers[index];
      ProviderLoadResult result;
      try {
        result = await load(provider);
      } catch (error) {
        result = ProviderLoadResult(errorMessage: error.toString());
      }

      onResult?.call(index, provider, result);
      if (result.success && result.videoLinks?.isNotEmpty == true) {
        return ProviderSelection(
          index: index,
          provider: provider,
          result: result,
          attempts: <ProviderAttempt>[
            ProviderAttempt(index: index, provider: provider, result: result),
          ],
        );
      }
    }
    return null;
  }


  /// Starts all providers concurrently. [firstPlayable] completes as soon
  /// as any provider returns a usable stream; [allSuccessful] completes after
  /// the remaining providers have finished and their results are combined.
  static ProviderLoadSession startLoadingAllSuccessful({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    ProviderResultCallback? onResult,
    Duration providerTimeout = const Duration(seconds: 25),
  }) {
    final firstPlayableCompleter = Completer<ProviderAttempt?>();

    Future<ProviderAttempt> attempt(
      int index,
      VideoProvider provider,
    ) async {
      ProviderLoadResult result;
      try {
        result = await load(provider).timeout(providerTimeout);
      } catch (error) {
        result = ProviderLoadResult(errorMessage: error.toString());
      }

      onResult?.call(index, provider, result);
      final loaded = ProviderAttempt(
        index: index,
        provider: provider,
        result: result,
      );
      if (loaded.hasPlayableSources && !firstPlayableCompleter.isCompleted) {
        firstPlayableCompleter.complete(loaded);
      }
      return loaded;
    }

    final attemptsFuture = Future.wait<ProviderAttempt>(
      providers.asMap().entries.map(
            (entry) => attempt(entry.key, entry.value),
          ),
    );
    final allSuccessful = attemptsFuture.then(_combineSuccessfulAttempts);
    allSuccessful.then(
      (_) {
        if (!firstPlayableCompleter.isCompleted) {
          firstPlayableCompleter.complete(null);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!firstPlayableCompleter.isCompleted) {
          firstPlayableCompleter.completeError(error, stackTrace);
        }
      },
    );

    return ProviderLoadSession(
      firstPlayable: firstPlayableCompleter.future,
      allSuccessful: allSuccessful,
    );
  }

  /// Resolves a first playable source quickly, then expands successful
  /// scraper providers in the background for alternate servers and audio
  /// languages. A failed fast request also gets one full-collection attempt,
  /// but it can never delay an already playable source.
  static ProviderLoadSession startFastThenExpand({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider)
        loadFast,
    required Future<ProviderLoadResult> Function(
      VideoProvider provider,
      ProviderLoadResult fastResult,
    ) loadExpanded,
    ProviderResultCallback? onResult,
    Duration providerTimeout = const Duration(seconds: 12),
    Duration expansionTimeout = const Duration(seconds: 12),
  }) {
    final firstPlayableCompleter = Completer<ProviderAttempt?>();

    Future<ProviderAttempt> runProvider(
      int index,
      VideoProvider provider,
    ) async {
      ProviderLoadResult fastResult;
      try {
        fastResult = await loadFast(provider).timeout(providerTimeout);
      } catch (error) {
        fastResult = ProviderLoadResult(errorMessage: error.toString());
      }

      onResult?.call(index, provider, fastResult);
      final fastAttempt = ProviderAttempt(
        index: index,
        provider: provider,
        result: fastResult,
      );
      if (fastAttempt.hasPlayableSources &&
          !firstPlayableCompleter.isCompleted) {
        firstPlayableCompleter.complete(fastAttempt);
      }

      // Start expansion only after the fast response is known. This means
      // full server collection can add audio variants without holding up the
      // first stream hand-off.
      ProviderLoadResult expandedResult;
      try {
        expandedResult = await loadExpanded(provider, fastResult)
            .timeout(expansionTimeout);
      } catch (error) {
        debugPrint(
          '[ProviderLoader] Background expansion failed '
          'provider=${provider.codeName}: $error',
        );
        return fastAttempt;
      }

      final expandedAttempt = ProviderAttempt(
        index: index,
        provider: provider,
        result: expandedResult,
      );
      if (expandedAttempt.hasPlayableSources) {
        if (!firstPlayableCompleter.isCompleted) {
          firstPlayableCompleter.complete(expandedAttempt);
        }
        return expandedAttempt;
      }
      // Retain the fast source when the optional expansion fails or returns
      // no links. Background work must never discard a working stream.
      return fastAttempt;
    }

    final attemptsFuture = Future.wait<ProviderAttempt>(
      providers.asMap().entries.map(
            (entry) => runProvider(entry.key, entry.value),
          ),
    );
    final allSuccessful = attemptsFuture.then(_combineSuccessfulAttempts);
    allSuccessful.then(
      (_) {
        if (!firstPlayableCompleter.isCompleted) {
          firstPlayableCompleter.complete(null);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!firstPlayableCompleter.isCompleted) {
          firstPlayableCompleter.completeError(error, stackTrace);
        }
      },
    );

    return ProviderLoadSession(
      firstPlayable: firstPlayableCompleter.future,
      allSuccessful: allSuccessful,
    );
  }

  /// Waits for all providers and returns their combined usable streams.
  /// Use [startLoadingAllSuccessful] when the player should start from the
  /// first usable provider without waiting for slower alternatives.
  static Future<ProviderSelection?> loadAllSuccessful({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    ProviderResultCallback? onResult,
    Duration providerTimeout = const Duration(seconds: 25),
  }) {
    return startLoadingAllSuccessful(
      providers: providers,
      load: load,
      onResult: onResult,
      providerTimeout: providerTimeout,
    ).allSuccessful;
  }

  static ProviderSelection? _combineSuccessfulAttempts(
    List<ProviderAttempt> attempts,
  ) {
    final successful = attempts
        .where((attempt) => attempt.hasPlayableSources)
        .toList(growable: false);
    if (successful.isEmpty) return null;

    final links = <RegularVideoLinks>[];
    final seenLinks = <String>{};
    final subtitles = <RegularSubtitleLinks>[];
    final seenSubtitles = <String>{};

    for (final selection in successful) {
      final providerLabel = selection.provider.displayName.trim();
      for (final link in selection.result.videoLinks ?? const []) {
        final url = link.url?.trim();
        if (url == null || url.isEmpty) continue;
        final dedupeKey = _sourceDedupeKey(url, link.headers);
        if (!seenLinks.add(dedupeKey)) continue;

        final rawQuality = link.quality?.trim();
        final quality = rawQuality == null || rawQuality.isEmpty
            ? 'unknown quality'
            : rawQuality;
        final server = link.server?.trim();
        links.add(
          RegularVideoLinks(
            url: url,
            quality: '$quality · $providerLabel',
            server: server == null || server.isEmpty ? null : server,
            isM3U8: link.isM3U8,
            isDash: link.isDash,
            headers: link.headers == null ? null : Map.of(link.headers!),
            sizeToken: link.sizeToken,
            audioLanguage: link.audioLanguage,
            providerCode: selection.provider.codeName,
          ),
        );
      }

      for (final subtitle in selection.result.subtitleLinks ?? const []) {
        final url = subtitle.url?.trim();
        if (url == null || url.isEmpty) continue;
        final language = subtitle.language?.trim() ?? '';
        final dedupeKey =
            '${language.toLowerCase()}|${_sourceDedupeKey(url, subtitle.headers)}';
        if (!seenSubtitles.add(dedupeKey)) continue;
        subtitles.add(
          RegularSubtitleLinks(
            url: url,
            language: language.isEmpty ? providerLabel : language,
            headers:
                subtitle.headers == null ? null : Map.of(subtitle.headers!),
          ),
        );
      }
    }

    if (links.isEmpty) return null;
    final primary = successful.first;
    return ProviderSelection(
      index: primary.index,
      provider: primary.provider,
      result: ProviderLoadResult(
        success: true,
        videoLinks: links,
        subtitleLinks: subtitles,
      ),
      attempts: List<ProviderAttempt>.unmodifiable(attempts),
    );
  }

  /// Returns successful source attempts that are still eligible for a
  /// language-preserving retry, keeping the original provider priority.
  static List<ProviderAttempt> fallbackCandidates({
    required List<ProviderAttempt> attempts,
    required String? failedProviderCode,
    required Iterable<String> eligibleProviderCodes,
    required Set<String> alreadyTriedProviderCodes,
  }) {
    final eligible = eligibleProviderCodes.toSet();
    return List<ProviderAttempt>.unmodifiable(
      attempts.where(
        (attempt) =>
            attempt.hasPlayableSources &&
            attempt.provider.codeName != failedProviderCode &&
            eligible.contains(attempt.provider.codeName) &&
            !alreadyTriedProviderCodes.contains(attempt.provider.codeName),
      ),
    );
  }

  static String _sourceDedupeKey(
    String url,
    Map<String, String>? headers,
  ) {
    // URL fragments are client-side only; they should not turn the same
    // network stream into multiple source choices.
    final normalized = url.trim().split('#').first;
    final headerEntries = headers?.entries.toList() ?? [];
    headerEntries.sort(
      (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
    );
    final headerKey = headerEntries
        .map((entry) => '${entry.key.toLowerCase()}:${entry.value}')
        .join('&');
    return '$normalized|headers:$headerKey';
  }

  static Future<ProviderLoaderResult> loadMovieFromProvider({
    required VideoProvider provider,
    required int movieId,
    required String scraperApiUrl,
    bool full = false,
  }) {
    switch (provider.type) {
      case VideoProviderType.directVixSrc:
        return VixSrc.loadMovie(movieId);
      case VideoProviderType.scraperApi:
        final providerId = provider.apiId;
        if (providerId == null || providerId.isEmpty) {
          return Future.value(
            const ProviderLoadResult(errorMessage: 'Provider ID is missing'),
          );
        }
        return ScraperApi(scraperApiUrl).loadMovie(
          providerId: providerId,
          movieId: movieId,
          full: full,
        );
    }
  }

  static Future<ProviderLoaderResult> loadTVFromProvider({
    required VideoProvider provider,
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
    required String scraperApiUrl,
    bool full = false,
  }) {
    switch (provider.type) {
      case VideoProviderType.directVixSrc:
        return VixSrc.loadEpisode(
          tvId: tvId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        );
      case VideoProviderType.scraperApi:
        final providerId = provider.apiId;
        if (providerId == null || providerId.isEmpty) {
          return Future.value(
            const ProviderLoadResult(errorMessage: 'Provider ID is missing'),
          );
        }
        return ScraperApi(scraperApiUrl).loadTVEpisode(
          providerId: providerId,
          tvId: tvId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          full: full,
        );
    }
  }
}
