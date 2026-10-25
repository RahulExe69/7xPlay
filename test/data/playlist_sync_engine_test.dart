import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/data/playlists/playlist.dart';
import 'package:flixquest/data/playlists/playlist_replay.dart';
import 'package:flixquest/data/playlists/playlist_store.dart';
import 'package:flixquest/data/repositories/playlist_repository.dart';
import 'package:flixquest/data/sync/playlist_sync_engine.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/provider/playlist_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_dio.dart';

const _list = '11111111-1111-4111-8111-111111111111';

PlaylistOperation _op(String id, String action,
        [Map<String, Object?> fields = const <String, Object?>{}]) =>
    PlaylistOperation(
        id: id, action: action, playlistId: _list, fields: fields);

Map<String, Object?> _title(int id, {String type = 'movie'}) =>
    <String, Object?>{'media_type': type, 'media_id': id, 'title': 'T$id'};

Map<String, Object?> _row(int id, int position,
        {String type = 'movie', bool deleted = false}) =>
    <String, Object?>{
      'playlist_id': _list,
      'media_type': type,
      'media_id': id,
      'position': position,
      'title': 'T$id',
      'genre_ids': <int>[10751],
      'deleted': deleted,
    };

Map<String, Object?> _answer({
  required int revision,
  bool full = false,
  List<String> answered = const <String>[],
  List<Map<String, Object?>>? lists,
  List<Map<String, Object?>> items = const <Map<String, Object?>>[],
  int? cursor,
}) =>
    <String, Object?>{
      'success': true,
      'server_revision': revision,
      'full': full,
      'results': <Map<String, Object?>>[
        for (final id in answered)
          <String, Object?>{'operation_id': id, 'status': 'applied'},
      ],
      'playlists': lists,
      'items': items,
      'next_cursor': cursor,
    };

Map<String, Object?> _listJson({int version = 1, bool deleted = false}) =>
    <String, Object?>{
      'id': _list,
      'name': 'Family night',
      'version': version,
      'deleted': deleted,
      'created_at': '2026-10-25T08:00:00.000000Z',
    };

