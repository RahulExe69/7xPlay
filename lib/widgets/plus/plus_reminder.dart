import 'package:shared_preferences/shared_preferences.dart';

/// When Home reminds a viewer about Plus, on phones and TV alike: on a day
/// it is due (every [every]), for the rest of that session, and not again
/// for [afterDismiss] once they say "Not now". Members and viewers who can't
/// buy it never see it; that is decided by the caller.
class PlusReminderSchedule {
  PlusReminderSchedule._();

  static final instance = PlusReminderSchedule._();

  static const _key = 'plus.spotlight.next_at';
  static const every = Duration(days: 2);
  static const afterDismiss = Duration(days: 7);
  static const afterOpened = Duration(days: 5);

  /// Decided once per session, so the reminder never pops in and out.
  bool? _due;
  bool _dismissed = false;
  bool _recorded = false;

  /// Whether a reminder belongs on Home this session; null until known.
  bool? get due => _dismissed ? false : _due;

  Future<bool> decide() async {
    if (_due != null) return due!;
    try {
      final preferences = await SharedPreferences.getInstance();
      _due = DateTime.now().millisecondsSinceEpoch >=
          (preferences.getInt(_key) ?? 0);
    } catch (_) {
      _due = false;
    }
    return due!;
  }

  /// The reminder was shown: the next one is [every] away.
  void shown() {
    if (_recorded) return;
    _recorded = true;
    _push(every);
  }

  void dismissed() {
    _dismissed = true;
    _push(afterDismiss);
  }

  void opened() => _push(afterOpened);

  Future<void> _push(Duration wait) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
          _key, DateTime.now().add(wait).millisecondsSinceEpoch);
    } catch (_) {/* It may show again next session. */}
  }
}
