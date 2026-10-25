import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../sync/library_scope.dart';
import 'playlist.dart';
import 'playlist_replay.dart';

/// One account's custom lists on this device, in their own database file
/// beside the bookmark ones, so My List's tables are never touched.
///
/// It keeps three things apart: the lists as Laravel last confirmed them,
/// the edits made since that it has not answered yet, and the revision the
/// confirmed copy is at. A sync replaces the first and third together and
/// drops the answered edits in the same transaction, so a crash can never
/// leave an edit both applied and still queued, or the checkpoint ahead of
/// the rows it describes.
class PlaylistStore {
  PlaylistStore(this.database);

  final Database database;

  static final Map<String, Future<PlaylistStore>> _stores = {};

  static const _lists = 'playlists';
  static const _items = 'playlist_items';
  static const _queue = 'playlist_operations';
  static const _meta = 'playlist_meta';
  static const _checkpointKey = 'checkpoint';

  /// The store for [owner], opened once per run.
  static Future<PlaylistStore> forOwner(String owner) {
    final key = LibraryScope.enabled ? owner : 'legacy';
    return _stores.putIfAbsent(key, () => open(owner: owner));
  }

  static Future<PlaylistStore> open(
      {required String owner, String? directoryPath}) async {
    final directory = directoryPath == null
        ? await getApplicationDocumentsDirectory()
        : Directory(directoryPath);
    final path = LibraryScope.filename('${directory.path}playlists.db', owner);
    return PlaylistStore(
        await openDatabase(path, version: 1, onCreate: _create));
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('CREATE TABLE $_lists(id TEXT PRIMARY KEY, name TEXT, '
        'description TEXT, version INTEGER, source_provider TEXT, '
        'source_id TEXT, created_at TEXT)');
    await db.execute('CREATE TABLE $_items(playlist_id TEXT, media_type TEXT, '
        'media_id INTEGER, position INTEGER, title TEXT, poster_path TEXT, '
        'backdrop_path TEXT, vote_average REAL, release_date TEXT, '
        'genre_ids TEXT, added_at TEXT, '
        'PRIMARY KEY(playlist_id, media_type, media_id))');
    await db.execute('CREATE TABLE $_queue(seq INTEGER PRIMARY KEY '
        'AUTOINCREMENT, operation_id TEXT UNIQUE, body TEXT)');
    await db.execute('CREATE TABLE $_meta(key TEXT PRIMARY KEY, value TEXT)');
  }

  /// The lists as they should look now.
  Future<List<Playlist>> read() async {
    final lists = await database.query(_lists);
    final items = await database.query(_items);
    return replayPlaylists(
      lists.map(PlaylistRecord.fromRow),
      items.map(PlaylistEntry.fromRow),
      await pending(),
    );
  }

  /// Saves [operation] before the screen shows it, so an edit survives the
  /// app closing before it reaches Laravel.
  Future<void> enqueue(PlaylistOperation operation) => database.insert(
        _queue,
        <String, Object?>{
          'operation_id': operation.id,
          'body': operation.encode()
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  /// Waiting edits, oldest first.
  Future<List<PlaylistOperation>> pending({int? limit}) async {
    final rows = await database.query(_queue, orderBy: 'seq', limit: limit);
    return rows
        .map((row) => PlaylistOperation.decode(row['body'] as String))
        .toList(growable: false);
  }

  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM $_queue')) ??
      0;

  /// The revision the confirmed copy is at; null before the first sync.
  Future<int?> checkpoint() async {
    final rows = await database.query(_meta,
        where: 'key = ?', whereArgs: <Object?>[_checkpointKey], limit: 1);
    return rows.isEmpty ? null : int.tryParse('${rows.first['value']}');
  }

  /// Applies one complete answer from Laravel: every page of it.
  ///
  /// A [full] answer is the whole confirmed state, so it replaces what is
  /// here; otherwise only the lists and titles it names change, a deleted
  /// list taking its titles with it. [answered] are the edits Laravel took or
  /// refused, which stop being replayed either way.
  Future<void> apply({
    required bool full,
    required int revision,
    required List<PlaylistRecordChange> lists,
    required List<PlaylistEntryChange> items,
    required Iterable<String> answered,
  }) async {
    await database.transaction((txn) async {
      if (full) {
        await txn.delete(_lists);
        await txn.delete(_items);
      }
      for (final change in lists) {
        if (change.deleted) {
          await txn.delete(_lists,
              where: 'id = ?', whereArgs: <Object?>[change.record.id]);
          await txn.delete(_items,
              where: 'playlist_id = ?', whereArgs: <Object?>[change.record.id]);
        } else {
          await txn.insert(_lists, change.record.toRow(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final change in items) {
        final entry = change.entry;
        if (change.deleted) {
          await txn.delete(_items,
              where: 'playlist_id = ? AND media_type = ? AND media_id = ?',
              whereArgs: <Object?>[
                entry.playlistId,
                entry.mediaType,
                entry.mediaId
              ]);
        } else {
          await txn.insert(_items, entry.toRow(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final id in answered) {
        await txn.delete(_queue,
            where: 'operation_id = ?', whereArgs: <Object?>[id]);
      }
      await txn.insert(
        _meta,
        <String, Object?>{'key': _checkpointKey, 'value': '$revision'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Forgets the checkpoint, so the next sync asks for everything.
  Future<void> resetCheckpoint() => database
      .delete(_meta, where: 'key = ?', whereArgs: <Object?>[_checkpointKey]);

  /// Hands a guest's lists to the account they signed in to: their edits are
  /// queued there and replayed to Laravel like any other. Copying is keyed by
  /// edit id, so a merge interrupted and run again adds nothing twice.
  Future<void> moveInto(PlaylistStore account) async {
    final operations = await pending();
    if (operations.isEmpty) return;
    await account.database.transaction((txn) async {
      for (final operation in operations) {
        await txn.insert(
          _queue,
          <String, Object?>{
            'operation_id': operation.id,
            'body': operation.encode()
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    await clear();
  }

  Future<void> clear() async {
    await database.transaction((txn) async {
      for (final table in <String>[_lists, _items, _queue, _meta]) {
        await txn.delete(table);
      }
    });
  }
}

class PlaylistRecordChange {
  const PlaylistRecordChange(this.record, {this.deleted = false});

  final PlaylistRecord record;
  final bool deleted;
}

class PlaylistEntryChange {
  const PlaylistEntryChange(this.entry, {this.deleted = false});

  final PlaylistEntry entry;
  final bool deleted;
}
