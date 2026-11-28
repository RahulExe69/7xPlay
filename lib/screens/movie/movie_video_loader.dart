import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/data/ads/content_ads.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flixquest/functions/function.dart';
import 'package:flixquest/functions/network.dart';
import 'package:flixquest/functions/video_utils.dart';
import 'package:flixquest/functions/player_route_handoff.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/catalog/hindi_origin_movie_recommendations.dart';
import 'package:flixquest/models/movie_stream_metadata.dart';
import 'package:flixquest/models/provider_video_source.dart';
import 'package:flixquest/models/provider_load_state.dart';
import 'package:flixquest/services/globle_method.dart';
import 'package:flixquest/widgets/playback_loading_screen.dart';
import 'package:flixquest/services/unified_download_workflow.dart';
import 'package:flixquest/video_providers/provider_loader.dart';
import 'package:flixquest/video_providers/scraper_api.dart';
import '../../controllers/recently_watched_database_controller.dart';
import '../../provider/recently_watched_provider.dart';
import '../../video_providers/common.dart';
import '../../video_providers/names.dart';
import '/api/endpoints.dart';
import '/constants/api_constants.dart';
import '/provider/app_dependency_provider.dart';
import '/provider/settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player.dart';
import '../../widgets/common_widgets.dart';
import 'package:flixquest/constants/app_constants.dart' show MediaType;

import 'package:flutter/material.dart';
import '../../screens/common/player.dart';
import '../../tv/player/tv_player_screen.dart';

/// Finds a movie stream and keeps the complete playback route ad-free.
class MovieVideoLoader extends StatelessWidget {
  const MovieVideoLoader(
      {required this.metadata,
      required this.download,
      this.useTvPlayer = false,
      this.onTvPlayerExit,
      this.adStage = PlaybackAdStage.streamFound,
      super.key});

  final MovieStreamMetadata metadata;
  final bool download;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;
  final PlaybackAdStage adStage;

  @override
  Widget build(BuildContext context) {
    final loader = _MovieVideoLoader(
        metadata: metadata,
        download: download,
        useTvPlayer: useTvPlayer,
        onTvPlayerExit: onTvPlayerExit,
        adStage: adStage);
    // Playback is intentionally ad-free. Keep the scope attached when the
    // loader hands off to the player, without waiting for an ad-classification
    // request or opening an interstitial over the Watch action.
    return ContentAdScope(adFree: true, child: loader);
  }
}

class _MovieVideoLoader extends StatefulWidget {
  const _MovieVideoLoader(
      {required this.download,
      required this.metadata,
      this.useTvPlayer = false,
      this.onTvPlayerExit,
      this.adStage = PlaybackAdStage.streamFound});

  final bool download;
  final MovieStreamMetadata metadata;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;

  /// Retained for the existing in-player reload call sites. Playback ads
  /// are disabled, so this value no longer changes the loading experience.
  final PlaybackAdStage adStage;

  @override
  State<_MovieVideoLoader> createState() => _MovieVideoLoaderState();
}

class _MovieVideoLoaderState extends State<_MovieVideoLoader> {
  RecentlyWatchedMoviesController recentlyWatchedMoviesController =
      RecentlyWatchedMoviesController();

  List<RegularVideoLinks>? movieVideoLinks;
  List<RegularSubtitleLinks>? movieVideoSubs;

  late SettingsProvider settings =
      Provider.of<SettingsProvider>(context, listen: false);
  List<VideoProvider> videoProviders = [];
  List<ProviderLoadState> providerStates = [];
  final Map<String, Stopwatch> _providerStopwatches = {};
  int currentProviderIndex = 0;
  String _scraperApiUrl = '';

  Map<String, String> videos = {};
  List<BetterPlayerSubtitlesSource> subs = [];

  // Collect all working providers
  List<ProviderVideoSource> availableProviders = [];

  late int foundIndex;

