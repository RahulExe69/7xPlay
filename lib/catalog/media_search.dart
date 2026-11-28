import '../api/endpoints.dart';
import '../functions/network.dart';
import '../models/person.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import 'media_item.dart';

/// Where Search's results come from, so tests can answer (and delay) as
/// they like.
abstract class SearchSource {
  Future<List<MediaItem>> movies(String query);
  Future<List<MediaItem>> series(String query);
  Future<List<Person>> people(String query);
}

/// TMDB, with the viewer's language and adult-content setting.
class TmdbSearchSource implements SearchSource {
  const TmdbSearchSource({required this.settings, required this.dependencies});

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;

  String _encode(String query) => Uri.encodeQueryComponent(query.trim());

  @override
  Future<List<MediaItem>> movies(String query) => fetchMovies(
        Endpoints.movieSearchUrl(
          _encode(query),
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then((items) => items.map(MediaItem.fromMovie).toList());

  @override
  Future<List<MediaItem>> series(String query) => fetchTV(
        Endpoints.tvSearchUrl(
          _encode(query),
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then((items) => items.map(MediaItem.fromSeries).toList());

  @override
  Future<List<Person>> people(String query) => fetchPerson(
        Endpoints.personSearchUrl(
          _encode(query),
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      );
}

/// What a query found, each kind in its own list.
class SearchResults {
  const SearchResults({
    required this.query,
    this.topResult,
    this.movies = const <MediaItem>[],
    this.series = const <MediaItem>[],
    this.people = const <Person>[],
  });

  final String query;

  /// The one title the query most likely means, if one stands out.
  final MediaItem? topResult;
  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<Person> people;

  bool get isEmpty => movies.isEmpty && series.isEmpty && people.isEmpty;
}

/// How Search looks things up: after the viewer stops typing, and only for
/// a query worth sending.
abstract final class MediaSearch {
  /// The pause in typing before a search goes out.
  static const debounce = Duration(milliseconds: 350);

  /// The shortest query that searches.
  static const minLength = 2;

  static bool searchable(String query) => query.trim().length >= minLength;

  /// Every kind at once; a kind that fails comes back empty rather than
  /// taking the others with it.
  static Future<SearchResults> run(SearchSource source, String query) async {
    Future<List<T>> orEmpty<T>(Future<List<T>> future) =>
        future.catchError((Object _) => <T>[]);
    final found = await Future.wait<Object>(<Future<Object>>[
      orEmpty(source.movies(query)),
      orEmpty(source.series(query)),
      orEmpty(source.people(query)),
    ]);
    final movies = rankTitles(query, unique(found[0] as List<MediaItem>));
    final series = rankTitles(query, unique(found[1] as List<MediaItem>));
    final people = (found[2] as List<Person>)
        .where((person) => person.id != null)
        .toList(growable: false);
    return SearchResults(
      query: query,
      topResult: topResultFor(query, movies: movies, series: series),
      movies: movies,
      series: series,
      people: people,
    );
  }

  static List<MediaItem> unique(List<MediaItem> items) {
    final seen = <String>{};
    return items
        .where((item) => item.id >= 0 && seen.add(item.stableId))
        .toList(growable: false);
  }

  /// Orders returned titles by how closely their normalized title matches
  /// the query. Popularity and rating only break ties between match levels.
  ///
  /// This ranks the results already returned by SearchSource; it does not
  /// change the query sent to TMDB or add another request.
  static List<MediaItem> rankTitles(String query, List<MediaItem> items) {
    final ranked = List<MediaItem>.of(items);
    ranked.sort((a, b) {
      final byMatch = _matchRank(query, b.title).compareTo(
        _matchRank(query, a.title),
      );
      if (byMatch != 0) return byMatch;
      if (_matchRank(query, a.title) == 1) {
        final byDistance = _fuzzyDistance(query, a.title).compareTo(
          _fuzzyDistance(query, b.title),
        );
        if (byDistance != 0) return byDistance;
      }
      final byPopularity =
          (b.popularity ?? 0).compareTo(a.popularity ?? 0);
      if (byPopularity != 0) return byPopularity;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      if (byRating != 0) return byRating;
      final byTitle = a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          );
      if (byTitle != 0) return byTitle;
      return a.stableId.compareTo(b.stableId);
    });
    return ranked.toList(growable: false);
  }

  /// A title the query plainly names, or one unambiguous close typo match.
  /// Exact, prefix and contained matches may be promoted directly. A fuzzy
  /// candidate is only promoted when it is uniquely closest; ambiguity is
  /// left for the viewer to decide.
  static MediaItem? topResultFor(
    String query, {
    required List<MediaItem> movies,
    required List<MediaItem> series,
  }) {
    final all = <MediaItem>[...movies, ...series];
    if (normalize(query).isEmpty || all.isEmpty) return null;
    final ranked = rankTitles(query, all);
    final best = ranked.first;
    final rank = _matchRank(query, best.title);
    if (rank == 0) return null;
    if (rank == 1) {
      final bestDistance = _fuzzyDistance(query, best.title);
      final equallyClose = all
          .where((item) => _fuzzyDistance(query, item.title) == bestDistance)
          .length;
      if (equallyClose != 1) return null;
    }
    return best;
  }

  static int _matchRank(String query, String title) {
    final wanted = normalize(query);
    final candidate = normalize(title);
    if (wanted.isEmpty || candidate.isEmpty) return 0;
    if (candidate == wanted) return 4;
    if (candidate.startsWith(wanted)) return 3;
    if (candidate.contains(wanted)) return 2;
    return _fuzzyDistance(wanted, candidate) <= _maxFuzzyDistance(wanted)
        ? 1
        : 0;
  }

  static int _maxFuzzyDistance(String query) =>
      query.length >= 7 ? 2 : 1;

  /// Minimum Levenshtein distance to the full title or any title token.
  /// Comparing tokens lets "avatr" find "Avatar: The Way of Water".
  static int _fuzzyDistance(String query, String title) {
    final wanted = normalize(query);
    final candidate = normalize(title);
    if (wanted.length < 4 || candidate.isEmpty) return 1 << 20;
    final maxDistance = _maxFuzzyDistance(wanted);
    final tokens = <String>{candidate, ...candidate.split(' ')};
    var best = 1 << 20;
    for (final token in tokens) {
      if ((token.length - wanted.length).abs() > maxDistance) continue;
      final distance = _editDistance(wanted, token);
      if (distance < best) best = distance;
      if (best == 0) break;
    }
    return best;
  }

  static int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var row = 1; row <= a.length; row++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = row;
      for (var column = 1; column <= b.length; column++) {
        final substitution = previous[column - 1] +
            (a.codeUnitAt(row - 1) == b.codeUnitAt(column - 1) ? 0 : 1);
        final insertion = current[column - 1] + 1;
        final deletion = previous[column] + 1;
        current[column] = <int>[substitution, insertion, deletion].reduce(
          (left, right) => left < right ? left : right,
        );
      }
      previous = current;
    }
    return previous[b.length];
  }

  /// A title for comparing: lower case, punctuation and extra spaces gone.
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
