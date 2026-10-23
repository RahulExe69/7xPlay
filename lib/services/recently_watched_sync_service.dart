import 'package:flutter/foundation.dart';
import '../data/sync/sync_runtime.dart';
import '../data/sync/sync_runner.dart';

enum RecentSyncStatus { idle, syncing, success, error }

Set<int> resolveCloudWinners({
  required Map<int, int> cloudVersions,
  required Map<int, int> localVersions,
  Set<int> cloudDeleted = const <int>{},
}) {
  final winners = <int>{};
  for (final entry in cloudVersions.entries) {
    final localVersion = localVersions[entry.key];
    if (localVersion == null) {
      if (!cloudDeleted.contains(entry.key)) winners.add(entry.key);
      continue;
    }
    if (entry.value > localVersion) winners.add(entry.key);
  }
  return winners;
}

/// Adapts Laravel's sync runner to existing provider and player callbacks.
class RecentlyWatchedSyncService {
  RecentlyWatchedSyncService._();
  static final instance = RecentlyWatchedSyncService._();
  final statusNotifier = ValueNotifier<RecentSyncStatus>(RecentSyncStatus.idle);
  final lastSyncedNotifier = ValueNotifier<DateTime?>(null);
  SyncRunner? _runner;

  void _bind() {
    final next = SyncRuntime.enabled ? SyncRuntime.coordinator?.recents : null;
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
      ? RecentSyncStatus.idle
      : RecentSyncStatus.values.byName(_runner!.status.value);
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

  void onRecentChanged() {
    if (canSync) _runner!.changed();
  }

  Future<void> flushPending() async {
    if (canSync) await _runner!.flush();
  }

  Future<bool> pushPendingNow() => syncNow();
  void dispose() {
    _runner?.status.removeListener(_onStatus);
    _runner?.lastSynced.removeListener(_onSynced);
    _runner = null;
  }
}
