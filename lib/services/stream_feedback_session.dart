import 'dart:math';

import 'package:better_player_plus/better_player_plus.dart';

/// Content-only measurements for one player route, across source switches.
/// Shared by the optional survey and sampled automatic playback reports.
class StreamFeedbackSession {
  StreamFeedbackSession({DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _openedAt = _now();
  }

  final DateTime Function() _now;
  late final DateTime _openedAt;
  DateTime? _adStartedAt;
  int _adMs = 0;
  DateTime? _playingAt;
  DateTime? _bufferingAt;
  DateTime? _transferAt;
  int? _transferBaseline;
  Duration? _lastPosition;
  int _watchMs = 0;
  int _bufferMs = 0;
  int _bufferCount = 0;
  int _errors = 0;
  int? _startupMs;
  bool _finished = false;
  StreamFeedbackMeasurement? _frozenMeasurement;
  bool _frozen = false;

  int _since(DateTime at) => max(0, _now().difference(at).inMilliseconds);

  void _stopWatching() {
    if (_playingAt case final at?) _watchMs += _since(at);
    _playingAt = null;
  }

  void _stopBuffering() {
    if (_bufferingAt case final at?) _bufferMs += _since(at);
    _bufferingAt = null;
  }

  void onEvent(
    BetterPlayerEvent event, {
    required bool isAd,
    required bool isPlaying,
    required bool isBuffering,
    int? totalBytes,
  }) {
    if (_frozen) return;
    final type = event.betterPlayerEventType;
    if (isAd && type != BetterPlayerEventType.preRollEnded) {
      _adStartedAt ??= _now();
      _stopWatching();
      return;
    }
    if (_adStartedAt case final at?) {
      _adMs += _since(at);
      _adStartedAt = null;
      _lastPosition = null;
    }
    switch (type) {
      case BetterPlayerEventType.progress:
        final position = event.parameters?['progress'];
        if (position is! Duration) return;
        final previous = _lastPosition;
        _lastPosition = position;
        if (previous == null ||
            position <= previous ||
            !isPlaying ||
            isBuffering) {
          _stopWatching();
          return;
        }
        _startupMs ??= max(0, _since(_openedAt) - _adMs);
        _stopBuffering();
        _playingAt ??= _now();
        if (totalBytes != null && _transferBaseline == null) {
          _transferBaseline = totalBytes;
          _transferAt = _now();
        }
        break;
      case BetterPlayerEventType.networkUsage:
        if (_startupMs != null &&
            _transferBaseline == null &&
            totalBytes != null) {
          _transferBaseline = totalBytes;
          _transferAt = _now();
        }
        break;
      case BetterPlayerEventType.pause:
      case BetterPlayerEventType.seekTo:
        _stopWatching();
        _stopBuffering();
        _lastPosition = null;
        break;
      case BetterPlayerEventType.bufferingStart:
        _stopWatching();
        if (_startupMs != null && _bufferingAt == null) {
          _bufferingAt = _now();
          _bufferCount++;
        }
        break;
      case BetterPlayerEventType.bufferingEnd:
        _stopBuffering();
        break;
      case BetterPlayerEventType.exception:
        recordFailure();
        break;
      case BetterPlayerEventType.finished:
        _finished = true;
        _stopWatching();
        _stopBuffering();
        break;
      case BetterPlayerEventType.setupDataSource:
      case BetterPlayerEventType.preRollEnded:
        _stopWatching();
        _stopBuffering();
        _lastPosition = null;
        break;
      default:
        break;
    }
  }

  void recordFailure() {
    if (_frozen) return;
    _errors++;
    _stopWatching();
    _stopBuffering();
  }

  /// Includes the app's position-based completion fallback, not just native
  /// finished events. This never emits a report by itself.
  void recordCompletion() {
    if (_frozen) return;
    _finished = true;
    _stopWatching();
    _stopBuffering();
  }

  /// Freezes immediately, before the player can be disposed. Network flushing
  /// may finish later, but time and playback events can no longer change.
  StreamFeedbackMeasurement freeze() {
    if (_frozenMeasurement case final measurement?) return measurement;
    _stopWatching();
    _stopBuffering();
    _frozen = true;
    return _frozenMeasurement = StreamFeedbackMeasurement(
      sessionMs: _since(_openedAt),
      watchedMs: _watchMs,
      bufferingMs: _bufferMs,
      bufferCount: _bufferCount,
      errorCount: _errors,
      startupMs: _startupMs,
      outcome: _startupMs == null
          ? (_errors > 0 ? 'failed_to_start' : 'abandoned_before_start')
          : (_finished ? 'completed' : 'exited'),
      transferBaseline: _transferBaseline,
      transferSampleMs: _transferAt == null ? 0 : _since(_transferAt!),
    );
  }
}

class StreamFeedbackMeasurement {
  const StreamFeedbackMeasurement({
    required this.sessionMs,
    required this.watchedMs,
    required this.bufferingMs,
    required this.bufferCount,
    required this.errorCount,
    required this.startupMs,
    required this.outcome,
    required this.transferBaseline,
    required this.transferSampleMs,
  });

