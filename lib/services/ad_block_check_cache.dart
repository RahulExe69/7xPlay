import 'dart:async';
import 'package:flutter/foundation.dart';

/// Shares a background scan between browsing, Play and its loader. A short
/// foreground deadline never turns an unfinished scan into a cached pass.
class AdBlockCheckCache extends ChangeNotifier {
  AdBlockCheckCache({
    this.foregroundWait = Duration.zero,
    this.validFor = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration foregroundWait;
  final Duration validFor;
  final DateTime Function() _now;
  Object? _key;
  Future<bool>? _pending;
  DateTime? _startedAt;
  DateTime? _completedAt;
  bool? _result;
  int _generation = 0;

  bool isBlocked(Object key) =>
      _key == key &&
      _result == true &&
      _completedAt != null &&
      _now().difference(_completedAt!) < validFor;

  void invalidate() {
    _generation++;
    _key = null;
    _pending = null;
    _result = null;
    _completedAt = null;
    _startedAt = null;
    notifyListeners();
  }

  Future<bool> warm(Object key, Future<bool> Function() scan) {
    final completed = _completedAt;
    if (_key == key &&
        completed != null &&
        _now().difference(completed) < validFor) {
      return Future.value(_result!);
    }
    if (_key == key && _pending != null) return _pending!;
    invalidate();
    _key = key;
    _startedAt = _now();
    final generation = _generation;
    final pending = Future<bool>.sync(scan);
    _pending = pending;
    // Install error handling immediately, including when nobody awaits warmup.
    return _pending = pending.then((blocked) {
      if (generation == _generation) {
        _result = blocked;
        _completedAt = _now();
        _pending = null;
        notifyListeners();
      }
      return blocked;
    }, onError: (Object _, StackTrace __) {
      if (generation == _generation) invalidate();
      return false;
    });
  }

  /// Null means the foreground budget expired or this scan became stale.
  Future<bool?> check(Object key, Future<bool> Function() scan) async {
    final pending = warm(key, scan);
    final generation = _generation;
    if (_completedAt != null) return _result;
    // A second loader shares the original deadline rather than waiting again.
    var remaining = foregroundWait - _now().difference(_startedAt!);
    if (remaining > foregroundWait) remaining = foregroundWait;
    if (remaining <= Duration.zero) return null;
    final result = await pending.timeout(remaining, onTimeout: () => false);
    if (generation != _generation) return null;
    // Only the full scan sets _completedAt, never the foreground timeout.
    return _completedAt == null ? null : result;
  }
}
