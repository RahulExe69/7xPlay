import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/media_search.dart';
import 'package:flixquest/models/person.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/screens/experience_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchSource implements SearchSource {
  MediaItem title(String name, int id) => MediaItem(
    kind: MediaKind.movie, id: id, title: name,
    overview: 'A search result.',
    posterPath: null, backdropPath: null, rating: 8.5,
    releaseDate: '2026-01-01',
  );
  @override
  Future<List<MediaItem>> movies(String query) async =>
      [title('Moonfall', 1), title('Moonlight', 2)];
  @override
  Future<List<MediaItem>> series(String query) async => const [];
  @override
  Future<List<Person>> people(String query) async =>
      [Person(id: 5, name: 'Luna Star', department: 'Acting')];
}

class _Preferences extends SettingsPreferences {
  final List<String> values = [];
  @override
  Future<List<String>> getRecentSearches() async => List.of(values);
  @override
  Future<void> addRecentSearch(String searchTerm) async {
    values.remove(searchTerm);
    values.insert(0, searchTerm);
  }
  @override
  Future<void> removeRecentSearch(String searchTerm) async {
    values.remove(searchTerm);
  }
  @override
  Future<void> clearRecentSearches() async => values.clear();
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
  testWidgets('shows the search start state and popular suggestions',
      (tester) async {
    await tester.pumpWidget(_app(ExperienceSearchScreen(
      source: _SearchSource(),
      loadSuggestions: () async => const SearchSuggestions.empty,
      preferences: _Preferences(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('FIND YOUR NEXT STORY'), findsOneWidget);
    expect(find.text('Popular right now'), findsOneWidget);
  });

  testWidgets('runs a query through the existing multi-kind search service',
      (tester) async {
    await tester.pumpWidget(_app(ExperienceSearchScreen(
      source: _SearchSource(),
      loadSuggestions: () async => const SearchSuggestions.empty,
      preferences: _Preferences(),
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Moonfall');
    tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('BEST MATCH'), findsOneWidget);
    expect(find.text('Moonfall'), findsWidgets);
    expect(find.text('Titles 2'), findsOneWidget);
  });
}
