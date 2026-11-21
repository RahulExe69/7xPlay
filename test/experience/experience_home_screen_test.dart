import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/screens/experience_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _HomeSource implements HomeFeedSource {
  static MediaItem _item(int id, String title) => MediaItem(
    kind: MediaKind.movie, id: id, title: title,
    overview: 'A featured story for the new home.',
    posterPath: '/poster$id.jpg', backdropPath: '/backdrop$id.jpg',
    rating: 8.4, releaseDate: '2026-01-01',
  );

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async {
    if (kind != MediaKind.movie) return const <MediaItem>[];
    final item = switch (list) {
      HomeList.trendingToday => _item(7, 'The 7x Feature'),
      HomeList.trendingWeek => _item(8, 'Trending Feature'),
      HomeList.popular => _item(9, 'Popular Feature'),
      HomeList.newReleases => _item(10, 'New Feature'),
      HomeList.topRated => _item(11, 'Rated Feature'),
      HomeList.upcoming => _item(12, 'Upcoming Feature'),
    };
    return <MediaItem>[item];
  }

  @override
  Future<List<MediaItem>> discover(MediaKind kind, {required int page, required int year, required int genreId}) async =>
      kind == MediaKind.movie ? <MediaItem>[_item(20, 'Spotlight Feature')] : const <MediaItem>[];
  @override
  Future<List<MediaItem>> genre(MediaKind kind, int genreId) async => const [];
  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) async => const [];
  @override
  Future<List<Genres>> genres(MediaKind kind) async => const [];
}

Widget _app(Widget child) {
  final theme = ThemeData.dark();
  return MaterialApp(
    theme: theme.copyWith(extensions: <ThemeExtension<dynamic>>[
      ExperienceThemeExtension(palette: ExperiencePalette.fromTheme(theme)),
    ]),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('builds a new featured home from the existing feed contract', (tester) async {
    await tester.pumpWidget(_app(ExperienceHomeScreen(source: _HomeSource())));
    await tester.pumpAndSettle();
    expect(find.text('7xPlay'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Trending Feature'), findsWidgets);
    expect(find.text('SPOTLIGHT'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -560));
    await tester.pumpAndSettle();
    expect(find.text('Trending now'), findsOneWidget);
  });

  testWidgets('switches between movie and series feed filters', (tester) async {
    await tester.pumpWidget(_app(ExperienceHomeScreen(source: _HomeSource())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Trending Feature'), findsWidgets);
    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to show just yet'), findsOneWidget);
  });
}
