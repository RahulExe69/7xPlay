import 'package:better_player_plus/better_player_plus.dart';
import 'package:flixquest/models/movie_stream_metadata.dart';
import 'package:flixquest/models/tv_stream_metadata.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../catalog/up_next.dart';
import '../../../constants/app_constants.dart';
import '../../../controllers/recently_watched_database_controller.dart';
import '../../../functions/function.dart';
import '../../../models/recently_watched.dart';
import '../../../provider/recently_watched_provider.dart';

class PlayerDataManagement {
  PlayerDataManagement({
    RecentlyWatchedMoviesController? recentlyWatchedMoviesController,
    RecentlyWatchedEpisodeController? recentlyWatchedEpisodeController,
  })  : recentlyWatchedMoviesController = recentlyWatchedMoviesController ??
            RecentlyWatchedMoviesController(),
        recentlyWatchedEpisodeController = recentlyWatchedEpisodeController ??
            RecentlyWatchedEpisodeController();

  final RecentlyWatchedMoviesController recentlyWatchedMoviesController;
  final RecentlyWatchedEpisodeController recentlyWatchedEpisodeController;

  Future<void> insertRecentMovieData({
    required BuildContext context,
    required BetterPlayerController betterPlayerController,
    required int duration,
    required MovieStreamMetadata movieMetadata,
  }) async {
    if (!context.mounted || duration <= 0) return;
    final video = betterPlayerController.videoPlayerController?.value;
    if (video == null || !video.initialized) return;

    // Capture everything before yielding: exiting can unmount the route and
    // dispose the player while the database is still working.
    final prv = context.read<RecentProvider>();
    final elapsed = video.position.inSeconds;

    int remaining = duration - elapsed;
    String dt = DateTime.now().toString();

    RecentMovie rMov = RecentMovie(
        dateTime: dt,
        elapsed: elapsed,
        id: movieMetadata.movieId!,
        posterPath: movieMetadata.posterPath!,
        releaseYear: movieMetadata.releaseYear!,
        remaining: remaining,
        title: movieMetadata.movieName,
        backdropPath: movieMetadata.backdropPath!);

    double percentage = (elapsed / duration) * 100;
    final isBookmarked =
        await recentlyWatchedMoviesController.contain(rMov.id!);

    // If completion is > 85%, remove from recents (if exists) and don't add
    if (percentage > 85) {
      if (isBookmarked) {
        await prv.deleteMovie(rMov.id!);
      }
      // Don't add to recents if already completed
    } else {
      // If completion <= 85%, add or update
      if (!isBookmarked) {
        await prv.addMovie(rMov);
      } else {
        await prv.updateMovie(rMov, rMov.id!);
      }
    }
  }

  Future<void> insertRecentEpisodeData({
    required BuildContext context,
    required BetterPlayerController betterPlayerController,
    required int duration,
    required TVStreamMetadata tvMetadata,
  }) async {
    if (!context.mounted || duration <= 0) return;
    final video = betterPlayerController.videoPlayerController?.value;
    if (video == null || !video.initialized) return;

    final prv = context.read<RecentProvider>();
    final elapsed = video.position.inSeconds;

    int remaining = duration - elapsed;
    String dt = DateTime.now().toString();

    String? backdropPath = tvMetadata.backdropPath;
    if (backdropPath == null) {
      for (final episode
          in tvMetadata.seasonEpisodes ?? const <EpisodeMetadata>[]) {
        if (episode.episodeId == tvMetadata.episodeId) {
          backdropPath = episode.stillPath;
          break;
        }
      }
    }

    RecentEpisode rEpisode = RecentEpisode(
        dateTime: dt,
        elapsed: elapsed,
        id: tvMetadata.episodeId!,
        posterPath: tvMetadata.posterPath!,
        backdropPath: backdropPath ?? tvMetadata.posterPath,
        remaining: remaining,
        seriesName: tvMetadata.seriesName!,
        episodeName: tvMetadata.episodeName!,
        episodeNum: tvMetadata.episodeNumber!,
        seasonNum: tvMetadata.seasonNumber!,
        seriesId: tvMetadata.tvId!);

    double percentage = (elapsed / duration) * 100;
    final next = percentage > 85 ? UpNext.after(tvMetadata) : null;
    final isBookmarked =
        await recentlyWatchedEpisodeController.contain(rEpisode.id!);

    // If completion is > 85%, remove from recents (if exists) and don't add
    if (percentage > 85) {
      if (isBookmarked) {
        await prv.deleteEpisode(
            rEpisode.id!, rEpisode.episodeNum!, rEpisode.seasonNum!);
      }
      // Keep the series in Continue Watching, one episode on; a series with
      // nothing more to watch leaves it.
      next == null
          ? await prv.clearUpNext(rEpisode.seriesId!)
          : await prv.recordUpNext(next);
      // Don't add to recents if already completed
    } else {
      // If completion <= 85%, add or update
      if (!isBookmarked) {
        await prv.addEpisode(rEpisode);
      } else {
        await prv.updateEpisode(
            rEpisode, rEpisode.id!, rEpisode.episodeNum!, rEpisode.seasonNum!);
      }
    }
  }

  /// Handles saving progress and analytics before switching to a new episode/movie
  Future<void> handleContentSwitch({
    required BuildContext context,
    required MediaType mediaType,
    required BetterPlayerController betterPlayerController,
    required int duration,
    required int playbackDurationInSeconds,
    MovieStreamMetadata? movieMetadata,
    TVStreamMetadata? tvMetadata,
  }) async {
    // Save current playback progress
    if (mediaType == MediaType.movie) {
      await insertRecentMovieData(
        context: context,
        betterPlayerController: betterPlayerController,
        duration: duration,
        movieMetadata: movieMetadata!,
      );
    } else {
      await insertRecentEpisodeData(
        context: context,
        betterPlayerController: betterPlayerController,
        duration: duration,
        tvMetadata: tvMetadata!,
      );
    }

    // Send analytics for current viewing session
    updateAndLogTotalStreamingDuration(playbackDurationInSeconds);
  }
}
