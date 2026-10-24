import 'package:flixquest/services/playback_wake_lock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<bool> writes;
  late PlaybackWakeLock wake;

  setUp(() {
    writes = <bool>[];
    wake = PlaybackWakeLock(toggle: (enable) async => writes.add(enable));
  });

  tearDown(() {
    // Leaves no heartbeat or lifecycle observer behind.
    for (final owner in <Object>['a', 'b', 'old', 'new']) {
      wake.release(owner);
    }
  });

  test('the screen stays on while anyone holds it', () {
    wake.hold('a');
    wake.hold('b');
    expect(writes, <bool>[true, true]);

    wake.release('a');
    expect(wake.isHeld, isTrue);
    expect(writes.last, isTrue);

    wake.release('b');
    expect(wake.isHeld, isFalse);
    expect(writes.last, isFalse);
  });

  test('an old player let go late cannot clear its replacement\'s hold', () {
    wake.hold('old');
    // The next episode's player starts before the old route is disposed.
    wake.hold('new');
    wake.release('old');
    expect(wake.isHeld, isTrue);
    expect(writes.last, isTrue);
  });

  test('holding or letting go twice writes once', () {
    wake.hold('a');
    wake.hold('a');
    expect(writes, <bool>[true]);
    wake.release('a');
    wake.release('a');
    expect(writes, <bool>[true, false]);
  });

  test('set follows whether playback is expected', () {
    wake.set('a', wanted: true);
    expect(wake.isHeld, isTrue);
    // Paused by the remote: the screen saver may start.
    wake.set('a', wanted: false);
    expect(wake.isHeld, isFalse);
    expect(writes, <bool>[true, false]);
  });

  // testWidgets runs in fake time, so the heartbeat can be stepped through.
  testWidgets('the flag is set again on a heartbeat while held, and only then',
      (tester) async {
    wake.hold('a');
    await tester.pump(const Duration(seconds: 95));
    expect(writes, <bool>[true, true, true, true]);

    wake.release('a');
    writes.clear();
    await tester.pump(const Duration(minutes: 5));
    expect(writes, isEmpty);
  });

  testWidgets('a failed write is survived and retried on the next heartbeat',
      (tester) async {
    var fail = true;
    final wake = PlaybackWakeLock(
      toggle: (enable) async {
        if (fail) throw StateError('wakelock requires a foreground activity');
        writes.add(enable);
      },
    );
    wake.hold('a');
    await tester.pump();
    expect(writes, isEmpty);

    fail = false;
    await tester.pump(const Duration(seconds: 30));
    expect(writes, <bool>[true]);
    wake.release('a');
  });

  test('returning to the app sets the flag again while held', () {
    wake.hold('a');
    writes.clear();
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(writes, <bool>[true]);

    wake.release('a');
    writes.clear();
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(writes, isEmpty);
  });
}
