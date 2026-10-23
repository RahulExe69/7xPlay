import 'package:dio/dio.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/repositories/bookmark_repository.dart';
import 'package:flixquest/data/repositories/recently_watched_repository.dart';
import 'package:flixquest/data/repositories/wellness_repository.dart';
import 'package:flixquest/data/sync/laravel_sync_coordinator.dart';
import 'package:flixquest/data/sync/library_scope.dart';
import 'package:flixquest/data/sync/sync_runtime.dart';
import 'package:flixquest/services/bookmark_sync_service.dart';
import 'package:flixquest/services/recently_watched_sync_service.dart';
import 'package:flixquest/services/wellness_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Dio dio;
  late LaravelSyncCoordinator first, second;
  late WellnessSyncService wellness;
  final bookmarks = BookmarkSyncService.instance;
  final recents = RecentlyWatchedSyncService.instance;

  LaravelSyncCoordinator coordinator() {
    final store = FakeKvStore();
    final clock = ServerClock(store);
    return LaravelSyncCoordinator(
      bookmarkRepository: BookmarkRepository(dio, store),
      recentRepository: RecentlyWatchedRepository(dio, store, clock),
      wellnessRepository: WellnessRepository(dio, store, clock),
      store: store,
      clock: clock,
      authenticatedOwner: () => null,
    );
  }

  setUp(() {
    dio = Dio();
    first = coordinator();
    second = coordinator();
    wellness = WellnessSyncService();
    SyncRuntime.configure(first, enabled: true);
  });
  tearDown(() async {
    SyncRuntime.configure(second, enabled: false);
    await bookmarks.init();
    await recents.init();
    wellness.bind();
    wellness.dispose();
    first.dispose();
    second.dispose();
    dio.close();
    SyncRuntime.coordinator = null;
    LibraryScope.clock = null;
    LibraryScope.store = null;
    LibraryScope.activate(null);
  });

  test('guests keep local libraries without initializing a Firebase account',
      () async {
    expect(bookmarks.canSync, isFalse);
    expect(recents.canSync, isFalse);
    expect(wellness.canSync, isFalse);
    expect(await bookmarks.syncNow(), isFalse);
    expect(await recents.syncNow(), isFalse);
    expect(await wellness.syncNow(), isFalse);
    expect(LibraryScope.owner, 'guest');
  });

  test('replacing the coordinator detaches old status and timestamp listeners',
      () async {
    await bookmarks.init();
    await recents.init();
    wellness.bind();
    final stamp = DateTime.utc(2026, 10, 18);
    first.bookmarks.status.value = 'syncing';
    first.recents.lastSynced.value = stamp;
    first.wellnessSync.status.value = 'success';
    expect(bookmarks.statusNotifier.value, SyncStatus.syncing);
    expect(recents.lastSyncedNotifier.value, stamp);
    expect(wellness.status.value, WellnessSyncStatus.success);

    SyncRuntime.configure(second, enabled: true);
    await bookmarks.init();
    await recents.init();
    wellness.bind();
    first.bookmarks.status.value = 'error';
    first.recents.lastSynced.value = stamp.add(const Duration(days: 1));
    first.wellnessSync.status.value = 'error';
    expect(bookmarks.statusNotifier.value, SyncStatus.idle);
    expect(recents.lastSyncedNotifier.value, isNull);
    expect(wellness.status.value, WellnessSyncStatus.idle);
    second.recents.status.value = 'syncing';
    expect(recents.statusNotifier.value, RecentSyncStatus.syncing);
  });
}