  final int sessionMs, watchedMs, bufferingMs, bufferCount, errorCount;
  final int? startupMs, transferBaseline;
  final int transferSampleMs;
  final String outcome;

  bool get eligible => watchedMs >= 60000 || errorCount > 0;

  /// A diagnostic label, never an inferred user rating. Raw metrics remain
  /// available when more than one problem occurred; the most severe wins here.
  String get playbackHealth {
    if (startupMs == null) {
      return errorCount > 0 ? 'failed_to_start' : 'not_observed';
    }
    if (errorCount > 0) return 'playback_errors';
    final activeMs = watchedMs + bufferingMs;
    if (bufferingMs >= 3000 && activeMs > 0 && bufferingMs / activeMs >= .05) {
      return 'heavy_buffering';
    }
    if (startupMs! >= 10000) return 'slow_start';
    if (watchedMs < 15000) return 'insufficient_playback';
    return 'no_observed_issue';
  }

  Map<String, Object> parameters({int? totalBytes}) {
    final bytes = totalBytes == null || transferBaseline == null
        ? null
        : max(0, totalBytes - transferBaseline!);
    final activeMs = watchedMs + bufferingMs;
    return {
      'session_ms': sessionMs,
      'watched_ms': watchedMs,
      'buffering_ms': bufferingMs,
      'buffer_count': bufferCount,
      'error_count': errorCount,
      if (startupMs != null) 'startup_ms': startupMs!,
      'outcome': outcome,
      'rebuffer_ratio': activeMs == 0 ? 0.0 : bufferingMs / activeMs,
      if (bytes != null) 'network_bytes': bytes,
      if (bytes != null) 'transfer_sample_ms': transferSampleMs,
      if (bytes != null && bytes > 0 && transferSampleMs >= 10000)
        'stream_mbps': bytes * 8 / (transferSampleMs * 1000),
    };
  }
}

/// Content and provider properties shared by Mixpanel surveys and reports.
/// Existing property values are preserved so saved filters remain consistent.
class StreamFeedbackContext {
  const StreamFeedbackContext({
    required this.mediaType,
    required this.surface,
    required this.provider,
    required this.initialProvider,
    required this.sourceSwitches,
    required this.connectionType,
    required this.networkChanges,
    this.tmdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.channelId,
    this.initialChannelId,
    this.videoHeight,
  });

  final String mediaType, surface, provider, initialProvider, connectionType;
  final int sourceSwitches, networkChanges;
  final int? tmdbId, seasonNumber, episodeNumber, videoHeight;
  final String? channelId, initialChannelId;

  Map<String, Object> get parameters => {
        'schema_version': 1,
        'media_type': mediaType,
        'surface': surface,
        if (mediaType != 'live_tv' && tmdbId != null)
          'tmdb_id': tmdbId.toString(),
        if (mediaType == 'tv') ...{
          // Preserve the existing season/episode values across analytics providers.
          if (seasonNumber != null) 'season_number': 's$seasonNumber',
          if (episodeNumber != null) 'episode_number': 'e$episodeNumber',
        },
        if (mediaType == 'live_tv') ...{
          if (channelId != null) 'channel_id': channelId!,
          if (initialChannelId != null) 'initial_channel_id': initialChannelId!,
        },
        'provider': provider,
        'initial_provider': initialProvider,
        'source_switches': 'switches_$sourceSwitches',
        'quality': videoHeight == null || videoHeight! <= 0
            ? 'unknown'
            : '${videoHeight}p',
        'connection_type': connectionType,
        'network_changes': networkChanges,
      };
}
