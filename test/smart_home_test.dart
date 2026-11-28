import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/smart_home.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _movie(
  int id, {
  List<int> genres = const <int>[],
  num popularity = 0,
  num rating = 0,
}) =>
    MediaItem.fromMovie(
      Movie(
        id: id,
        title: 'Movie $id',
        genreIds: genres,
        popularity: popularity,
        voteAverage: rating,
        posterPath: '/$id.jpg',
      ),
    );

MediaItem _series(
  int id, {
  List<int> genres = const <int>[],
  num popularity = 0,
  num rating = 0,
}) =>
    MediaItem.fromSeries(
      TV(
        id: id,
        name: 'Series $id',
        genreIds: genres,
        popularity: popularity,
        voteAverage: rating,
        posterPath: '/$id.jpg',
      ),
    );

void main() {
  group('SmartHome.personalized', () {
    test('genre overlap outranks popularity, then popularity breaks ties', () {
      final result = SmartHome.personalized(
        saved: <MediaItem>[_movie(90, genres: [28, 12])],
        candidates: <MediaItem>[
          _movie(1, genres: [28, 12], popularity: 10, rating: 6),
          _movie(2, genres: [28], popularity: 900, rating: 9),
          _movie(3, genres: [12], popularity: 100, rating: 8),
          _movie(4, genres: [35], popularity: 5000, rating: 10),
        ],
      );

      expect(result.map((item) => item.id), <int>[1, 2, 3]);
    });

    test('later duplicate with genre metadata remains eligible', () {
      final result = SmartHome.personalized(
        saved: <MediaItem>[_movie(90, genres: [28])],
        candidates: <MediaItem>[
          _movie(1),
          _movie(1, genres: [28], popularity: 20),
        ],
      );

      expect(result.map((item) => item.id), <int>[1]);
      expect(result.single.genreIds, <int>[28]);
    });

    test('saved and continue-watching titles are excluded and candidates dedupe', () {
      final saved = _movie(90, genres: [28]);
      final inProgress = _movie(91, genres: [28]);
      final result = SmartHome.personalized(
        saved: <MediaItem>[saved],
        continueWatching: <MediaItem>[inProgress],
        candidates: <MediaItem>[
          saved,
          inProgress,
          _movie(1, genres: [28], popularity: 10),
          _movie(1, genres: [28], popularity: 20),
          _movie(2, genres: [28], popularity: 5),
        ],
      );

      expect(result.map((item) => item.id), <int>[1, 2]);
      expect(result.map((item) => item.stableId).toSet(), hasLength(2));
    });

    test('in-progress history contributes affinity when feed metadata is available', () {
      final recentWithoutGenres = <MediaItem>[
        _movie(90),
        _movie(91),
      ];
      final result = SmartHome.personalized(
        saved: <MediaItem>[_movie(80, genres: [28])],
        continueWatching: recentWithoutGenres,
        candidates: <MediaItem>[
          _movie(90, genres: [16], popularity: 1),
          _movie(91, genres: [16], popularity: 1),
          _movie(1, genres: [16], popularity: 10),
          _movie(2, genres: [28], popularity: 900),
        ],
      );

      expect(result.map((item) => item.id), <int>[1, 2]);
    });

    test('legacy bookmarks without genre metadata do not personalize the feed', () {
      final result = SmartHome.personalized(
        saved: <MediaItem>[_movie(90)],
        candidates: <MediaItem>[_movie(1, genres: [28])],
      );

      expect(result, isEmpty);
    });

    test('genre preferences remain separated between movies and series', () {
      final result = SmartHome.personalized(
        saved: <MediaItem>[_movie(90, genres: [28])],
        candidates: <MediaItem>[
          _series(1, genres: [28], popularity: 1000),
          _movie(2, genres: [28], popularity: 1),
        ],
      );

      expect(result.map((item) => item.stableId), <String>['movie:2']);
    });

    test('recommendation count respects the requested limit', () {
      final result = SmartHome.personalized(
        saved: <MediaItem>[_movie(90, genres: [28])],
        candidates: <MediaItem>[
          for (var id = 1; id <= 5; id++) _movie(id, genres: [28], popularity: 6 - id),
        ],
        limit: 2,
      );

      expect(result.map((item) => item.id), <int>[1, 2]);
    });
  });

  group('SmartHome.watchlistUpdates', () {
    test('shows saved titles found in current or upcoming lists once', () {
      final saved = <MediaItem>[
        _movie(1, genres: [28]),
        _series(2, genres: [16]),
        _movie(3, genres: [35]),
      ];
      final current = <MediaItem>[
        _series(2, genres: [16]),
        _movie(4, genres: [28]),
      ];
      final upcoming = <MediaItem>[
        _movie(1, genres: [28]),
        _series(2, genres: [16]),
        _movie(5, genres: [35]),
      ];

      final result = SmartHome.watchlistUpdates(
        saved: saved,
        current: current,
        upcoming: upcoming,
      );

      expect(
        result.map((item) => item.stableId),
        <String>['series:2', 'movie:1'],
      );
    });

    test('returns no updates for unrelated or empty lists', () {
      expect(
        SmartHome.watchlistUpdates(
          saved: <MediaItem>[_movie(1)],
          current: <MediaItem>[_movie(2)],
          upcoming: const <MediaItem>[],
        ),
        isEmpty,
      );
    });

    test('watchlist update count respects the requested limit', () {
      final result = SmartHome.watchlistUpdates(
        saved: <MediaItem>[
          _movie(1),
          _movie(2),
          _movie(3),
        ],
        current: <MediaItem>[
          _movie(1),
          _movie(2),
          _movie(3),
        ],
        upcoming: const <MediaItem>[],
        limit: 2,
      );

      expect(result.map((item) => item.id), <int>[1, 2]);
    });
  });
}