  /// The metadata this loader was built for, captured once. Route builders run
  /// again whenever route dependencies change, and callers construct a fresh
  /// [MovieStreamMetadata] inside them; swapping to that empty copy mid-flight
  /// would drop the fetched recommendations the player needs.
  late final MovieStreamMetadata _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = widget.metadata;
    debugPrint(
      '[MovieRecommendationsDebug][LOADER_INIT] '
      'movieId=${_metadata.movieId} '
      'title=${_metadata.movieName} '
      'existingRecommendations=${_metadata.recommendations?.length ?? 0} '
      'download=${widget.download} useTvPlayer=${widget.useTvPlayer}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPlayback());
  }

  Future<void> _startPlayback() async {
    if (!mounted) return;
    // Resolve playback immediately; ad and ad-blocker overlays must not
    // intercept the Watch action before a source can be loaded.
    await loadVideo();
  }

  Future<void> _loadProviders() async {
    _scraperApiUrl = Provider.of<AppDependencyProvider>(context, listen: false)
        .flixquestAPIURL;
    final providers = <VideoProvider>[];
    try {
      providers.addAll(await ScraperApi(_scraperApiUrl).getProviders());
    } catch (error) {
      debugPrint('Unable to load scraper providers: $error');
    }

    // Keep the app's existing VixSrc implementation as an independent source,
    // even if the scraper API also exposes a provider named "vixsrc". Karamara
    // is pinned first; the saved order is retained for all remaining providers.
    providers.add(VideoProvider.directVixSrc);
    final orderedProviders = VideoProviderOrder.prioritizeKaramara(
      settings.orderStreamProviders(providers),
    );
    if (!mounted) return;
    setState(() {
      videoProviders = orderedProviders;
      providerStates = orderedProviders
          .map(
            (provider) => ProviderLoadState(
              codeName: provider.codeName,
              fullName: provider.displayName,
              content: provider.content,
              status: ProviderStatus.pending,
            ),
          )
          .toList();
    });
  }

