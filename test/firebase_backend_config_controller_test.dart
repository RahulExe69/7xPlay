import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flixquest/services/app_remote_config.dart';
import 'package:flixquest/services/firebase_backend_config_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_remote_config.dart';

class _BackendRemoteConfig extends FakeFirebaseRemoteConfig {
  final updates = StreamController<RemoteConfigUpdate>.broadcast(sync: true);
  Future<void> Function()? onFetch;

  @override
  DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  RemoteConfigFetchStatus get lastFetchStatus =>
      RemoteConfigFetchStatus.success;

  @override
  Stream<RemoteConfigUpdate> get onConfigUpdated => updates.stream;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<bool> activate() async => true;

  @override
  Future<bool> fetchAndActivate() async {
    await onFetch?.call();
    lastFetchTime = DateTime.now();
    return false; // No changed values is still a successful fetch.
  }

  void publish(String url) {
    setMockString(AppRemoteConfig.laravelApiUrlKey, url);
    updates.add(RemoteConfigUpdate({AppRemoteConfig.laravelApiUrlKey}));
  }
}

void main() {
  late _BackendRemoteConfig remote;
  late FirebaseBackendConfigController controller;
  late List<String> applied;

  setUp(() {
    remote = _BackendRemoteConfig();
    applied = [];
    controller = FirebaseBackendConfigController(
      fallbackUrl: 'https://bundled.example',
      onUrlChanged: applied.add,
      remote: remote,
      connectivityChanges: const Stream<bool>.empty(),
      checkConnectivity: () async => true,
    );
  });

  tearDown(() async {
    controller.dispose();
    await remote.updates.close();
  });

  test('starts on bundled URL, applies activated cache before a slow fetch',
      () async {
    remote.setMockString(
        AppRemoteConfig.laravelApiUrlKey, ' https://cached.example/backend/ ');
    final fetching = Completer<void>();
    final release = Completer<void>();
    remote.onFetch = () async {
      fetching.complete();
      await release.future;
      remote.setMockString(
          AppRemoteConfig.laravelApiUrlKey, 'https://fresh.example/api/v1');
    };

    expect(applied, isEmpty);
    final starting = controller.start();
    await fetching.future;
    expect(applied, ['https://cached.example/backend/api/v1/']);
    release.complete();
    await starting;
    expect(applied.last, 'https://fresh.example/api/v1/');
  });

  test('missing remote value and offline first fetch keep bundled fallback',
      () async {
    remote.onFetch = () async => throw StateError('offline');
    await controller.start();
    expect(remote.defaults[AppRemoteConfig.laravelApiUrlKey], '');
    expect(applied, isEmpty);

    remote.onFetch = () async {
      remote.setMockString(
          AppRemoteConfig.laravelApiUrlKey, 'https://recovered.example');
    };
    await controller.refresh();
    expect(applied, ['https://recovered.example/api/v1/']);
  });

  test('realtime updates validate, deduplicate and support clearing the URL',
      () async {
    await controller.start();
    remote.publish('https://live.example');
    await Future<void>.delayed(Duration.zero);
    expect(applied, ['https://live.example/api/v1/']);

    for (final invalid in [
      'localhost:8000',
      'ftp://backend.example',
      'https://user:secret@backend.example',
      'https://backend.example?token=private',
      'https://backend.example#fragment',
      'https://[invalid',
    ]) {
      remote.publish(invalid);
      await Future<void>.delayed(Duration.zero);
      expect(applied.length, 1, reason: invalid);
    }
    remote.publish('https://live.example/api/v1/');
    await Future<void>.delayed(Duration.zero);
    expect(applied.length, 1);

    remote.publish('  ');
    await Future<void>.delayed(Duration.zero);
    expect(applied.last, 'https://bundled.example/api/v1/');
  });

  test('offline refresh retains an activated URL', () async {
    remote.setMockString(
        AppRemoteConfig.laravelApiUrlKey, 'https://cached.example');
    remote.onFetch = () async => throw StateError('offline');
    await controller.start();
    expect(applied, ['https://cached.example/api/v1/']);
  });

  test('dispose prevents an in-flight fetch from applying its result',
      () async {
    final fetching = Completer<void>();
    final release = Completer<void>();
    remote.onFetch = () async {
      fetching.complete();
      await release.future;
      remote.setMockString(
          AppRemoteConfig.laravelApiUrlKey, 'https://late.example');
    };
    final starting = controller.start();
    await fetching.future;
    controller.dispose();
    release.complete();
    await starting;
    expect(applied, isEmpty);
  });
}
