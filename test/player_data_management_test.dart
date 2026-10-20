import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:flixquest/catalog/up_next.dart';
import 'package:flixquest/controllers/recently_watched_database_controller.dart';
import 'package:flixquest/models/movie_stream_metadata.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv_stream_metadata.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flixquest/screens/common/player/player_background_save.dart';
import 'package:flixquest/screens/common/player/player_data_management.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Movies implements RecentlyWatchedMoviesController {
  final contains = Completer<bool>();

  @override
  Future<bool> contain(int id) => contains.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Episodes implements RecentlyWatchedEpisodeController {
  final contains = Completer<bool>();

  @override
  Future<bool> contain(int id) => contains.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Video implements VideoPlayerController {
  _Video(int elapsed)
      : value = VideoPlayerValue(
          duration: const Duration(seconds: 100),
          position: Duration(seconds: elapsed),
        );

  @override
  VideoPlayerValue value;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements BetterPlayerController {
  _Player(this.videoPlayerController);

  @override
  VideoPlayerController? videoPlayerController;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recent extends ChangeNotifier implements RecentProvider {
  final calls = <String>[];
  RecentMovie? movie;
  RecentEpisode? episode;
  Future<void> write = Future<void>.value();

  @override
  Future<void> addMovie(RecentMovie value) {
    movie = value;
    calls.add('add movie');
    return write;
  }

  @override
  Future<void> updateMovie(RecentMovie value, int id) {
    movie = value;
    calls.add('update movie');
    return write;
  }

  @override
  Future<void> deleteMovie(int id) {
    calls.add('delete movie');
    return write;
  }

  @override
  Future<void> addEpisode(RecentEpisode value) {
    episode = value;
    calls.add('add episode');
    return write;
  }

  @override
  Future<void> updateEpisode(
      RecentEpisode value, int id, int episodeNum, int seasonNum) {
    episode = value;
    calls.add('update episode');
    return write;
  }

  @override
  Future<void> deleteEpisode(int id, int episodeNum, int seasonNum) {
    calls.add('delete episode');
    return write;
  }

  @override
  Future<void> recordUpNext(UpNext entry) async {
    calls.add('up next ${entry.episode}');
  }

  @override
  Future<void> clearUpNext(int seriesId) async {
    calls.add('clear up next');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Movies movies;
  late _Episodes episodes;
  late _Recent recent;
  late _Video video;
  late _Player player;
  late PlayerDataManagement data;
  late BuildContext context;

  Future<void> mount(WidgetTester tester) async {
    movies = _Movies();
    episodes = _Episodes();
    recent = _Recent();
    video = _Video(50);
    player = _Player(video);
    data = PlayerDataManagement(
      recentlyWatchedMoviesController: movies,
      recentlyWatchedEpisodeController: episodes,
    );
    addTearDown(recent.dispose);
    addTearDown(video.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<RecentProvider>.value(
        value: recent,
        child: Builder(builder: (value) {
          context = value;
          return const SizedBox();
        }),
      ),
    );
  }

  Future<void> save(bool movie,
      {int duration = 100, bool lastEpisode = false}) {
    if (movie) {
      return data.insertRecentMovieData(
        context: context,
        betterPlayerController: player,
        duration: duration,
        movieMetadata: MovieStreamMetadata(
          movieId: 1,
          movieName: 'Movie',
          posterPath: '/poster.jpg',
          backdropPath: '/backdrop.jpg',
          releaseYear: 2026,
          elapsed: 0,
          isAdult: false,
          releaseDate: '2026-01-01',
        ),
      );
    }
    return data.insertRecentEpisodeData(
      context: context,
      betterPlayerController: player,
      duration: duration,
      tvMetadata: TVStreamMetadata(
        tvId: 1,
        episodeId: 11,
        seriesName: 'Series',
        episodeName: 'Pilot',
        episodeNumber: 1,
        seasonNumber: 1,
        posterPath: '/poster.jpg',
        elapsed: 0,
        airDate: '2020-01-01',
        seasonEpisodes: [
          EpisodeMetadata(
            episodeId: 11,
            episodeName: 'Pilot',
            episodeNumber: 1,
            seasonNumber: 1,
            stillPath: '/still.jpg',
          ),
          if (!lastEpisode)
            EpisodeMetadata(
              episodeId: 12,
              episodeName: 'Second',
              episodeNumber: 2,
              seasonNumber: 1,
              airDate: '2020-01-02',
            ),
        ],
      ),
    );
  }

  for (final movie in [true, false]) {
    final kind = movie ? 'movie' : 'episode';
    for (final exists in [false, true]) {
      for (final elapsed in [50, 85, 90]) {
        testWidgets(
            '$kind save survives unmount during lookup: exists=$exists, elapsed=$elapsed',
            (tester) async {
          await mount(tester);
          video.value =
              video.value.copyWith(position: Duration(seconds: elapsed));
          late Future<void> pending;
          savePlayerDataInBackground(
            () => pending = save(movie),
            operation: kind,
          );

          // The route disappears and the player is released before SQLite replies.
          await tester.pumpWidget(const SizedBox());
          expect(context.mounted, isFalse);
          expect(recent.calls, isEmpty);
          player.videoPlayerController = null;
          (movie ? movies.contains : episodes.contains).complete(exists);
          await tester.pump();
          await pending;

          expect(recent.calls, [
            if (elapsed <= 85) '${exists ? 'update' : 'add'} $kind',
            if (elapsed > 85 && exists) 'delete $kind',
            if (elapsed > 85 && !movie) 'up next 2',
          ]);
          if (elapsed <= 85) {
            expect(movie ? recent.movie?.elapsed : recent.episode?.elapsed,
                elapsed);
            expect(movie ? recent.movie?.remaining : recent.episode?.remaining,
                100 - elapsed);
            if (!movie) expect(recent.episode?.backdropPath, '/still.jpg');
          }
        });
      }
    }

    testWidgets('$kind save waits for the provider write', (tester) async {
      await mount(tester);
      final write = Completer<void>();
      recent.write = write.future;
      var finished = false;
      final pending = save(movie).then((_) => finished = true);
      (movie ? movies.contains : episodes.contains).complete(false);
      await tester.pump();
      expect(recent.calls, ['add $kind']);
      expect(finished, isFalse);
      write.complete();
      await tester.pump();
      await pending;
      expect(finished, isTrue);
    });

    for (final state in [
      'unmounted',
      'no controller',
      'uninitialized',
      'zero duration'
    ]) {
      testWidgets('$kind save skips $state', (tester) async {
        await mount(tester);
        switch (state) {
          case 'unmounted':
            await tester.pumpWidget(const SizedBox());
          case 'no controller':
            player.videoPlayerController = null;
          case 'uninitialized':
            video.value = VideoPlayerValue.uninitialized();
        }
        await save(movie, duration: state == 'zero duration' ? 0 : 100);
        expect(recent.calls, isEmpty);
      });
    }
  }

  testWidgets('finishing the last episode removes its up next entry',
      (tester) async {
    await mount(tester);
    video.value = video.value.copyWith(position: const Duration(seconds: 90));
    final pending = save(false, lastEpisode: true);
    episodes.contains.complete(true);
    await tester.pump();
    await pending;
    expect(recent.calls, ['delete episode', 'clear up next']);
  });
}
