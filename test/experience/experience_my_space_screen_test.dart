import 'package:flixquest/catalog/up_next.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/provider/offline_download_provider.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/screens/experience_my_space_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Recent extends RecentProvider {
  @override
  List<RecentMovie> get movies => const [];
  @override
  List<RecentEpisode> get episodes => const [];
  @override
  List<UpNext> get upNext => const [];
  @override
  Future<void> fetchMovies() async {}
  @override
  Future<void> fetchEpisodes() async {}
}

class _Bookmarks extends BookmarkProvider {
  @override
  List<Movie> get movies => const [];
  @override
  List<TV> get tvShows => const [];
  @override
  bool get isLoading => false;
  @override
  Future<void> fetchBookmarks() async {}
}

class _Offline extends OfflineDownloadProvider {
  @override
  List<OfflineDownload> get downloads => const [];
  @override
  bool get loading => false;
  @override
  Future<void> refresh() async {}
}

Widget _app(Widget child) {
  final theme = ThemeData.dark();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<RecentProvider>.value(value: _Recent()),
      ChangeNotifierProvider<BookmarkProvider>.value(value: _Bookmarks()),
      ChangeNotifierProvider<OfflineDownloadProvider>.value(value: _Offline()),
    ],
    child: MaterialApp(
      theme: theme.copyWith(extensions: <ThemeExtension<dynamic>>[
        ExperienceThemeExtension(palette: ExperiencePalette.fromTheme(theme)),
      ]),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('shows the personal library dashboard and feature shortcuts',
      (tester) async {
    await tester.pumpWidget(_app(const ExperienceMySpaceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('My Space'), findsOneWidget);
    expect(find.text('Your space'), findsOneWidget);
    expect(find.text('My List'), findsOneWidget);
    expect(find.text('Downloads'), findsWidgets);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('7x AI'), findsOneWidget);
    expect(find.text('Account & app'), findsOneWidget);
  });

  testWidgets('provides guest access without requiring a sign-in session',
      (tester) async {
    await tester.pumpWidget(_app(const ExperienceMySpaceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Guest profile'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
