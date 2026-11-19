import 'package:flixquest/data/playlists/playlist.dart';
import 'package:flixquest/mobile/screens/playlists_screen.dart';
import 'package:flixquest/mobile/widgets/page_kit.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/playlist_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakePlaylists extends PlaylistProvider {
  _FakePlaylists(this._lists);

  final List<Playlist> _lists;

  @override
  List<Playlist> get lists => _lists;

  @override
  bool get loaded => true;

  @override
  Future<bool> sync() async => false;
}

Playlist _playlist(String id, String name, {int count = 4}) {
  return Playlist(
    PlaylistRecord(
      id: id,
      name: name,
      description: 'A personal collection',
    ),
    <PlaylistEntry>[
      for (var i = 0; i < count; i++)
        PlaylistEntry(
          playlistId: id,
          mediaType: i.isEven ? 'movie' : 'tv',
          mediaId: i + 1,
          position: i,
          title: '$name title ${i + 1}',
        ),
    ],
  );
}

Future<void> _pumpPlaylists(
  WidgetTester tester, {
  required List<Playlist> lists,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<AppDependencyProvider>(
          create: (_) => AppDependencyProvider(),
        ),
        ChangeNotifierProvider<PlaylistProvider>.value(
          value: _FakePlaylists(lists),
        ),
      ],
      child: const MaterialApp(home: PlaylistsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows custom lists as artwork-led gallery cards',
      (tester) async {
    await _pumpPlaylists(
      tester,
      lists: <Playlist>[
        _playlist('one', 'Weekend picks'),
        _playlist('two', 'Anime marathon', count: 2),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Weekend picks'), findsOneWidget);
    expect(find.text('Anime marathon'), findsOneWidget);
    expect(find.byType(ListRow), findsNothing);

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      grid.gridDelegate,
      isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
    );
    expect(
      (grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent)
          .maxCrossAxisExtent,
      230,
    );
  });

  testWidgets('keeps the deliberate empty state when no lists exist',
      (tester) async {
    await _pumpPlaylists(tester, lists: const <Playlist>[]);

    expect(tester.takeException(), isNull);
    expect(find.text('playlists_empty_title'), findsOneWidget);
    expect(find.text('playlist_new'), findsOneWidget);
    expect(find.text('playlist_import'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });
}
