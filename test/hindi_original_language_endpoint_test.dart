import 'package:flixquest/api/endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hindi-origin discovery is separate from the metadata display language', () {
    final url = Endpoints.discoverMoviesByOriginalLanguageUrl(
      'en-US',
      originalLanguage: 'hi',
      genreIds: [18, 28, 18],
      includeAdult: false,
    );

    expect(url, contains('language=en-US'));
    expect(url, contains('with_original_language=hi'));
    expect(url, contains('with_genres=18|28'));
    expect(url, contains('include_adult=false'));
  });

  test('Hindi-origin discovery supports a broad fallback without genres', () {
    final url = Endpoints.discoverMoviesByOriginalLanguageUrl(
      'hi-IN',
      originalLanguage: 'hi',
    );

    expect(url, contains('language=hi-IN'));
    expect(url, contains('with_original_language=hi'));
    expect(url, isNot(contains('with_genres=')));
  });
}
