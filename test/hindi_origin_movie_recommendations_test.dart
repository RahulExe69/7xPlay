import 'package:flixquest/catalog/hindi_origin_movie_recommendations.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flutter_test/flutter_test.dart';

Movie _movie(int id, String language) =>
    Movie(id: id, title: 'Movie $id', originalLanguage: language);

void main() {
  group('HindiOriginMovieRecommendations', () {
    test('keeps Hindi-origin titles only and excludes the source movie', () {
      final result = HindiOriginMovieRecommendations.merge(
        sourceMovieId: 1,
        recommendations: [
          _movie(2, 'en'),
          _movie(3, 'hi'),
          _movie(1, 'hi'),
        ],
        similar: [_movie(4, 'ja'), _movie(5, 'hi')],
        discovery: [_movie(6, 'bn')],
      );

      expect(result.map((movie) => movie.id), [3, 5]);
    });

    test('deduplicates across related and discovery lists while preserving order', () {
      final result = HindiOriginMovieRecommendations.merge(
        sourceMovieId: 1,
        recommendations: [_movie(2, 'hi')],
        similar: [_movie(2, 'hi'), _movie(3, 'hi')],
        discovery: [_movie(3, 'hi'), _movie(4, 'hi')],
      );

      expect(result.map((movie) => movie.id), [2, 3, 4]);
    });

    test('does not let a non-Hindi duplicate hide a Hindi entry later', () {
      final result = HindiOriginMovieRecommendations.merge(
        sourceMovieId: 1,
        recommendations: [_movie(2, 'en')],
        similar: [_movie(2, 'hi')],
        discovery: const [],
      );

      expect(result.map((movie) => movie.id), [2]);
    });

    test('respects the requested limit', () {
      final result = HindiOriginMovieRecommendations.merge(
        sourceMovieId: 1,
        recommendations: [_movie(2, 'hi'), _movie(3, 'hi')],
        similar: [_movie(4, 'hi')],
        discovery: const [],
        limit: 2,
      );

      expect(result.map((movie) => movie.id), [2, 3]);
    });
  });
}
