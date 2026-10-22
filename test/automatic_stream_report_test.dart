import 'dart:async';

import 'package:flixquest/services/automatic_stream_report.dart';
import 'package:flixquest/services/stream_feedback_session.dart';
import 'package:flutter_test/flutter_test.dart';

StreamFeedbackMeasurement _measurement({
  int watchedMs = 300000,
  int? startupMs = 1000,
  int errors = 0,
  int bufferingMs = 0,
}) =>
    StreamFeedbackMeasurement(
      sessionMs: watchedMs + (startupMs ?? 0) + bufferingMs,
      watchedMs: watchedMs,
      bufferingMs: bufferingMs,
      bufferCount: bufferingMs == 0 ? 0 : 2,
      errorCount: errors,
      startupMs: startupMs,
      outcome: startupMs == null
          ? (errors > 0 ? 'failed_to_start' : 'abandoned_before_start')
          : 'exited',
      transferBaseline: 1000,
      transferSampleMs: 60000,
    );

const _episode = StreamFeedbackContext(
  mediaType: 'tv',
  surface: 'tv',
  provider: 'current',
  initialProvider: 'first',
  sourceSwitches: 1,
  connectionType: 'wifi',
  networkChanges: 1,
  tmdbId: 1399,
  seasonNumber: 2,
  episodeNumber: 3,
  videoHeight: 1080,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default sampling can skip a stream even in a debug test build',
      () async {
    var writes = 0;
    final report = AutomaticStreamReport(
      draw: (max) {
        expect(max, 5);
        return 4;
      },
      writeEvent: (_, __) async {
        writes++;
      },
    );
    expect(report.selected, isFalse);
    await report.send(
        measurement: _measurement(), context: _episode, endReason: 'user_exit');
    expect(writes, 0);
  });

  test('one fifth of sessions selected once before measurements are known',
      () async {
    var draws = 0;
    var flushes = 0;
    final events = <String>[];
    final sessions = List.generate(
        100,
        (index) => AutomaticStreamReport(
              draw: (max) {
                expect(max, 5);
                draws++;
                return index % max;
              },
              writeEvent: (name, params) async {
                events.add(name);
              },
            ));
    expect(draws, 100);
    expect(sessions.where((report) => report.selected).length, 20);
    for (final report in sessions) {
      await report.send(
          measurement: _measurement(),
          context: _episode,
          endReason: 'user_exit',
          flushNetworkUsage: () async {
            flushes++;
            return 15001000;
          });
    }
    expect(draws, 100);
    expect(flushes, 20);
    expect(events, List.filled(20, 'stream_playback_report'));
  });

  test('same full diagnostics as survey, with no rating and no UI dependency',
      () async {
    late Map<String, Object> payload;
    final report = AutomaticStreamReport(
        debugAlwaysReport: false,
        draw: (_) => 0,
        writeEvent: (_, params) async {
          payload = params;
        });
    final measurement = _measurement(bufferingMs: 20000);
    await report.send(
        measurement: measurement,
        context: _episode,
        endReason: 'content_switch',
        flushNetworkUsage: () async => 15001000);
    expect(payload, {
      ..._episode.parameters,
      ...measurement.parameters(totalBytes: 15001000),
      'end_reason': 'content_switch',
      'playback_health': 'heavy_buffering',
    });
    expect(payload.length, 25);
    expect(payload['tmdb_id'], '1399');
    expect(payload['season_number'], 's2');
    expect(payload['episode_number'], 'e3');
    expect(payload['stream_mbps'], 2.0);
    expect(payload.containsKey('rating'), isFalse);
    expect(payload.containsKey('issue'), isFalse);
  });

  for (final debugAlwaysReport in [false, true]) {
    test(
        'under-five-minute sessions never send or flush (debug: $debugAlwaysReport)',
        () async {
      var writes = 0;
      var flushes = 0;
      for (final measurement in [
        _measurement(watchedMs: 0, startupMs: null, errors: 1),
        _measurement(watchedMs: 1000),
        _measurement(watchedMs: 299999, errors: 2),
        _measurement(watchedMs: 0, startupMs: null),
      ]) {
        final report = AutomaticStreamReport(
          debugAlwaysReport: debugAlwaysReport,
          draw: (_) => 0,
          writeEvent: (_, __) async {
            writes++;
          },
        );
        await report.send(
            measurement: measurement,
            context: _episode,
            endReason: 'user_exit',
            flushNetworkUsage: () async {
              flushes++;
              return 15001000;
            });
        await report.send(
            measurement: measurement,
            context: _episode,
            endReason: 'route_disposed');
        expect(report.shouldReport, isFalse);
      }
      expect(writes, 0);
      expect(flushes, 0);
    });

    test(
        'five-minute boundary uses actual watch time (debug: $debugAlwaysReport)',
        () async {
      final payloads = <Map<String, Object>>[];
      for (final watchedMs in [299999, 300000, 300001]) {
        final report = AutomaticStreamReport(
          debugAlwaysReport: debugAlwaysReport,
          draw: (_) => 0,
          writeEvent: (_, params) async {
            payloads.add(params);
          },
        );
        // Each route is open much longer due to buffering. Only watched_ms
        // determines eligibility, rather than wall time or playhead position.
        await report.send(
            measurement:
                _measurement(watchedMs: watchedMs, bufferingMs: 600000),
            context: _episode,
            endReason: 'route_disposed');
      }
      expect(
          payloads.map((payload) => payload['watched_ms']), [300000, 300001]);
    });
  }

  test('explicit exit followed by dispose cannot duplicate an in-flight report',
      () async {
    final bytes = Completer<int?>();
    final payloads = <Map<String, Object>>[];
    var flushes = 0;
    final report = AutomaticStreamReport(
        debugAlwaysReport: false,
        draw: (_) => 0,
        writeEvent: (_, params) async {
          payloads.add(params);
        });
    final first = report.send(
        measurement: _measurement(),
        context: _episode,
        endReason: 'user_exit',
        flushNetworkUsage: () {
          flushes++;
          return bytes.future;
        });
    expect(report.shouldReport, isFalse);
    await report.send(
        measurement: _measurement(),
        context: _episode,
        endReason: 'route_disposed',
        flushNetworkUsage: () {
          flushes++;
          return bytes.future;
        });
    bytes.complete(15001000);
    await first;
    expect(flushes, 1);
    expect(payloads.length, 1);
    expect(payloads.single['end_reason'], 'user_exit');
  });

  test('native counter errors retain all other fields and last known bytes',
      () async {
    late Map<String, Object> payload;
    final report = AutomaticStreamReport(
        debugAlwaysReport: false,
        draw: (_) => 0,
        writeEvent: (_, params) async {
          payload = params;
        });
    await report.send(
        measurement: _measurement(),
        context: _episode,
        endReason: 'route_disposed',
        fallbackNetworkBytes: 15001000,
        flushNetworkUsage: () => throw StateError('unsupported'));
    expect(payload['network_bytes'], 15000000);
    expect(payload['stream_mbps'], 2.0);
    expect(payload['watched_ms'], 300000);
  });

  test('hanging native counter has a bounded wait and fallback', () async {
    late Map<String, Object> payload;
    final report = AutomaticStreamReport(
        debugAlwaysReport: false,
        draw: (_) => 0,
        networkTimeout: Duration.zero,
        writeEvent: (_, params) async {
          payload = params;
        });
    await report.send(
        measurement: _measurement(),
        context: _episode,
        endReason: 'route_disposed',
        fallbackNetworkBytes: 15001000,
        flushNetworkUsage: () => Completer<int?>().future);
    expect(payload['network_bytes'], 15000000);
    expect(report.shouldReport, isFalse);
  });

  test('Analytics failures never escape or cause a retry duplicate', () async {
    var writes = 0;
    final report = AutomaticStreamReport(
        debugAlwaysReport: false,
        draw: (_) => 0,
        writeEvent: (_, __) async {
          writes++;
          throw StateError('offline');
        });
    await expectLater(
        report.send(
            measurement: _measurement(),
            context: _episode,
            endReason: 'user_exit'),
        completes);
    await report.send(
        measurement: _measurement(),
        context: _episode,
        endReason: 'route_disposed');
    expect(writes, 1);
  });

  test('health labels have explicit thresholds and never claim a user rating',
      () {
    expect(_measurement(startupMs: 10000).playbackHealth, 'slow_start');
    expect(_measurement(bufferingMs: 2999).playbackHealth, 'no_observed_issue');
    expect(_measurement(bufferingMs: 3000, watchedMs: 57000).playbackHealth,
        'heavy_buffering');
    expect(_measurement(bufferingMs: 3000, watchedMs: 60000).playbackHealth,
        'no_observed_issue');
    expect(
        _measurement(startupMs: 20000, bufferingMs: 20000, errors: 1)
            .playbackHealth,
        'playback_errors');
    expect(
        _measurement(watchedMs: 14999).playbackHealth, 'insufficient_playback');
    expect(_measurement(watchedMs: 15000).playbackHealth, 'no_observed_issue');
  });

  test('live TV reports identify channels without fabricated TMDB fields',
      () async {
    late Map<String, Object> payload;
    final report = AutomaticStreamReport(
        debugAlwaysReport: false,
        draw: (_) => 0,
        writeEvent: (_, params) async {
          payload = params;
        });
    await report.send(
        measurement: _measurement(),
        context: const StreamFeedbackContext(
            mediaType: 'live_tv',
            surface: 'mobile',
            provider: 'dlhd',
            initialProvider: 'dlhd',
            sourceSwitches: 1,
            channelId: 'channel_2',
            initialChannelId: 'channel_1',
            connectionType: 'mobile',
            networkChanges: 0),
        endReason: 'user_exit');
    expect(payload['channel_id'], 'channel_2');
    expect(payload['initial_channel_id'], 'channel_1');
    expect(payload.containsKey('tmdb_id'), isFalse);
    expect(payload.containsKey('season_number'), isFalse);
  });
}
