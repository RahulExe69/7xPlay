import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stream_feedback_session.dart';
import 'analytics_service.dart';

typedef FeedbackEventWriter = Future<void> Function(
    String name, Map<String, Object> parameters);

/// Uses the app's Mixpanel service; no Firestore documents or extra backend.
/// Debug and release builds share the same sampling, watch-time eligibility
/// and cooldown rules. Tests may explicitly override those rules.
class StreamFeedbackService {
  StreamFeedbackService({
    Future<SharedPreferences> Function()? preferences,
    FeedbackEventWriter? writeEvent,
    DateTime Function()? now,
    int Function(int)? draw,
    bool debugAlwaysReport = false,
  })  : _preferences = preferences ?? SharedPreferences.getInstance,
        _writeEvent = writeEvent ?? _mixpanelEvent,
        _now = now ?? DateTime.now,
        _draw = draw ?? Random().nextInt,
        _debugAlwaysReport = debugAlwaysReport;

  static final instance = StreamFeedbackService();
  static const cooldownKey = 'stream_feedback_last_shown_ms_v1';
  static const cooldown = Duration(days: 3);
  final Future<SharedPreferences> Function() _preferences;
  final FeedbackEventWriter _writeEvent;
  final DateTime Function() _now;
  final int Function(int) _draw;
  final bool _debugAlwaysReport;
  bool _reserved = false;

  static Future<void> _mixpanelEvent(String name, Map<String, Object> params) =>
      AnalyticsService.instance.trackStreamDiagnostics(name, params);

  Future<bool> reserve(StreamFeedbackMeasurement measurement) async {
    if (_reserved) return false;
    if (_debugAlwaysReport) {
      _reserved = true;
      return true;
    }
    if (!measurement.eligible || _draw(10) != 0) return false;
    _reserved = true;
    try {
      final prefs = await _preferences();
      final last = prefs.getInt(cooldownKey);
      if (last != null &&
          _now().millisecondsSinceEpoch - last < cooldown.inMilliseconds) {
        _reserved = false;
        return false;
      }
      return true;
    } catch (_) {
      _reserved = false;
      return false;
    }
  }

  Future<void> markShown() async {
    // Emulator/debug testing must not change the production cooldown.
    if (_debugAlwaysReport) return;
    try {
      final prefs = await _preferences();
      await prefs.setInt(cooldownKey, _now().millisecondsSinceEpoch);
    } catch (_) {
      // Preference failures must never hold navigation or feedback open.
    }
  }

  void release() => _reserved = false;

  Future<void> track(String action, Map<String, Object> parameters) async {
    try {
      await _writeEvent('stream_feedback_$action', parameters);
    } catch (error) {
      debugPrint(
          '[StreamFeedback] Analytics unavailable: ${error.runtimeType}');
    }
  }
}

/// Connection transport is context, not an internet speed/reachability test.
class StreamFeedbackConnection {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  String type = 'unknown';
  int changes = 0;
  bool _disposed = false;
  bool _receivedUpdate = false;

  void start() {
    final connectivity = Connectivity();
    _subscription = connectivity.onConnectivityChanged.listen(
      (results) {
        _receivedUpdate = true;
        _update(results);
      },
      onError: (Object _) {},
    );
    unawaited(connectivity.checkConnectivity().then((results) {
      if (!_receivedUpdate) _update(results);
    }).catchError((Object _) {}));
  }

  void _update(List<ConnectivityResult> results) {
    if (_disposed) return;
    final names = results.map((result) => result.name).toSet().toList()..sort();
    final next = names.isEmpty ? 'unknown' : names.join('_');
    if (type != 'unknown' && type != next) changes++;
    type = next;
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
  }
}
