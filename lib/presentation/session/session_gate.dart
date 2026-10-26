import 'package:flutter/material.dart';
import '../../services/in_app_messaging_service.dart';
import 'session_view_model.dart';

/// Replaces the app shell and removes private routes when identity changes.
class SessionGate extends StatefulWidget {
  const SessionGate({required this.session, required this.builder, super.key});
  final SessionViewModel session;
  final Widget Function(BuildContext context, bool canBrowse) builder;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  String? _identity;

  @override
  void initState() {
    super.initState();
    _identity = widget.session.gateIdentity.value;
    widget.session.addListener(_changed);
  }

  @override
  void didUpdateWidget(SessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_changed);
      widget.session.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) return;
    final identity = widget.session.gateIdentity.value;
    final identityChanged = identity != _identity;
    _identity = identity;
    setState(() {});
    if (identityChanged ||
        widget.session.state
            .maybeWhen(expired: () => true, orElse: () => false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = InAppMessagingService.navigatorKey.currentState ??
            Navigator.maybeOf(context, rootNavigator: true);
        final messenger =
            ScaffoldMessenger.maybeOf(navigator?.context ?? context);
        messenger?.clearMaterialBanners();
        messenger?.removeCurrentMaterialBanner();
        navigator?.popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.state
        .maybeWhen(initializing: () => true, orElse: () => false)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final identity = widget.session.gateIdentity.value;
    return KeyedSubtree(
        key: ValueKey(identity ?? 'signed-out'),
        child: widget.builder(context, identity != null));
  }
}
