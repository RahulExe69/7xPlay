import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The one owner of the screen-on flag during playback.
///
/// Every player holds it under its own key while playback is expected and
/// lets go when it is not (paused, failed for good, or gone). The flag is on
/// while anyone holds it, so a player being torn down late, after its
/// replacement has started, cannot switch the screen off under the new one.
///
/// The flag lives on the Activity's window, where anything else can clear it
/// (Fire OS window transitions among them), so while it is held it is set
/// again on resume and on a [heartbeat] rather than trusted to stay set.
class PlaybackWakeLock with WidgetsBindingObserver {
  PlaybackWakeLock({
    Future<void> Function(bool enable)? toggle,
    this.heartbeat = const Duration(seconds: 30),
  }) : _toggle = toggle ?? ((enable) => WakelockPlus.toggle(enable: enable));

  static final PlaybackWakeLock instance = PlaybackWakeLock();

  final Future<void> Function(bool enable) _toggle;

  /// Fire TV's shortest screen saver timeout is five minutes, so a flag
  /// cleared behind our back comes back long before it matters.
  final Duration heartbeat;

  final Set<Object> _holders = <Object>{};
  Timer? _heartbeatTimer;
  bool _observing = false;

  /// Whether some player is holding the screen on.
  bool get isHeld => _holders.isNotEmpty;

  /// Holds the screen on for [owner] while [wanted], else lets [owner] go.
  void set(Object owner, {required bool wanted}) {
    final changed = wanted ? _holders.add(owner) : _holders.remove(owner);
    if (changed) _sync();
  }

  void hold(Object owner) => set(owner, wanted: true);

  void release(Object owner) => set(owner, wanted: false);

  void _sync() {
    final held = isHeld;
    debugPrint('[PlaybackWake] ${held ? 'hold' : 'release'} '
        '(holders: ${_holders.length})');
    if (held) {
      _heartbeatTimer ??= Timer.periodic(heartbeat, (_) => _apply());
      if (!_observing) {
        _observing = true;
        WidgetsBinding.instance.addObserver(this);
      }
    } else {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      if (_observing) {
        _observing = false;
        WidgetsBinding.instance.removeObserver(this);
      }
    }
    _apply();
  }

  /// Writes the current state to the window. The plugin only touches the
  /// flag when it differs, so repeating this is cheap.
  Future<void> _apply() async {
    final held = isHeld;
    try {
      await _toggle(held);
    } catch (error) {
      // Without an Activity (mid recreation) there is no window to flag; the
      // next resume or heartbeat tries again.
      debugPrint('[PlaybackWake] could not ${held ? 'set' : 'clear'} '
          'the screen-on flag: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isHeld) _apply();
  }
}
