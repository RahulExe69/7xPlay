import 'dart:convert';
import 'dart:io';

import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/media_search.dart';
import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/functions/tmdb_request.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
    TMDB_API_KEY = 'proxy-search-test-key';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  tearDown(() => TMDB_API_KEY = '');

  test('direct requests are preserved when the proxy is off or missing', () {
    const url =
        'https://api.themoviedb.org/3/search/movie?query=Dune&api_key=k';
    expect(tmdbRequestUri(url, false, 'https://proxy.example').toString(), url);
    expect(tmdbRequestUri(url, true, '').toString(), url);
  });

  test('proxy parameters and the complete destination survive wrapping', () {
    const url = 'https://api.themoviedb.org/3/search/movie?'
        'query=A%26B%2BC%23D%25&include_adult=true&language=fr-FR&api_key=k';
    final request = tmdbRequestUri(
      url,
      true,
      'https://proxy.example/tmdb?region=eu&tag=a&tag=b',
    );
    expect(request.path, '/tmdb');
    expect(request.queryParameters['region'], 'eu');
    expect(request.queryParametersAll['tag'], <String>['a', 'b']);
    expect(request.queryParameters['destination'], url);
    expect(request.queryParameters.containsKey('api_key'), isFalse);
    final destination = Uri.parse(request.queryParameters['destination']!);
    expect(destination.queryParameters['query'], 'A&B+C#D%');
  });

  for (final query in <String>[
    'Dune',
    '  The Dark Knight  ',
    'Love & Other Drugs + #1 100%',
    'Amélie 千と千尋',
  ]) {
    test('mobile and TV search through the proxy: $query', () async {
      // Decode destination once, as the proxy does, then parse the TMDB URL.
      // An unescaped wrapper loses the API key and corrupts reserved characters.
      final requests = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final destination = request.uri.queryParameters['destination'];
        final target = destination == null ? null : Uri.tryParse(destination);
        if (target == null) {
          request.response.statusCode = 400;
        } else {
          requests.add(target);
          if (target.queryParameters['api_key'] != 'proxy-search-test-key') {
            request.response.statusCode = 401;
          } else {
            request.response.write(jsonEncode(<String, dynamic>{
              'results': <Object>[
                <String, dynamic>{
                  'id': 1,
                  'title': target.queryParameters['query'],
                  'name': target.queryParameters['query'],
                },
              ],
            }));
          }
        }
        await request.response.close();
      });

      final settings = SettingsProvider()
        ..enableProxy = true
        ..isAdult = true
        ..appLanguage = 'fr-FR';
      final dependencies = AppDependencyProvider()
        ..tmdbProxy = Platform.environment['TMDB_PROXY_TEST_URL'] ??
            'http://127.0.0.1:${server.port}/';
      addTearDown(settings.dispose);
      addTearDown(dependencies.dispose);

      final mobile = await MediaSearch.run(
        TmdbSearchSource(settings: settings, dependencies: dependencies),
        query,
      );
      expect(mobile.movies.single.title, query.trim());
      expect(mobile.series.single.title, query.trim());
      expect(mobile.people.single.name, query.trim());

      final tv = await const CatalogController().search(
        query: query,
        settings: settings,
        dependencies: dependencies,
      );
      expect(tv, hasLength(2));
      expect(tv.map((item) => item.title), everyElement(query.trim()));

      if (!Platform.environment.containsKey('TMDB_PROXY_TEST_URL')) {
        expect(requests, hasLength(5));
        expect(
            requests.map((uri) => uri.path),
            containsAll(<String>[
              '/3/search/movie',
              '/3/search/tv',
              '/3/search/person',
            ]));
        for (final request in requests) {
          expect(request.host, 'api.themoviedb.org');
          expect(request.queryParameters['query'], query.trim());
          expect(request.queryParameters['include_adult'], 'true');
          expect(request.queryParameters['language'], 'fr-FR');
        }
      }
    });
  }
}
