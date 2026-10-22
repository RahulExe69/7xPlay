import 'dart:async';

import 'package:flixquest/models/live_tv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only advancing content playback starts backup discovery', () async {
    var requests = 0;
    final discovery = LiveStreamDiscovery(initial: _variant('one'), backups: [
      () async {
        requests++;
        return _variant('two');
      },
    ]);
    addTearDown(discovery.dispose);
    void progress(int seconds,
        {bool playing = true, bool buffering = false, bool ad = false}) {
      discovery.observePlayback(
        position: Duration(seconds: seconds),
        isPlaying: playing,
        isBuffering: buffering,
        isAd: ad,
      );
    }

    progress(10, ad: true);
    progress(0);
    progress(1, buffering: true);
    progress(2, playing: false);
    progress(2);
    expect(requests, 0);

    final updated = discovery.updates.first;
    progress(3);
    expect((await updated).map((item) => item.url), ['one', 'two']);
    progress(4);
    discovery.start();
    expect(requests, 1);
  });

  test(
      'a fast later backup is published without waiting for a slow earlier one',
      () async {
    final slow = Completer<LiveStreamVariant?>();
    final discovery = LiveStreamDiscovery(initial: _variant('one'), backups: [
      () => slow.future,
      () async => _variant('three'),
    ]);
    addTearDown(discovery.dispose);
    final fast = discovery.updates.first;
    discovery.start();
    expect((await fast).map((item) => item.url), ['one', 'three']);

    final complete = discovery.updates.first;
    slow.complete(_variant('two'));
    expect((await complete).map((item) => item.url), ['one', 'two', 'three']);
  });

  test('pre-playback recovery stops at the next usable backup', () async {
    final requests = <int>[];
    final discovery = LiveStreamDiscovery(initial: _variant('one'), backups: [
      () async {
        requests.add(2);
        throw StateError('unavailable');
      },
      () async {
        requests.add(3);
        return _variant('three');
      },
      () async {
        requests.add(4);
        return _variant('four');
      },
    ]);
    addTearDown(discovery.dispose);

    await discovery.resolveNext();
    expect(requests, [2, 3]);
    expect(discovery.variants.map((item) => item.url), ['one', 'three']);
    final updated = discovery.updates.first;
    discovery.start();
    await updated;
    expect(requests, [2, 3, 4]);
  });

  test('background and recovery share the same pending request', () async {
    final pending = Completer<LiveStreamVariant?>();
    var requests = 0;
    final discovery = LiveStreamDiscovery(initial: _variant('one'), backups: [
      () {
        requests++;
        return pending.future;
      },
    ]);
    addTearDown(discovery.dispose);
    discovery.start();
    final recovery = discovery.resolveNext();
    pending.complete(_variant('two'));
    await recovery;
    expect(requests, 1);
    expect(discovery.hasNext, isFalse);
  });

  test('leaving before playback starts makes no backup requests', () async {
    var requests = 0;
    final discovery = LiveStreamDiscovery(initial: _variant('one'), backups: [
      () async {
        requests++;
        return _variant('two');
      },
    ]);
    discovery.dispose();
    discovery.start();
    await discovery.resolveNext();
    expect(requests, 0);
  });

  test('late results from a disposed channel are discarded', () async {
    final pending = Completer<LiveStreamVariant?>();
    final discovery = LiveStreamDiscovery(initial: _variant('one'), backups: [
      () => pending.future,
    ]);
    final updates = <List<LiveStreamVariant>>[];
    final subscription = discovery.updates.listen(updates.add);
    discovery.start();
    discovery.dispose();
    pending.complete(_variant('two'));
    await discovery.resolveNext();
    await subscription.cancel();
    expect(updates, isEmpty);
    expect(discovery.variants.map((item) => item.url), ['one']);
  });
}

LiveStreamVariant _variant(String url) => LiveStreamVariant(
      url: url,
      headers: const {},
      mediaType: 'hls',
    );