void main() {
  late Directory dir;
  late PlaylistStore store;
  late FakeDioAdapter adapter;
  late Dio dio;
  late PlaylistSyncEngine engine;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = await Directory.systemTemp.createTemp('playlists-');
    store = await PlaylistStore.open(
        owner: 'user:1', directoryPath: '${dir.path}/');
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    engine = PlaylistSyncEngine(PlaylistRepository(dio));
  });

  tearDown(() async {
    await store.database.close();
    dio.close();
    await dir.delete(recursive: true);
  });

  group('replay', () {
    const record = PlaylistRecord(id: _list, name: 'Mine', version: 3);
    PlaylistEntry entry(int id, int position) => PlaylistEntry(
        playlistId: _list,
        mediaType: 'movie',
        mediaId: id,
        position: position,
        title: 'T$id');

    test('skips a rename Laravel would refuse for its old version', () {
      final lists = replayPlaylists(const <PlaylistRecord>[
        record
      ], const <PlaylistEntry>[], <PlaylistOperation>[
        _op('a', PlaylistOperation.update,
            <String, Object?>{'base_version': 2, 'name': 'Stale'}),
        _op('b', PlaylistOperation.update,
            <String, Object?>{'base_version': 3, 'name': 'Fresh'}),
        _op('c', PlaylistOperation.update,
            <String, Object?>{'base_version': 4, 'name': 'Fresher'}),
      ]);
      expect(lists.single.name, 'Fresher');
      expect(lists.single.version, 5);
    });

    test('keeps titles a reorder did not name after the ones it did', () {
      final lists = replayPlaylists(
        const <PlaylistRecord>[record],
        <PlaylistEntry>[entry(1, 0), entry(2, 1), entry(3, 2)],
        <PlaylistOperation>[
          _op('a', PlaylistOperation.add, _title(4)),
          _op('b', PlaylistOperation.reorder, <String, Object?>{
            'base_version': 3,
            'items': <Object>[_title(3), _title(1)],
          }),
        ],
      );
      expect(lists.single.entries.map((e) => e.mediaId), <int>[3, 1, 2, 4]);
    });

    test(
        'keeps a movie and a series with the same id apart and ignores a repeat',
        () {
      final lists = replayPlaylists(const <PlaylistRecord>[
        record
      ], const <PlaylistEntry>[], <PlaylistOperation>[
        _op('a', PlaylistOperation.add, _title(7)),
        _op('b', PlaylistOperation.add, _title(7, type: 'tv')),
        _op('c', PlaylistOperation.add, _title(7)),
      ]);
      expect(
          lists.single.entries.map((e) => e.key), <String>['movie:7', 'tv:7']);
    });

    test('drops a deleted list and ignores later edits to it', () {
      final lists = replayPlaylists(const <PlaylistRecord>[
        record
      ], <PlaylistEntry>[
        entry(1, 0)
      ], <PlaylistOperation>[
        _op('a', PlaylistOperation.delete),
        _op('b', PlaylistOperation.add, _title(2)),
      ]);
      expect(lists, isEmpty);
    });
  });

  test('sends waiting edits, applies the answer, and stores the checkpoint',
      () async {
    await store.enqueue(_op('op-1', PlaylistOperation.create,
        <String, Object?>{'name': 'Family night'}));
    await store.enqueue(_op('op-2', PlaylistOperation.add, _title(550)));
    adapter.enqueueJson(_answer(
      revision: 4,
      full: true,
      answered: <String>['op-1', 'op-2'],
      lists: <Map<String, Object?>>[_listJson()],
      items: <Map<String, Object?>>[_row(550, 0)],
    ));

    await engine.sync('user:1', store);

    final body = adapter.requests.single.data as Map;
    expect(body.containsKey('since_revision'), isFalse);
    expect((body['operations'] as List).map((op) => op['operation_id']),
        <String>['op-1', 'op-2']);
    expect(adapter.requests.single.extra['syncOwner'], 'user:1');
    expect(await store.pendingCount(), 0);
    expect(await store.checkpoint(), 4);
    final lists = await store.read();
    expect(lists.single.name, 'Family night');
    expect(lists.single.entries.single.genreIds, <int>[10751]);
  });

  test('keeps an edit made while the request was out and replays it', () async {
    await store.apply(
      full: true,
      revision: 2,
      lists: <PlaylistRecordChange>[
        PlaylistRecordChange(PlaylistRecord.fromJson(_listJson()))
      ],
      items: const <PlaylistEntryChange>[],
      answered: const <String>[],
    );
    await store.enqueue(_op('op-1', PlaylistOperation.add, _title(1)));
    adapter.enqueueJson(_answer(
      revision: 3,
      answered: <String>['op-1'],
      lists: const <Map<String, Object?>>[],
      items: <Map<String, Object?>>[_row(1, 0)],
    ));
    final running = engine.sync('user:1', store);
    await store.enqueue(_op('op-2', PlaylistOperation.add, _title(2)));
    await running;

    expect((adapter.requests.single.data as Map)['since_revision'], 2);
    final pending = await store.pending();
    expect(pending.map((op) => op.id), <String>['op-2']);
    expect(
        (await store.read()).single.entries.map((e) => e.mediaId), <int>[1, 2]);
  });

  test('applies a paged answer only once every page is in', () async {
    await store.apply(
      full: true,
      revision: 1,
      lists: <PlaylistRecordChange>[
        PlaylistRecordChange(PlaylistRecord.fromJson(_listJson()))
      ],
      items: <PlaylistEntryChange>[
        PlaylistEntryChange(PlaylistEntry.fromJson(_row(99, 0)))
      ],
      answered: const <String>[],
    );
    await store.resetCheckpoint();
    adapter
      ..enqueueJson(_answer(
        revision: 8,
        full: true,
        lists: <Map<String, Object?>>[_listJson(version: 2)],
        items: <Map<String, Object?>>[_row(1, 0)],
        cursor: 41,
      ))
      ..enqueueError();

    await expectLater(
        engine.sync('user:1', store), throwsA(isA<DioException>()));
    // The stale copy is untouched until a complete answer arrives.
    expect((await store.read()).single.entries.single.mediaId, 99);
    expect(await store.checkpoint(), isNull);

    adapter
      ..enqueueJson(_answer(
        revision: 8,
        full: true,
        lists: <Map<String, Object?>>[_listJson(version: 2)],
        items: <Map<String, Object?>>[_row(1, 0)],
        cursor: 41,
      ))
      ..enqueueJson(
          _answer(revision: 8, items: <Map<String, Object?>>[_row(2, 1)]));
    await engine.sync('user:1', store);

    final page = adapter.requests.last.data as Map;
    expect(page['cursor'], 41);
    expect(page['until_revision'], 8);
    expect(page.containsKey('operations'), isFalse);
    final list = (await store.read()).single;
    expect(list.version, 2);
    expect(list.entries.map((e) => e.mediaId), <int>[1, 2]);
    expect(await store.checkpoint(), 8);
  });

  test('removes a title and a whole list that a delta reports deleted',
      () async {
    await store.apply(
      full: true,
      revision: 2,
      lists: <PlaylistRecordChange>[
        PlaylistRecordChange(PlaylistRecord.fromJson(_listJson()))
      ],
      items: <PlaylistEntryChange>[
        PlaylistEntryChange(PlaylistEntry.fromJson(_row(1, 0))),
        PlaylistEntryChange(PlaylistEntry.fromJson(_row(2, 1))),
      ],
      answered: const <String>[],
    );
    adapter.enqueueJson(_answer(
        revision: 3,
        lists: const <Map<String, Object?>>[],
        items: <Map<String, Object?>>[_row(1, 0, deleted: true)]));
    await engine.sync('user:1', store);
    expect((await store.read()).single.entries.map((e) => e.mediaId), <int>[2]);

    adapter.enqueueJson(_answer(
        revision: 4, lists: <Map<String, Object?>>[_listJson(deleted: true)]));
    await engine.sync('user:1', store);
    expect(await store.read(), isEmpty);
    expect(await store.database.query('playlist_items'), isEmpty);
  });

  test('starts again from nothing when Laravel is behind the checkpoint',
      () async {
    await store.apply(
      full: true,
      revision: 50,
      lists: const <PlaylistRecordChange>[],
      items: const <PlaylistEntryChange>[],
      answered: const <String>[],
    );
    adapter
      ..enqueueJson(<String, Object?>{
        'success': false,
        'errors': <String, Object?>{
          'since_revision': <String>['Checkpoint is ahead of the server.']
        },
      }, statusCode: 422)
      ..enqueueJson(_answer(
          revision: 3, full: true, lists: <Map<String, Object?>>[_listJson()]));

    await engine.sync('user:1', store);

    expect((adapter.requests.last.data as Map).containsKey('since_revision'),
        isFalse);
    expect(await store.checkpoint(), 3);
    expect((await store.read()).single.name, 'Family night');
  });

  test('writes nothing for an account that is no longer signed in', () async {
    await store.enqueue(_op(
        'op-1', PlaylistOperation.create, <String, Object?>{'name': 'Mine'}));
    var current = true;
    adapter.enqueueJson(_answer(
        revision: 2,
        full: true,
        answered: <String>['op-1'],
        lists: <Map<String, Object?>>[_listJson()]));
    final running = engine.sync('user:1', store, isCurrent: () => current);
    current = false;
    await running;

    expect(await store.pendingCount(), 1);
    expect(await store.checkpoint(), isNull);
  });

  test("moves a guest's lists to the account once, however often it runs",
      () async {
    final guest = await PlaylistStore.open(
        owner: 'guest', directoryPath: '${dir.path}/g');
    await guest.enqueue(_op('op-1', PlaylistOperation.create,
        <String, Object?>{'name': 'Guest list'}));
    await guest.enqueue(_op('op-2', PlaylistOperation.add, _title(5)));
    final copy = await PlaylistStore.open(
        owner: 'guest', directoryPath: '${dir.path}/g');

    await guest.moveInto(store);
    await copy.moveInto(store);

    expect(
        (await store.pending()).map((op) => op.id), <String>['op-1', 'op-2']);
    expect(await guest.read(), isEmpty);
    expect((await store.read()).single.entries.single.mediaId, 5);
    await guest.database.close();
  });

  test('two renames before a sync carry the versions Laravel will be at',
      () async {
    final provider = PlaylistProvider(openStore: (_) async => store);
    await provider.load();
    final id = await provider.create('First',
        first: MediaItem.fromMovie(
            Movie(id: 9, title: 'Nine', genreIds: <int>[10751])));
    await provider.rename(id, 'Second');
    await provider.rename(id, 'Third');

    final pending = await store.pending();
    expect(pending.map((op) => op.action), <String>[
      PlaylistOperation.create,
      PlaylistOperation.add,
      PlaylistOperation.update,
      PlaylistOperation.update,
    ]);
    expect(pending[1].fields['genre_ids'], <int>[10751]);
    expect(pending[2].fields['base_version'], 1);
    expect(pending[3].fields['base_version'], 2);
    expect(provider.byId(id)!.name, 'Third');
    await expectLater(
        provider.create('   '), throwsA(isA<PlaylistEditException>()));
  });
}
