import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/new_and_hot.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/screens/experience_new_and_hot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _HotSource implements NewAndHotSource {
  MediaItem item(int id, String title) => MediaItem(
    kind: MediaKind.movie, id: id, title: title,
    overview: 'A new story to discover.',
    posterPath: null, backdropPath: null, rating: 8.2,
    releaseDate: '2026-12-01',
  );

  @override
  Future<List<MediaItem>> upcomingMovies() async => [item(1, 'December Premiere')];
  @override
  Future<List<MediaItem>> seriesPremieres(DateTime today) async => const [];
  @override
  Future<List<MediaItem>> trending(MediaKind kind) async =>
      [item(kind == MediaKind.movie ? 2 : 3,
        kind == MediaKind.movie ? 'Trending Movie' : 'Trending Series')];
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
  testWidgets('renders editorial upcoming releases from the catalog contract',
      (tester) async {
    await tester.pumpWidget(_app(ExperienceNewAndHotScreen(
      source: _HotSource(),
      now: () => DateTime(2026, 11, 22),
    )));
    await tester.pumpAndSettle();

    expect(find.text('New & Hot'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('December Premiere'), findsWidgets);
    expect(find.text('FIRST LOOK'), findsOneWidget);
  });

  testWidgets('switches to a trending editorial ranking', (tester) async {
    await tester.pumpWidget(_app(ExperienceNewAndHotScreen(
      source: _HotSource(),
      now: () => DateTime(2026, 11, 22),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();

    expect(find.text('Everyone is watching'), findsOneWidget);
    expect(find.text('Trending Movie'), findsWidgets);
  });
}
