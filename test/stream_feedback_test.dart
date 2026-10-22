import 'package:better_player_plus/better_player_plus.dart';
import 'package:flixquest/services/stream_feedback_service.dart';
import 'package:flixquest/services/stream_feedback_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Playback {
  DateTime now = DateTime(2026, 10, 19);
  late final session = StreamFeedbackSession(now: () => now);
  void advance(int milliseconds) =>
      now = now.add(Duration(milliseconds: milliseconds));
  void event(BetterPlayerEventType type,
      {int? progress,
      bool ad = false,
      bool playing = true,
      bool buffering = false,
      int? bytes}) {
    session.onEvent(
        BetterPlayerEvent(type, parameters: {
          if (progress != null) 'progress': Duration(milliseconds: progress),
        }),
        isAd: ad,
        isPlaying: playing,
        isBuffering: buffering,
        totalBytes: bytes);
  }

  void start({int? bytes}) {
    event(BetterPlayerEventType.progress, progress: 0, bytes: bytes);
    advance(1000);
    event(BetterPlayerEventType.progress, progress: 1000, bytes: bytes);
  }
}

StreamFeedbackMeasurement eligibleMeasurement() =>
    const StreamFeedbackMeasurement(
      sessionMs: 70000,
      watchedMs: 60000,
      bufferingMs: 2000,
      bufferCount: 1,
      errorCount: 0,
      startupMs: 1500,
      outcome: 'exited',
      transferBaseline: 1000,
      transferSampleMs: 60000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ads never establish playback, contribute watch time or errors', () {
    final playback = _Playback();
    playback.event(BetterPlayerEventType.play, ad: true);
    playback.advance(10000);
    playback.event(BetterPlayerEventType.progress,
        progress: 10000, ad: true, bytes: 1000000);
    playback.event(BetterPlayerEventType.exception, ad: true);
    playback.advance(10000);
    playback.event(BetterPlayerEventType.preRollEnded);
    playback.start(bytes: 1000000);
    playback.advance(60000);
    final measurement = playback.session.freeze();
    expect(measurement.startupMs, 1000);
    expect(measurement.watchedMs, 60000);
    expect(measurement.errorCount, 0);
    expect(measurement.eligible, isTrue);
    final params = measurement.parameters(totalBytes: 16000000);
    expect(params['network_bytes'], 15000000);
    expect(params['stream_mbps'], 2.0);
  });

  test('open rebuffer counted once; startup buffering is separate', () {
    final playback = _Playback();
    playback.event(BetterPlayerEventType.bufferingStart);
    playback.advance(2000);
    playback.event(BetterPlayerEventType.bufferingEnd);
    playback.start();
    playback.advance(60000);
    playback.event(BetterPlayerEventType.bufferingStart);
    playback.advance(1000);
    playback.event(BetterPlayerEventType.bufferingStart);
    playback.advance(2000);
    final measurement = playback.session.freeze();
    expect(measurement.startupMs, 3000);
    expect(measurement.watchedMs, 60000);
    expect(measurement.bufferingMs, 3000);
    expect(measurement.bufferCount, 1);
    expect(measurement.parameters()['rebuffer_ratio'],
        closeTo(3000 / 63000, .00001));
    playback.advance(20000);
    playback.event(BetterPlayerEventType.exception);
    expect(measurement.errorCount, 0);
  });

  test('pause and source replacement do not count as watch or rebuffer time',
      () {
    final playback = _Playback()..start();
    playback.advance(10000);
    playback.event(BetterPlayerEventType.pause, playing: false);
    playback.advance(30000);
    playback.event(BetterPlayerEventType.setupDataSource);
    playback.advance(5000);
    playback.event(BetterPlayerEventType.progress, progress: 90000);
    playback.advance(1000);
    playback.event(BetterPlayerEventType.progress, progress: 91000);
    playback.advance(10000);
    final result = playback.session.freeze();
    expect(result.watchedMs, 20000);
    expect(result.bufferingMs, 0);
    expect(result.startupMs, 1000);
  });

  test('failed startup eligible; initialized or play alone is not success', () {
    final playback = _Playback();
    playback.event(BetterPlayerEventType.initialized);
    playback.event(BetterPlayerEventType.play);
    playback.advance(5000);
    playback.session.recordFailure();
    final measurement = playback.session.freeze();
    expect(measurement.eligible, isTrue);
    expect(measurement.outcome, 'failed_to_start');
    expect(measurement.startupMs, isNull);
    expect(measurement.parameters().containsKey('stream_mbps'), isFalse);
  });

  test('early exits and unsupported/short transfer samples omit throughput',
      () {
    final playback = _Playback()..start(bytes: 1000);
    playback.advance(1000);
    final result = playback.session.freeze();
    expect(result.eligible, isFalse);
    expect(result.parameters(totalBytes: 1000000).containsKey('stream_mbps'),
        isFalse);
    expect(result.parameters().containsKey('network_bytes'), isFalse);
    expect(result.parameters(totalBytes: 0)['network_bytes'], 0);
  });

  test('default survey rules enforce watch time and cooldown in debug tests',
      () async {
    final now = DateTime(2026, 10, 20);
    SharedPreferences.setMockInitialValues({
      StreamFeedbackService.cooldownKey: now.millisecondsSinceEpoch,
    });
    var draws = 0;
    final service = StreamFeedbackService(
      now: () => now,
      draw: (max) {
        expect(max, 10);
        draws++;
        return 0;
      },
    );
    expect(await service.reserve(_Playback().session.freeze()), isFalse);
    expect(draws, 0);
    expect(await service.reserve(eligibleMeasurement()), isFalse);
    expect(draws, 1);
  });

  test('10 percent sampling runs locally without emitting events', () async {
    SharedPreferences.setMockInitialValues({});
    var drawn = 0;
    var writes = 0;
    final service = StreamFeedbackService(
      draw: (max) => drawn++ % max,
      writeEvent: (_, __) async {
        writes++;
      },
    );
    var selected = 0;
    for (var i = 0; i < 100; i++) {
      if (await service.reserve(eligibleMeasurement())) selected++;
      service.release();
    }
    expect(selected, 10);
    expect(writes, 0);
  });

  test('cooldown persists across service instances and dismissals', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 10, 19);
    StreamFeedbackService create() => StreamFeedbackService(
        debugAlwaysReport: false, draw: (_) => 0, now: () => now);
    final first = create();
    expect(await first.reserve(eligibleMeasurement()), isTrue);
    await first.markShown();
    first.release();
    now = now.add(const Duration(days: 2));
    expect(await create().reserve(eligibleMeasurement()), isFalse);
    now = now.add(const Duration(days: 1));
    expect(await create().reserve(eligibleMeasurement()), isTrue);
  });

  test('simultaneous exits cannot reserve two prompts', () async {
    SharedPreferences.setMockInitialValues({});
    final service =
        StreamFeedbackService(debugAlwaysReport: false, draw: (_) => 0);
    final results = await Future.wait([
      service.reserve(eligibleMeasurement()),
      service.reserve(eligibleMeasurement()),
    ]);
    expect(results.where((value) => value).length, 1);
    service.release();
  });

  test('automatic reporting and the survey share one immutable final snapshot',
      () {
    final playback = _Playback()..start(bytes: 1000);
    playback.advance(60000);
    playback.session.recordCompletion();
    final first = playback.session.freeze();
    playback.advance(30000);
    playback.session.recordFailure();
    final second = playback.session.freeze();
    expect(identical(first, second), isTrue);
    expect(second.sessionMs, 61000);
    expect(second.watchedMs, 60000);
    expect(second.outcome, 'completed');
    expect(second.errorCount, 0);
  });

  test('complete episode payload preserves the stream event properties', () {
    const context = StreamFeedbackContext(
      mediaType: 'tv',
      surface: 'tv',
      tmdbId: 1399,
      seasonNumber: 2,
      episodeNumber: 3,
      provider: 'current',
      initialProvider: 'first',
      sourceSwitches: 1,
      videoHeight: 1080,
      connectionType: 'wifi',
      networkChanges: 1,
    );
    final parameters = {
      ...context.parameters,
      ...eligibleMeasurement().parameters(totalBytes: 15001000),
      'rating': 'bad',
      'issue': 'wrong_content',
    };
    expect(parameters['tmdb_id'], '1399');
    expect(parameters['season_number'], 's2');
    expect(parameters['episode_number'], 'e3');
    expect(parameters['source_switches'], 'switches_1');
    expect(parameters.containsKey('channel_id'), isFalse);
    for (final entry in parameters.entries) {
      expect(entry.value, anyOf(isA<String>(), isA<num>()));
    }
  });

  test('analytics failures never escape to navigation', () async {
    final service = StreamFeedbackService(
        debugAlwaysReport: false,
        writeEvent: (_, __) async => throw StateError('offline'));
    await expectLater(service.track('submitted', {'rating': 'bad'}), completes);
  });
}
