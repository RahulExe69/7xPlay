import 'dart:math';

import 'package:flutter/foundation.dart';

import 'stream_feedback_service.dart';
import 'stream_feedback_session.dart';
import 'analytics_service.dart';

/// One silent Mixpanel report for sampled sessions with at least five minutes of
/// observed content playback. It never opens UI or reads survey cooldowns.
/// Debug and release builds use the same sampling and watch-time rules.
class AutomaticStreamReport {
  AutomaticStreamReport({
    int Function(int)? draw,
    bool debugAlwaysReport = false,
    FeedbackEventWriter? writeEvent,
    Duration networkTimeout = const Duration(seconds: 2),
  })  : selected = debugAlwaysReport || (draw ?? Random().nextInt)(5) == 0,
        _writeEvent = writeEvent ?? _mixpanelEvent,
        _networkTimeout = networkTimeout;

  static const eventName = 'stream_playback_report';
  static const minimumWatch = Duration(minutes: 5);
  final bool selected;
  final FeedbackEventWriter _writeEvent;
  final Duration _networkTimeout;
  bool _reported = false;

  bool get shouldReport => selected && !_reported;

  static Future<void> _mixpanelEvent(String name, Map<String, Object> params) =>
      AnalyticsService.instance.trackStreamDiagnostics(name, params);

  /// Reserves the report synchronously, before the first await. Call before
  /// disposing the native player; [flushNetworkUsage] is requested immediately.
  /// A hanging/unsupported native counter falls back to its last observed value.
  Future<void> send({
    required StreamFeedbackMeasurement measurement,
    required StreamFeedbackContext context,
    required String endReason,
    int? fallbackNetworkBytes,
    Future<int?> Function()? flushNetworkUsage,
  }) async {
    if (!shouldReport) return;
    _reported = true;
    // Watch time excludes prerolls, pauses and buffering. This gate also
    // applies in debug mode and to sessions that encountered playback errors.
    if (measurement.watchedMs < minimumWatch.inMilliseconds) return;
    final metadata = context.parameters;
    int? bytes = fallbackNetworkBytes;
    if (flushNetworkUsage != null) {
      try {
        bytes = await flushNetworkUsage().timeout(_networkTimeout) ?? bytes;
      } catch (_) {
        // Missing measurements must not suppress the rest of the diagnostics.
      }
    }
    try {
      await _writeEvent(eventName, {
        ...metadata,
        ...measurement.parameters(totalBytes: bytes),
        'end_reason': endReason,
        'playback_health': measurement.playbackHealth,
      });
    } catch (error) {
      debugPrint(
          '[AutomaticStreamReport] Analytics unavailable: ${error.runtimeType}');
    }
  }
}
