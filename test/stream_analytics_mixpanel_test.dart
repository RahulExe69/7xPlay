import 'dart:async';

import 'package:flixquest/constants/api_constants.dart' as api;
import 'package:flixquest/functions/function.dart';
import 'package:flixquest/services/analytics_service.dart';
import 'package:flixquest/services/automatic_stream_report.dart';
import 'package:flixquest/services/stream_feedback_service.dart';
import 'package:flixquest/services/stream_feedback_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixpanel_flutter/codec/mixpanel_message_codec.dart';

const _mixpanelChannel = MethodChannel(
  'mixpanel_flutter',
  StandardMethodCodec(MixpanelMessageCodec()),
);
const _context = StreamFeedbackContext(
  mediaType: 'tv',
  surface: 'tv',
  provider: 'provider_a',
  initialProvider: 'provider_a',
  sourceSwitches: 0,
  tmdbId: 1399,
  seasonNumber: 2,
  episodeNumber: 3,
  videoHeight: 1080,
  connectionType: 'wifi',
  networkChanges: 0,
);
const _measurement = StreamFeedbackMeasurement(
  sessionMs: 330000,
  watchedMs: 300000,
  bufferingMs: 5000,
  bufferCount: 2,
  errorCount: 0,
  startupMs: 1500,
  outcome: 'exited',
  transferBaseline: 1000,
  transferSampleMs: 60000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var initializations = 0;
  var failTracking = false;
  Completer<void>? durationTracked;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  List<Map<dynamic, dynamic>> tracks() => calls
      .where((call) => call.method == 'track')
      .map((call) => call.arguments as Map<dynamic, dynamic>)
      .toList();

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
    api.mixpanelKey = 'test-mixpanel-token';
    messenger.setMockMethodCallHandler(_mixpanelChannel, (call) async {
      if (call.method == 'initialize') initializations++;
      calls.add(call);
      if (call.method == 'track') {
        if (failTracking) throw PlatformException(code: 'offline');
        final args = call.arguments as Map<dynamic, dynamic>;
        if (args['eventName'] == 'total_streaming_duration') {
          durationTracked?.complete();
        }
      }
      return null;
    });
    await AnalyticsService.init();
  });
  setUp(() {
    calls.clear();
    failTracking = false;
    durationTracked = null;
  });
  tearDownAll(() => messenger.setMockMethodCallHandler(_mixpanelChannel, null));

  test(
      'default survey writer sends all feedback events through existing Mixpanel',
      () async {
    final service = StreamFeedbackService();
    final params = <String, Object>{
      ..._context.parameters,
      ..._measurement.parameters(totalBytes: 15001000),
    };
    await service.track('shown', params);
    await service
        .track('submitted', {...params, 'rating': 'bad', 'issue': 'buffering'});
    await service.track('dismissed', params);

    final events = tracks();
    expect(events.map((event) => event['eventName']), [
      'stream_feedback_shown',
      'stream_feedback_submitted',
      'stream_feedback_dismissed',
    ]);
    expect(events[0]['properties'], params);
    expect(events[1]['properties'],
        {...params, 'rating': 'bad', 'issue': 'buffering'});
    expect(events[2]['properties'], params);
    expect(initializations, 1);
  });

  test(
      'default automatic writer sends full diagnostics to the same Mixpanel instance once',
      () async {
    final report = AutomaticStreamReport(draw: (_) => 0);
    await report.send(
        measurement: _measurement,
        context: _context,
        endReason: 'user_exit',
        fallbackNetworkBytes: 15001000);
    await report.send(
        measurement: _measurement,
        context: _context,
        endReason: 'route_disposed');

    final event = tracks().single;
    expect(event['eventName'], 'stream_playback_report');
    expect(event['properties'], {
      ..._context.parameters,
      ..._measurement.parameters(totalBytes: 15001000),
      'end_reason': 'user_exit',
      'playback_health': 'no_observed_issue',
    });
    expect(initializations, 1);
  });

  test('under-five-minute sessions never reach the Mixpanel transport',
      () async {
    final report = AutomaticStreamReport(draw: (_) => 0);
    await report.send(
        measurement: const StreamFeedbackMeasurement(
          sessionMs: 330000,
          watchedMs: 299999,
          bufferingMs: 20000,
          bufferCount: 2,
          errorCount: 1,
          startupMs: 1000,
          outcome: 'exited',
          transferBaseline: null,
          transferSampleMs: 0,
        ),
        context: _context,
        endReason: 'user_exit');
    expect(tracks(), isEmpty);
  });

  test(
      'legacy duration helper also sends to Mixpanel with its existing property',
      () async {
    totalStreamingDuration = 0;
    durationTracked = Completer<void>();
    updateAndLogTotalStreamingDuration(300);
    await durationTracked!.future;
    durationTracked = Completer<void>();
    updateAndLogTotalStreamingDuration(60);
    await durationTracked!.future;
    expect(tracks().map((event) => event['eventName']), [
      'total_streaming_duration',
      'total_streaming_duration',
    ]);
    expect(tracks().map((event) => event['properties']), [
      {'duration_seconds': 300},
      {'duration_seconds': 360},
    ]);
  });

  test('Mixpanel transport failures do not escape feedback or playback exit',
      () async {
    failTracking = true;
    await expectLater(
        StreamFeedbackService().track('shown', _context.parameters), completes);
    await expectLater(
        AutomaticStreamReport(draw: (_) => 0).send(
            measurement: _measurement,
            context: _context,
            endReason: 'user_exit'),
        completes);
    expect(tracks().length, 2);
  });
}
