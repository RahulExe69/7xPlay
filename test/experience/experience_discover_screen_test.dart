import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/screens/experience_discover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DiscoverSource implements HomeFeedSource {
  MediaItem item(int id, String title) => MediaItem(
    kind: MediaKind.movie, id: id, title: title, overview: 'A test title.',
    posterPath: null, backdropPath: null, rating: 8.1,
    releaseDate: '2026-01-01',
  );

  @override
  Future<List<Genres>> genres(MediaKind kind) async => [
    Genres(genreID: 28, genreName: 'Action'),
    Genres(genreID: 18, genreName: 'Drama'),
  ];
  @override
  Future<List<MediaItem>> genre(MediaKind kind, int genreId) async =>
      [item(genreId, genreId == 28 ? 'Action Feature' : 'Drama Feature')];
  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async => const [];
  @override
  Future<List<MediaItem>> discover(MediaKind kind, {
    required int page, required int year, required int genreId,
  }) async => const [];
  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) async =>
      const [];
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
  testWidgets('loads genres and shows titles for the selected genre',
      (tester) async {
    await tester.pumpWidget(_app(
      ExperienceDiscoverScreen(source: _DiscoverSource()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Choose your mood'), findsOneWidget);
    expect(find.text('Action'), findsWidgets);
    expect(find.text('Action Feature'), findsOneWidget);

    await tester.tap(find.text('Drama').first);
    await tester.pumpAndSettle();

    expect(find.text('Explore Drama'), findsOneWidget);
    expect(find.text('Drama Feature'), findsOneWidget);
  });

  testWidgets('switches between movie and series genre catalogs',
      (tester) async {
    await tester.pumpWidget(_app(
      ExperienceDiscoverScreen(source: _DiscoverSource()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Action'), findsWidgets);
  });
}
