import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/season_source.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/data/ads/content_ads.dart';
import 'package:flixquest/mobile/screens/episode_screen.dart';
import 'package:flixquest/mobile/screens/season_screen.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/images.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/videos.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _locales = <Locale>[
  Locale('en'),
  Locale('es'),
  Locale('ar'),
  Locale('hi'),
];

class _FileLoader extends AssetLoader {
  const _FileLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

final _series = MediaItem.fromSeries(
  TV(
    id: 77,
    name: 'Signal',
    firstAirDate: '2020-01-01',
    overview: 'A mystery connects two timelines.',
  ),
);

final _season = Seasons(
  seasonNumber: 1,
  name: 'Season 1',
  airDate: '2020-01-01',
  episodeCount: 2,
  overview: 'The first season.',
);

final _first = EpisodeList(
  seasonNumber: 1,
  episodeNumber: 1,
  episodeId: 701,
  name: 'The Beginning',
  airDate: '2020-01-03',
  runtime: 48,
  overview: 'A signal appears.',
);

final _future = EpisodeList(
  seasonNumber: 1,
  episodeNumber: 2,
  episodeId: 702,
  name: 'The Future',
  airDate: '2030-01-03',
  runtime: 49,
  overview: 'The signal returns.',
);

class _SeasonSource implements SeasonSource {
  _SeasonSource({this.failEpisodes = false});

  bool failEpisodes;
  final List<int> episodeRequests = <int>[];

  @override
  Future<TVDetails> series(int seriesId) async =>
      TVDetails(seasons: <Seasons>[_season]);

  @override
  Future<List<Genres>> genres(int seriesId) async =>
      <Genres>[Genres(genreID: 18, genreName: 'Drama')];

  @override
  Future<List<EpisodeList>> episodes(int seriesId, int season) async {
    episodeRequests.add(season);
    if (failEpisodes) throw Exception('offline');
    return <EpisodeList>[_first, _future];
  }

  @override
  Future<Credits> seasonCredits(int seriesId, int season) async => Credits();

  @override
  Future<Images> seasonImages(int seriesId, int season) async => Images();

  @override
  Future<Videos> seasonVideos(int seriesId, int season) async => Videos();

  @override
  Future<EpisodeList> episode(int seriesId, int season, int episode) async =>
      episode == 1 ? _first : _future;

  @override
  Future<Credits> episodeCredits(
    int seriesId,
    int season,
    int episode,
  ) async =>
      Credits();

  @override
  Future<Images> episodeImages(
    int seriesId,
    int season,
    int episode,
  ) async =>
      Images();
}

Widget _app(Widget home) => EasyLocalization(
      supportedLocales: _locales,
      startLocale: _locales.first,
      fallbackLocale: _locales.first,
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _FileLoader(),
      child: Builder(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(),
            ),
            ChangeNotifierProvider<AppDependencyProvider>(
              create: (_) => AppDependencyProvider()
                ..displayWatchNowButton = true
                ..displayDownloadButton = true,
            ),
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: ThemeData.dark(useMaterial3: true),
              home: home,
            ),
          ),
        ),
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  ContentAds.reset();
  ContentAds.lookup = (_, __) async => <int>[18];

  await tester.pumpWidget(_app(home));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    await EasyLocalization.ensureInitialized();
  });

  tearDown(ContentAds.reset);

  testWidgets(
    'season page opens an unaired episode without offering Play or Download',
    (tester) async {
      final source = _SeasonSource();
      await _pump(
        tester,
        SeasonScreen(
          series: _series,
          seasons: <Seasons>[_season],
          seasonNumber: 1,
          source: source,
          now: () => DateTime(2026, 11, 20),
          adBuilder: (_) => const SizedBox.shrink(),
        ),
      );

      expect(find.text('1. The Beginning'), findsOneWidget);
      expect(find.text('2. The Future'), findsOneWidget);
      await tester.ensureVisible(find.text('2. The Future'));
      await tester.tap(find.text('2. The Future'));
      await tester.pumpAndSettle();

      expect(find.byType(EpisodeScreen), findsOneWidget);
      expect(find.text('The Future'), findsWidgets);
      expect(find.text('Play'), findsNothing);
      expect(find.text('Download'), findsNothing);
      expect(find.byTooltip('Download episode'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('season episode failure offers Retry and reloads the list',
      (tester) async {
    final source = _SeasonSource(failEpisodes: true);
    await _pump(
      tester,
      SeasonScreen(
        series: _series,
        seasons: <Seasons>[_season],
        seasonNumber: 1,
        source: source,
        now: () => DateTime(2026, 11, 20),
        adBuilder: (_) => const SizedBox.shrink(),
      ),
    );

    expect(find.text("Episodes couldn't be loaded."), findsOneWidget);
    source.failEpisodes = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(source.episodeRequests, <int>[1, 1]);
    expect(find.text('1. The Beginning'), findsOneWidget);
    expect(find.text('2. The Future'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'episode screen keeps its season context in a narrow RTL layout',
    (tester) async {
      await _pump(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.3),
            ),
            child: EpisodeScreen(
              series: _series,
              episode: _first,
              seasonEpisodes: <EpisodeList>[_first, _future],
              seasons: <Seasons>[_season],
              source: _SeasonSource(),
              now: () => DateTime(2026, 11, 20),
              adBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
        size: const Size(320, 700),
      );

      expect(find.text('The Beginning'), findsWidgets);
      expect(find.text('1. The Beginning'), findsOneWidget);
      // The adjacent episode remains available in the season context;
      // navigation from the season page is covered by the first test.
      expect(find.text('2. The Future'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
