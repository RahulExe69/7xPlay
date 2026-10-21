import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../provider/settings_provider.dart';

/// Android owns the temporary DND rule and releases it when its activity pauses.
/// Separate session IDs keep overlapping/replacement player routes safe.
class StreamingDndService {
  static const _channel = MethodChannel('dev.beamlak.flixquest/streaming_dnd');
  static int _nextSessionId = 0;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Map<String, dynamic>> status() async {
    if (!_isAndroid) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('status') ??
          const {};
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }

  static Future<bool> requestAccess() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> _setActive(int id, bool active) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSessionActive', {
        'sessionId': id,
        'active': active,
      });
    } on PlatformException catch (error) {
      debugPrint('Streaming Do Not Disturb unavailable: ${error.code}');
    } on MissingPluginException {
      // Other platforms and tests have no Android bridge.
    }
  }
}

class StreamingDndSession {
  StreamingDndSession(this._settings, {required bool television})
      : _supported = !television && StreamingDndService._isAndroid,
        _id = StreamingDndService._nextSessionId++ {
    if (_supported) {
      _settings.addListener(_sync);
      _sync();
    }
  }

  final SettingsProvider _settings;
  final bool _supported;
  final int _id;
  bool _active = false;
  bool _disposed = false;

  void _sync() {
    final active = _settings.doNotDisturbWhileStreaming;
    if (_disposed || _active == active) return;
    _active = active;
    unawaited(StreamingDndService._setActive(_id, active));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_supported) return;
    _settings.removeListener(_sync);
    if (_active) unawaited(StreamingDndService._setActive(_id, false));
  }
}
