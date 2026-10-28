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

class ProviderSelection {
  const ProviderSelection({
    required this.index,
    required this.provider,
    required this.result,
  });

  final int index;
  final VideoProvider provider;
  final ProviderLoadResult result;
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
        );
      }
    }
    return null;
  }


  /// Loads every provider concurrently and combines the usable streams.
  ///
  /// This is intended for normal playback: one source's language or quality
  /// catalogue must not hide streams returned by another source. The first
  /// successful provider remains the selection identity for existing player
  /// recovery and provider-switch controls. Each combined quality label
  /// includes its provider name, while the upstream server remains available.
  static Future<ProviderSelection?> loadAllSuccessful({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    ProviderResultCallback? onResult,
    Duration providerTimeout = const Duration(seconds: 25),
  }) async {
    Future<ProviderSelection?> attempt(
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
      if (result.success &&
          result.videoLinks?.any(
                (link) => link.url?.trim().isNotEmpty == true,
              ) ==
              true) {
        return ProviderSelection(
          index: index,
          provider: provider,
          result: result,
        );
      }
      return null;
    }

    // Future.wait preserves input order, while each async attempt starts as
    // soon as it is created. One provider failing does not cancel the others.
    final attempts = await Future.wait<ProviderSelection?>(
      providers.asMap().entries.map(
            (entry) => attempt(entry.key, entry.value),
          ),
    );
    final successful = attempts.whereType<ProviderSelection>().toList();
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
