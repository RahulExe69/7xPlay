import '../models/movie.dart';

/// Builds a de-duplicated, Hindi-original recommendation list.
///
/// TMDB's recommendation/similar endpoints are useful for relevance but are
/// not language filters. Discover results provide a Hindi-original fallback.
abstract final class HindiOriginMovieRecommendations {
  static List<Movie> merge({
    required int sourceMovieId,
    required Iterable<Movie> recommendations,
    required Iterable<Movie> similar,
    required Iterable<Movie> discovery,
    int limit = 10,
  }) {
    if (limit <= 0) return const <Movie>[];

    final seen = <int>{sourceMovieId};
    final result = <Movie>[];

    for (final group in <Iterable<Movie>>[
      recommendations,
      similar,
      discovery,
    ]) {
      for (final movie in group) {
        final id = movie.id;
        final language = movie.originalLanguage?.trim().toLowerCase();
        if (id == null ||
            id <= 0 ||
            language != 'hi' ||
            seen.contains(id)) {
          continue;
        }
        seen.add(id);
        result.add(movie);
        if (result.length >= limit) {
          return List<Movie>.unmodifiable(result);
        }
      }
    }
    return List<Movie>.unmodifiable(result);
  }
}
