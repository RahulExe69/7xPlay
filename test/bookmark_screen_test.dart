import 'package:flixquest/mobile/app/mobile_tabs.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/screens/common/bookmark_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeBookmarks extends ChangeNotifier implements BookmarkProvider {
  _FakeBookmarks({this.movies = const <Movie>[], this.tvShows = const <TV>[]});

  @override
  final List<Movie> movies;

  @override
  final List<TV> tvShows;

  @override
  bool get isLoading => false;

  @override
  bool isMovieBookmarked(int id) => movies.any((movie) => movie.id == id);

  @override
  bool isTVBookmarked(int id) => tvShows.any((show) => show.id == id);

  @override
  Future<void> fetchBookmarks() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  required List<Movie> movies,
  required List<TV> series,
  required MobileTabController tabs,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MobileTabScope(
      controller: tabs,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppDependencyProvider>(
            create: (_) => AppDependencyProvider(),
          ),
          ChangeNotifierProvider<BookmarkProvider>.value(
            value: _FakeBookmarks(movies: movies, tvShows: series),
          ),
        ],
        child: const MaterialApp(home: BookmarkScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('My List has a useful empty state that opens Discover',
      (tester) async {
    final tabs = MobileTabController(initial: MobileTab.mine);
    await _pump(
      tester,
      movies: const <Movie>[],
      series: const <TV>[],
      tabs: tabs,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('my_list'), findsOneWidget);
    expect(find.text('no_movies_bookmarked'), findsOneWidget);
    expect(find.text('my_list_empty_hint'), findsOneWidget);
    expect(find.text('discover'), findsOneWidget);

    await tester.tap(find.text('discover'));
    await tester.pumpAndSettle();
    expect(tabs.current, MobileTab.discover);
    expect(tester.takeException(), isNull);
    tabs.dispose();
  });

  testWidgets('shows saved titles in the responsive poster grid',
      (tester) async {
    final tabs = MobileTabController(initial: MobileTab.mine);
    await _pump(
      tester,
      movies: <Movie>[
        Movie(id: 1, title: 'Saved film'),
        Movie(id: 2, title: 'Another film'),
      ],
      series: <TV>[
        TV(id: 3, name: 'Saved series', originalName: 'Saved series'),
      ],
      tabs: tabs,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
    await tester.tap(find.text('tv_series'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
    tabs.dispose();
  });
}
