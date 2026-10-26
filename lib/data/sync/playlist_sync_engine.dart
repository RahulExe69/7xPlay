import 'package:dio/dio.dart';

import '../playlists/playlist_store.dart';
import '../repositories/playlist_repository.dart';
import 'sync_transport.dart';

/// Sends the waiting playlist edits and brings the confirmed copy up to date.
///
/// Every page of Laravel's answer is read before anything is written, and
/// then all of it lands in one transaction with the new checkpoint. A sync
/// cut short by a sign-out or a dropped connection leaves the store as it
/// was; its edits are sent again next time and Laravel answers them from its
/// log instead of applying them twice.
class PlaylistSyncEngine {
  PlaylistSyncEngine(this.repository);

  final PlaylistRepository repository;

  /// Returns whether edits are still waiting, as when more were queued than
  /// one request takes.
  Future<bool> sync(String owner, PlaylistStore store,
      {bool Function()? isCurrent}) async {
    bool current() => isCurrent == null || isCurrent();
    final operations =
        await store.pending(limit: PlaylistRepository.maxOperations);
    var since = await store.checkpoint();
    if (!current()) return false;

    PlaylistSyncPage first;
    try {
      first = await repository.sync(
          owner: owner, operations: operations, since: since);
    } on DioException catch (error) {
      if (!SyncTransport.revisionAhead(error)) rethrow;
      // Laravel was restored from an older copy: start again from nothing.
      since = null;
      first = await repository.sync(owner: owner, operations: operations);
    }
    final lists = [...first.lists];
    final items = [...first.items];
    var cursor = first.nextCursor;
    while (cursor != null) {
      if (!current()) return false;
      final page = await repository.sync(
          owner: owner, since: since, until: first.revision, cursor: cursor);
      items.addAll(page.items);
      cursor = page.nextCursor;
    }
    if (!current()) return false;

    await store.apply(
      full: first.full,
      revision: first.revision,
      lists: lists,
      items: items,
      answered: first.answered,
    );
    return await store.pendingCount() > 0 &&
        operations.length >= PlaylistRepository.maxOperations;
  }
}