  Future<void> loadVideo() async {
    if (!mounted) return;
    try {
      // Start independent local/network work together. None of it is needed
      // before provider resolution begins.
      final recommendationsFetch =
          widget.download ? null : _fetchMovieRecommendations();
      final bookmarkedFuture =
          recentlyWatchedMoviesController.contain(_metadata.movieId!);
      await _loadProviders();
      final isBookmarked = await bookmarkedFuture;
      int elapsed = 0;
      if (isBookmarked) {
        var rMovies =
            Provider.of<RecentProvider>(context, listen: false).movies;
        int index =
            rMovies.indexWhere((element) => element.id == _metadata.movieId);
        // A cloud merge can add the row to the database before this snapshot of
        // the provider list catches up, so resume from the start if it is not
        // here yet rather than indexing past the end.
        if (index != -1) {
          setState(() {
            elapsed = rMovies[index].elapsed!;
          });
        }
        _metadata.elapsed = elapsed;
      } else {
        _metadata.elapsed = 0;
      }

      final isUnreleased =
          _metadata.releaseDate != null && !isReleased(_metadata.releaseDate!);
      if (isUnreleased) {
        GlobalMethods.showScaffoldMessage(
            tr('movie_may_not_be_available'), context);
      }

      ProviderSelection? selection;
      Future<ProviderSelection?>? backgroundProviderSelection;
      Stream<ProviderAttempt>? backgroundProviderAttempts;
      if (widget.download) {
        selection = await _fetchSelection(providers: videoProviders);
      } else {
        // Start all providers together but hand off to playback as soon as a
        // single usable result arrives. Alternatives continue in background.
        final session = _startProviderSelection(providers: videoProviders);
        final firstAttempt = await session.firstPlayable;
        if (firstAttempt != null) {
          selection = ProviderSelection(
            index: firstAttempt.index,
            provider: firstAttempt.provider,
            result: firstAttempt.result,
            attempts: <ProviderAttempt>[firstAttempt],
          );
        }
        backgroundProviderSelection = session.allSuccessful;
        backgroundProviderAttempts = session.providerAttempts;
      }

      if (!mounted) return;
      // Hand the unified provider result to the player immediately.
      // Manifest language scans and pre-playback language dialogs are not
      // part of the normal Watch path.
      final playerAttempts = selection?.attempts ?? const <ProviderAttempt>[];
      final firstWorkingProviderCode = selection?.provider.codeName;
      final selectedResult = selection?.result;
      const eligibleProviderCodes = <String>[];
      const String? selectedAudioLanguageCode = null;
      if (selectedResult != null && firstWorkingProviderCode != null) {
        _showSelectedProvider(selection!.provider);
        final result = selectedResult;
        videos = VideoUtils.convertVideoLinksToMap(result.videoLinks!);
        movieVideoLinks = result.videoLinks;
        movieVideoSubs = result.subtitleLinks;
        _addSubtitles(result.subtitleLinks);
      }

      if (firstWorkingProviderCode == null && mounted) {
        _showErrorSheet(tr('movie_vid_404'));
        return;
      }

      // Prepare final video map (reversed for quality ordering)
      Map<String, String> reversedVids =
          VideoUtils.reverseVideoQualityMap(videos);
      final videoFormats = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoFormatsToMap(movieVideoLinks ?? const []),
      );
      final videoHeaders = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoHeadersToMap(movieVideoLinks ?? const []),
      );
      final videoSizeTokens = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoSizeTokensToMap(movieVideoLinks ?? const []),
      );
      final videoAudioLanguages = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoAudioLanguagesToMap(movieVideoLinks ?? const []),
      );
      final videoProviderCodes = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoProviderCodesToMap(movieVideoLinks ?? const []),
      );

      if (firstWorkingProviderCode != null && mounted) {
        if (widget.download) {
          final subtitleTrack = _preferredSubtitle(movieVideoSubs);
          final queued = await UnifiedDownloadWorkflow.enqueue(
            context,
            attempts: selection?.attempts ?? const <ProviderAttempt>[],
            scraperApiUrl: _scraperApiUrl,
            id: 'movie_${_metadata.movieId}',
            title: _metadata.movieName ?? 'Movie',
            mediaType: 'movie',
            contentId: _metadata.movieId,
            posterUrl: (_metadata.posterPath == null ? null : '${TMDB_BASE_IMAGE_URL}w500${_metadata.posterPath}'),
            seasonNumber: null,
            episodeNumber: null,
            episodeLabel: null,
            subtitleTrackUrl: subtitleTrack?.url,
            subtitleTrackName: subtitleTrack?.language,
            subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
          );
          if (mounted) Navigator.pop(context, queued);
          return;
        }
        if (!isUnreleased) {
          Provider.of<SettingsProvider>(context, listen: false)
              .analytics
              .trackMovieWatched(
                movieName: _metadata.movieName,
                movieId: _metadata.movieId,
                isAdult: _metadata.isAdult ?? 'unknown',
              );
        }

        // Recommendations enrich the watch page but must not hold up
        // first-frame playback. Continue loading them after route handoff.
        unawaited(recommendationsFetch);

        // Navigate to player with provider list for lazy loading
        debugPrint(
          '[MovieRecommendationsDebug][PLAYER_HANDOFF] '
          'movieId=${_metadata.movieId} '
          'title=${_metadata.movieName} '
          'recommendations=${_metadata.recommendations?.length ?? 0} '
          'recommendationIds=${_metadata.recommendations?.map((movie) => movie.movieId).join(',') ?? 'none'}',
        );
        handoffLoaderToPlayer<void>(
          context,
          (context) {
            debugPrint(
              '[MovieRecommendationsDebug][PLAYER_CREATED] '
              'movieId=${_metadata.movieId} '
              'recommendations=${_metadata.recommendations?.length ?? 0} '
              'recommendationsNull=${_metadata.recommendations == null} '
              'useTvPlayer=${widget.useTvPlayer}',
            );
            final player = PlayerOne(
              mediaType: MediaType.movie,
              sources: reversedVids,
              subs: subs,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).colorScheme.surface
              ],
              settings: settings,
              movieMetadata: _metadata,
              availableProviders:
                  videoProviders, // Pass provider list for lazy loading
              currentProviderCode: firstWorkingProviderCode, // Current provider
              scraperApiUrl: _scraperApiUrl,
              videoFormats: videoFormats,
              videoHeaders: videoHeaders,
              videoSizeTokens: videoSizeTokens,
              videoAudioLanguages: videoAudioLanguages,
              videoProviderCodes: videoProviderCodes,
              initialVideoLinks: movieVideoLinks ?? const [],
              initialProviderAttempts: playerAttempts,
              eligibleProviderCodes: eligibleProviderCodes,
              selectedAudioLanguageCode: selectedAudioLanguageCode,
              backgroundProviderSelection: backgroundProviderSelection,
              backgroundProviderAttempts: backgroundProviderAttempts,
              subtitleStyle:
                  Provider.of<SettingsProvider>(context).subtitleTextStyle,
              useTvControls: widget.useTvPlayer,
              onTvPlayerExit: widget.onTvPlayerExit,
            );
            return widget.useTvPlayer ? TvPlayerScreen(child: player) : player;
          },
        );
      } else {
        if (mounted) {
          _showErrorSheet(tr('movie_vid_404'));
        }
      }
    } on Exception catch (e) {
      debugPrint('[MovieVideoLoader] Exception loading video: $e');
      if (mounted) {
        _showErrorSheet(tr('movie_vid_404'));
      }
    }
  }

  /// Focus the carousel on the first provider still being fetched so the
  /// highlight does not linger on a provider that just failed or succeeded.
  int _firstLoadingProviderIndex() {
    for (var index = 0; index < providerStates.length; index++) {
      if (providerStates[index].status == ProviderStatus.loading) {
        return index;
      }
    }
    return currentProviderIndex;
  }

  /// Shows [provider] as the one selected for playback.
  void _showSelectedProvider(VideoProvider provider) {
    if (!mounted) return;
    setState(() {
      currentProviderIndex = videoProviders.indexWhere(
        (candidate) => candidate.codeName == provider.codeName,
      );
    });
  }

  /// Starts provider lookups in parallel. Normal playback waits only for
  /// the first usable source; downloads can still await the full result.
  ProviderLoadSession _startProviderSelection({
    required List<VideoProvider> providers,
  }) {
    return ProviderLoader.startFastThenExpand(
      providers: providers,
      loadFast: (provider) {
        _providerStopwatches[provider.codeName] = Stopwatch()..start();
        // Providers resolve concurrently, so each active request gets a loading state.
        if (mounted) {
          setState(() {
            final providerIndex = providerStates.indexWhere(
              (state) => state.codeName == provider.codeName,
            );
            if (providerIndex != -1) {
              providerStates[providerIndex] = providerStates[providerIndex]
                  .copyWith(status: ProviderStatus.loading);
            }
            currentProviderIndex = _firstLoadingProviderIndex();
          });
        }
        debugPrint(
          '[MovieVideoLoader] Request provider=${provider.displayName} '
          '(${provider.codeName}), tmdbId=${_metadata.movieId}',
        );
        return ProviderLoader.loadMovieFromProvider(
          provider: provider,
          movieId: _metadata.movieId!,
          scraperApiUrl: _scraperApiUrl,
          // The first working server is enough to start playback. The full
          // collection is requested separately after a fast source is found.
          full: false,
        );
      },
      loadExpanded: (provider, fastResult) {
        if (provider.type == VideoProviderType.directVixSrc) {
          return Future<ProviderLoadResult>.value(fastResult);
        }
        return ProviderLoader.loadMovieFromProvider(
          provider: provider,
          movieId: _metadata.movieId!,
          scraperApiUrl: _scraperApiUrl,
          full: true,
        );
      },
      onResult: (index, provider, result) {
        final providerSucceeded =
            result.success && result.videoLinks?.isNotEmpty == true;
        final providerIndex = videoProviders.indexWhere(
          (candidate) => candidate.codeName == provider.codeName,
        );
        debugPrint(
          '[MovieVideoLoader] Response provider=${provider.displayName} '
          'success=${result.success}, links=${result.videoLinks?.length ?? 0}, '
          'subtitles=${result.subtitleLinks?.length ?? 0}, error=${result.errorMessage}',
        );
        if (mounted &&
            providerIndex >= 0 &&
            providerIndex < providerStates.length) {
          setState(() {
            providerStates[providerIndex] =
                providerStates[providerIndex].copyWith(
              // A failed fast response is still being retried through
              // full-collection resolution. Only the final callback marks it
              // definitively failed.
              status: providerSucceeded
                  ? ProviderStatus.success
                  : ProviderStatus.loading,
              errorMessage: providerSucceeded ? null : result.errorMessage,
            );
            currentProviderIndex = _firstLoadingProviderIndex();
          });
        }
      },
      // Full-collection resolution runs after the initial source hand-off.
      // Publish its result too, so transient failures can recover to Success
      // instead of leaving the provider marked Failed.
      onFinalResult: (index, provider, result) {
        // Measure and report the complete fast + recovery attempt, not only
        // the first response. A transient fast failure followed by a working
        // full collection is a provider success in reliability analytics.
        final durationMs = _providerStopwatches
                .remove(provider.codeName)
                ?.elapsedMilliseconds ??
            0;
        final providerSucceeded =
            result.success && result.videoLinks?.isNotEmpty == true;
        settings.analytics.trackProviderAttempt(
          mediaType: 'movie',
          contentId: _metadata.movieId,
          contentTitle: _metadata.movieName,
          provider: provider.displayName,
          purpose: widget.download ? 'download' : 'playback',
          success: providerSucceeded,
          durationMs: durationMs,
          sourceCount: result.videoLinks?.length ?? 0,
          subtitleCount: result.subtitleLinks?.length ?? 0,
          error: result.errorMessage,
        );
        final providerIndex = videoProviders.indexWhere(
          (candidate) => candidate.codeName == provider.codeName,
        );
        if (mounted &&
            providerIndex >= 0 &&
            providerIndex < providerStates.length) {
          final succeeded =
              result.success && result.videoLinks?.isNotEmpty == true;
          setState(() {
            providerStates[providerIndex] =
                providerStates[providerIndex].copyWith(
              status: succeeded ? ProviderStatus.success : ProviderStatus.failed,
              errorMessage: result.errorMessage,
            );
            currentProviderIndex = _firstLoadingProviderIndex();
          });
        }
      },
      providerTimeout: const Duration(seconds: 25),
      expansionTimeout: const Duration(seconds: 35),
    );
  }

  Future<ProviderSelection?> _fetchSelection({
    required List<VideoProvider> providers,
  }) =>
      _startProviderSelection(providers: providers).allSuccessful;

  /// Leaves the loader screen and reports the failure in a bottom sheet that
  /// can push a fresh loader when the user retries.
  void _showErrorSheet(String message) {
    final navigator = Navigator.of(context);
    final metadata = _metadata;
    final download = widget.download;
    final useTvPlayer = widget.useTvPlayer;
    final onTvPlayerExit = widget.onTvPlayerExit;
    final adStage = widget.adStage;
    navigator.pop();
    ReportErrorWidget.show(
      navigator.context,
      error: message,
      onRetry: () => navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MovieVideoLoader(
            metadata: metadata,
            download: download,
            useTvPlayer: useTvPlayer,
            onTvPlayerExit: onTvPlayerExit,
            adStage: adStage,
          ),
        ),
      ),
    );
  }

  RegularSubtitleLinks? _preferredSubtitle(
    List<RegularSubtitleLinks>? subtitles,
  ) {
    if (subtitles == null || subtitles.isEmpty) return null;
    final preferred = settings.defaultSubtitleLanguage.toLowerCase();
    for (final subtitle in subtitles) {
      final language = subtitle.language?.toLowerCase() ?? '';
      if (subtitle.url?.isNotEmpty == true &&
          preferred.isNotEmpty &&
          (language == preferred ||
              language.startsWith(preferred) ||
              (preferred == 'en' && language.startsWith('english')))) {
        return subtitle;
      }
    }
    return subtitles.cast<RegularSubtitleLinks?>().firstWhere(
          (subtitle) => subtitle?.url?.isNotEmpty == true,
          orElse: () => null,
        );
  }

  void _addSubtitles(List<RegularSubtitleLinks>? subtitleLinks) {
    if (subtitleLinks == null || subtitleLinks.isEmpty) return;
    final preferredLang = settings.defaultSubtitleLanguage.toLowerCase();

    for (final subLink in subtitleLinks) {
      final subLanguage = subLink.language ?? 'Unknown';
      final normalizedLanguage = subLanguage.toLowerCase();
      final isPreferred = preferredLang.isNotEmpty &&
          (normalizedLanguage.startsWith(preferredLang) ||
              normalizedLanguage == preferredLang ||
              (preferredLang == 'en' &&
                  normalizedLanguage.startsWith('english')));
      subs.add(
        BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.network,
          urls: [subLink.url ?? ''],
          name: subLanguage,
          selectedByDefault: isPreferred,
          headers: subLink.headers,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final releaseYear = _metadata.releaseYear?.toString() ??
        _metadata.releaseDate?.split('-').first;
    final contextLine = <String>[
      if (widget.download) tr('download'),
      if (releaseYear?.isNotEmpty == true && releaseYear != '0') releaseYear!,
    ].join('  ·  ');
    return PlaybackLoadingScreen(
      title: _metadata.movieName?.trim().isNotEmpty == true
          ? _metadata.movieName!.trim()
          : tr('movie'),
      subtitle: contextLine,
      backdropPath: _metadata.backdropPath,
      posterPath: _metadata.posterPath,
      providers: providerStates,
      currentProviderIndex: currentProviderIndex,
      showProviderDetails: widget.download,
    );
  }

  Future<void> _fetchMovieRecommendations() async {
    final movieId = _metadata.movieId;
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final language = settings.appLanguage;
    debugPrint(
      '[MovieRecommendationsDebug][FETCH_START] '
      'movieId=$movieId language=$language '
      'proxyEnabled=$isProxyEnabled proxyConfigured=${proxyUrl.isNotEmpty} '
      'mounted=$mounted',
    );
    if (movieId == null) {
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_SKIPPED] reason=missing_movie_id',
      );
      return;
    }

    final recommendations = await _loadRecommendations(
      movieId: movieId,
      isProxyEnabled: isProxyEnabled,
      proxyUrl: proxyUrl,
      language: language,
    );
    _metadata.recommendations = recommendations;
    debugPrint(
      '[MovieRecommendationsDebug][METADATA_SET] '
      'movieId=$movieId count=${recommendations.length} '
      'items=${recommendations.map((movie) => '${movie.movieId}:${movie.title}').join(' | ')}',
    );

    // Set the movie change callback
    _metadata.onMovieChange = (int movieId) async {
      // This will be called from the player when user selects a movie
    };
  }

  /// TMDB's "recommendations" is frequently empty for newer or niche titles, so
  /// fall back to the broader "similar" list before giving up.
  Future<List<MovieRecommendation>> _loadRecommendations({
    required int movieId,
    required bool isProxyEnabled,
    required String proxyUrl,
    required String language,
  }) async {
    if (_metadata.originalLanguage?.trim().toLowerCase() == 'hi') {
      final related = await Future.wait<List<Movie>>([
        _fetchRecommendationList(
          label: 'Hindi-origin recommendations',
          endpoint: Endpoints.getMovieRecommendations(movieId, 1, language),
          isProxyEnabled: isProxyEnabled,
          proxyUrl: proxyUrl,
        ),
        _fetchRecommendationList(
          label: 'Hindi-origin similar movies',
          endpoint: Endpoints.getSimilarMovies(movieId, 1, language),
          isProxyEnabled: isProxyEnabled,
          proxyUrl: proxyUrl,
        ),
      ]);

      var discoveries = <Movie>[];
      var selected = HindiOriginMovieRecommendations.merge(
        sourceMovieId: movieId,
        recommendations: related[0],
        similar: related[1],
        discovery: discoveries,
      );

      if (selected.length < 10) {
        discoveries = await _fetchRecommendationList(
          label: 'Hindi-origin genre discovery',
          endpoint: Endpoints.discoverMoviesByOriginalLanguageUrl(
            language,
            originalLanguage: 'hi',
            genreIds: _metadata.genreIds,
            includeAdult: settings.isAdult,
          ),
          isProxyEnabled: isProxyEnabled,
          proxyUrl: proxyUrl,
        );
        selected = HindiOriginMovieRecommendations.merge(
          sourceMovieId: movieId,
          recommendations: related[0],
          similar: related[1],
          discovery: discoveries,
        );
      }

      if (selected.length < 10 && _metadata.genreIds?.isNotEmpty == true) {
        final broadDiscoveries = await _fetchRecommendationList(
          label: 'Hindi-origin popular discovery',
          endpoint: Endpoints.discoverMoviesByOriginalLanguageUrl(
            language,
            originalLanguage: 'hi',
            includeAdult: settings.isAdult,
          ),
          isProxyEnabled: isProxyEnabled,
          proxyUrl: proxyUrl,
        );
        selected = HindiOriginMovieRecommendations.merge(
          sourceMovieId: movieId,
          recommendations: related[0],
          similar: related[1],
          discovery: [...discoveries, ...broadDiscoveries],
        );
      }

      return selected
          .take(10)
          .map(MovieRecommendation.fromMovie)
          .toList(growable: false);
    }

    // Other titles keep the existing relevance-first recommendations flow.
    var movies = await _fetchRecommendationList(
      label: 'recommendations',
      endpoint: Endpoints.getMovieRecommendations(movieId, 1, language),
      isProxyEnabled: isProxyEnabled,
      proxyUrl: proxyUrl,
    );
    if (movies.isEmpty) {
      debugPrint(
        '[MovieRecommendationsDebug][FALLBACK_SIMILAR] movieId=$movieId',
      );
      movies = await _fetchRecommendationList(
        label: 'similar',
        endpoint: Endpoints.getSimilarMovies(movieId, 1, language),
        isProxyEnabled: isProxyEnabled,
        proxyUrl: proxyUrl,
      );
    }
    return movies
        .take(10)
        .map(MovieRecommendation.fromMovie)
        .toList(growable: false);
  }

  Future<List<Movie>> _fetchRecommendationList({
    required String label,
    required String endpoint,
    required bool isProxyEnabled,
    required String proxyUrl,
  }) async {
    try {
      final movies = await fetchMovies(
        endpoint,
        isProxyEnabled,
        proxyUrl,
        debugLabel: 'MovieRecommendationsDebug',
      );
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_RESULT] '
        'label=$label rawCount=${movies.length} '
        'rawIds=${movies.take(10).map((movie) => movie.id).join(',')}',
      );
      return movies;
    } catch (error, stackTrace) {
      // A failed list is not fatal; the other list (or an empty result) is used.
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_FAILED] '
        'label=$label type=${error.runtimeType} error=$error',
      );
      debugPrintStack(
        label: '[MovieRecommendationsDebug][FETCH_FAILED_STACK]',
        stackTrace: stackTrace,
      );
      return const <Movie>[];
    }
  }
}
