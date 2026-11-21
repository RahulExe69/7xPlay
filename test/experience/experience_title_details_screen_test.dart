import 'package:flixquest/catalog/details_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/screens/experience_title_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _movie() => const MediaItem(
  kind: MediaKind.movie,
  id: 15,
  title: 'The Last Signal',
  overview: 'A rescue crew receives a message from a lost station.',
  posterPath: null,
  backdropPath: null,
  rating: 8.4,
  releaseDate: '2025-03-14',
);

Widget _app(Widget child) {
  final theme = ThemeData.dark();
  return MaterialApp(
    theme: theme.copyWith(extensions: <ThemeExtension<dynamic>>[
      ExperienceThemeExtension(palette: ExperiencePalette.fromTheme(theme)),
    ]),
    home: child,
  );
}

void main() {
  testWidgets('renders full-screen title details and loads extended metadata',
      (tester) async {
    final item = _movie();
    var played = false;
    await tester.pumpWidget(_app(ExperienceTitleDetailsScreen(
      item: item,
      loadDetails: (value) async => MediaDetailsData(
        item: value,
        movieDetails: MovieDetails(
          runtime: 132,
          tagline: 'Every signal has a price.',
          status: 'Released',
        ),
        recommendations: const [],
      ),
      onPlay: (_) async => played = true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('The Last Signal'), findsOneWidget);
    expect(find.text('Every signal has a price.'), findsOneWidget);
    expect(find.text('132m'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text(item.overview), findsOneWidget);
    expect(find.text('Add to My List'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(played, isTrue);
  });

  testWidgets('renders series seasons and recommendations', (tester) async {
    const item = MediaItem(
      kind: MediaKind.series,
      id: 24,
      title: 'Night Shift',
      overview: 'A city never sleeps.',
      posterPath: null,
      backdropPath: null,
      rating: 9,
      releaseDate: '2024-01-01',
    );
    await tester.pumpWidget(_app(ExperienceTitleDetailsScreen(
      item: item,
      canPlay: false,
      loadDetails: (value) async => MediaDetailsData(
        item: value,
        seriesDetails: TVDetails(
          numberOfSeasons: 2,
          status: 'Returning Series',
          seasons: [
            Seasons(name: 'Season 1', seasonNumber: 1, episodeCount: 8),
            Seasons(name: 'Season 2', seasonNumber: 2, episodeCount: 10),
          ],
        ),
        recommendations: [_movie()],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Seasons'), findsOneWidget);
    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('10 episodes'), findsOneWidget);
    expect(find.text('You may also like'), findsOneWidget);
    expect(find.text('The Last Signal'), findsOneWidget);
  });
}
