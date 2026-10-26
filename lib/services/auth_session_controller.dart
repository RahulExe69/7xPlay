import 'package:flutter/foundation.dart';
import '../presentation/session/auth_runtime.dart';
import '../presentation/session/session_view_model.dart';

/// Adapts the typed session to the root gate used by existing routes.
class AuthSessionController {
  AuthSessionController._();
  static final AuthSessionController instance = AuthSessionController._();
  final ValueNotifier<String?> userId = ValueNotifier(null);
  SessionViewModel? _session;
  void initialize() {
    final session = AuthRuntime.maybeSession;
    if (session == null || identical(_session, session)) return;
    _session?.gateIdentity.removeListener(_update);
    _session = session;
    session.gateIdentity.addListener(_update);
    _update();
  }

  void _update() => userId.value = _session?.gateIdentity.value;

  /// Compatibility shim: Laravel actions must update SessionViewModel itself.
  void setAuthenticatedUserId(String? value) {
    if (_session == null) userId.value = value;
  }
}
