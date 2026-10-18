import 'package:flutter/foundation.dart';
import '../data/sync/sync_runtime.dart';
import '../data/sync/sync_runner.dart';
import '../data/sync/library_scope.dart';

enum SyncStatus { idle, syncing, success, error }

/// Adapts Laravel's sync runner to existing provider and player callbacks.
class BookmarkSyncService {
  BookmarkSyncService._();
  static final instance = BookmarkSyncService._();
  final statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.idle);
  final lastSyncedNotifier = ValueNotifier<DateTime?>(null);
  SyncRunner? _runner;

  void _bind() {
    final next =
        SyncRuntime.enabled ? SyncRuntime.coordinator?.bookmarks : null;
    if (identical(next, _runner)) return;
    _runner?.status.removeListener(_onStatus);
    _runner?.lastSynced.removeListener(_onSynced);
    _runner = next;
    next?.status.addListener(_onStatus);
    next?.lastSynced.addListener(_onSynced);
    _onStatus();
    _onSynced();
  }

  void _onStatus() => statusNotifier.value = _runner == null
      ? SyncStatus.idle
      : SyncStatus.values.byName(_runner!.status.value);
  void _onSynced() => lastSyncedNotifier.value = _runner?.lastSynced.value;
  bool get canSync {
    _bind();
    return SyncRuntime.enabled && (SyncRuntime.coordinator?.canSync ?? false);
  }

  Future<bool> syncNow({bool force = false}) async {
    if (!canSync) return false;
    return _runner!.sync();
  }

  Future<void> init() async => _bind();
  Future<void> autoSyncIfSignedIn() async {
    if (canSync) await _runner!.autoSync();
  }

  Future<void> onBookmarkChanged() async {
    if (canSync) _runner!.changed();
  }

  Future<bool> pushLocalToCloud() => syncNow();
  Future<bool> pullCloudToLocal() => syncNow();
  Future<bool> deleteMovieFromCloud(int id, {String? owner}) =>
      _delete('movie', id, owner: owner);
  Future<bool> deleteTVFromCloud(int id, {String? owner}) =>
      _delete('tv', id, owner: owner);
  Future<bool> _delete(String type, int id, {String? owner}) async {
    if (!SyncRuntime.enabled || SyncRuntime.coordinator == null) return false;
    final capturedOwner = owner ?? LibraryScope.owner;
    if (!capturedOwner.startsWith('user:')) return false;
    try {
      final repository = SyncRuntime.coordinator!.bookmarkRepository;
      await repository.recordDeletion(capturedOwner, type, id);
      if (capturedOwner != LibraryScope.owner || !canSync) return false;
      await repository.deleteMedia(type, id, owner: capturedOwner);
      return true;
    } catch (_) {
      if (capturedOwner == LibraryScope.owner && canSync) _runner!.changed();
      return false;
    }
  }
}
