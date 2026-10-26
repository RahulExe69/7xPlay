import 'session_view_model.dart';

/// Compatibility access for existing account routes; main installs Provider too.
class AuthRuntime {
  static SessionViewModel? _session;
  static SessionViewModel get session =>
      _session ?? (throw StateError('Session is not configured'));
  static SessionViewModel? get maybeSession => _session;
  static void configure(SessionViewModel session) {
    _session = session;
  }
}
