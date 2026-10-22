import 'dart:async';

import 'package:flixquest/services/ad_block_check_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default checks return immediately while the scan is pending', () async {
    final cache = AdBlockCheckCache();
    final pending = Completer<bool>();
    expect(cache.foregroundWait, Duration.zero);
    expect(await cache.check('network', () => pending.future), isNull);
    pending.complete(false);
    await cache.warm('network', () async => true);
    expect(await cache.check('network', () async => true), isFalse);
  });
  testWidgets('cold waits are bounded and a second loader shares the deadline',
      (tester) async {
    final cache = AdBlockCheckCache(
        now: tester.binding.clock.now,
        foregroundWait: const Duration(milliseconds: 700));
    final pending = Completer<bool>();
    var scans = 0;
    Future<bool> scan() {
      scans++;
      return pending.future;
    }

    final first = cache.check('network-a', scan);
    await tester.pump(cache.foregroundWait);
    expect(await first, isNull);
    expect(await cache.check('network-a', scan), isNull);
    expect(scans, 1);
    pending.complete(true);
    await tester.pump();
    expect(await cache.check('network-a', scan), isTrue);
    expect(scans, 1);
  });

  test('finished warmup and loader reuse the result without another scan',
      () async {
    final cache = AdBlockCheckCache();
    var scans = 0;
    Future<bool> scan() async {
      scans++;
      return false;
    }

    await cache.warm('same-network', scan);
    expect(await cache.check('same-network', scan), isFalse);
    expect(await cache.check('same-network', scan), isFalse);
    expect(scans, 1);
  });

  test('expired results and changed configurations start a new scan', () async {
    var now = DateTime(2026);
    final cache = AdBlockCheckCache(now: () => now);
    var scans = 0;
    Future<bool> scan() async {
      scans++;
      return false;
    }

    await cache.warm('config-a', scan);
    now = now.add(cache.validFor);
    await cache.warm('config-a', scan);
    await cache.warm('config-b', scan);
    expect(scans, 3);
  });

  test('invalidated scans cannot overwrite a newer network result', () async {
    final cache = AdBlockCheckCache();
    final old = Completer<bool>();
    final obsolete = cache.warm('network', () => old.future);
    cache.invalidate();
    await cache.warm('network', () async => true);
    old.complete(false);
    await obsolete;
    expect(await cache.check('network', () async => false), isTrue);
  });

  test('failed scans are not cached', () async {
    final cache = AdBlockCheckCache();
    await cache.warm(
        'network', () async => throw StateError('probe unavailable'));
    await cache.warm('network', () async => true);
    expect(await cache.check('network', () async => true), isTrue);
  });
}
