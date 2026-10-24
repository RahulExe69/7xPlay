import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../data/ads/content_ads.dart';
import '../provider/app_dependency_provider.dart';
import '../services/device_presentation_service.dart';
import '../tv/widgets/tv_dialog.dart';
import 'ad_block_gate.dart';

/// Late positive results stop the native stream before leaving its route.
/// Fullscreen, menus and dialogs above that route leave with it.
class AdBlockPlaybackGuard extends StatefulWidget {
  const AdBlockPlaybackGuard(
      {required this.child,
      required this.stopPlayback,
      this.television = false,
      this.gate,
      super.key});
  final Widget child;
  final VoidCallback stopPlayback;
  final bool television;
  final AdBlockGate? gate;
  static const recheckInterval = Duration(seconds: 30);

  @override
  State<AdBlockPlaybackGuard> createState() => _AdBlockPlaybackGuardState();
}

class _AdBlockPlaybackGuardState extends State<AdBlockPlaybackGuard>
    with WidgetsBindingObserver {
  late final AdBlockGate _gate = widget.gate ?? AdBlockGate.instance;
  AppDependencyProvider? _provider;
  Timer? _nextCheck;
  bool _checking = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _gate.addListener(_onResult);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.watch<AppDependencyProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onResult();
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        _handled ||
        _checking ||
        ContentAdScope.adFreeAt(context) ||
        _provider?.adBlockGateEnabled != true ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    _nextCheck?.cancel();
    _checking = true;
    try {
      await _gate.warmUp(context);
    } finally {
      _checking = false;
      final state = WidgetsBinding.instance.lifecycleState;
      if (mounted &&
          !_handled &&
          (state == null || state == AppLifecycleState.resumed)) {
        _nextCheck = Timer(
            AdBlockPlaybackGuard.recheckInterval, () => unawaited(_refresh()));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _nextCheck?.cancel();
    if (state == AppLifecycleState.resumed) {
      _gate.invalidate();
      unawaited(_refresh());
    }
  }

  void _onResult() {
    final provider = _provider;
    if (!mounted ||
        _handled ||
        provider == null ||
        ContentAdScope.adFreeAt(context) ||
        !_gate.blocksPlayback(provider)) {
      return;
    }
    _handled = true;
    _nextCheck?.cancel();
    // Stop synchronously; navigation and platform view removal may need a frame.
    try {
      widget.stopPlayback();
    } catch (error) {
      debugPrint('[AdBlockPlaybackGuard] stop failed; closing player: $error');
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leavePlayer());
    } else {
      _leavePlayer();
    }
  }

  void _leavePlayer() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    final root = Navigator.of(context, rootNavigator: true);
    final television =
        widget.television || DevicePresentationService.instance.isTelevision;
    if (root != navigator) {
      final anchor = ModalRoute.of(navigator.context);
      if (anchor != null) {
        _removeAbove(root, anchor);
      }
    }
    _removeAbove(navigator, route);
    if (route.isFirst) {
      // A player opened as the app's initial route still loses its video UI.
      navigator.pushReplacement<void, void>(PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => Scaffold(
              body: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr('ad_blocker_playback_stopped')))))));
      return;
    } else {
      navigator.removeRoute(route);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messageContext = root.overlay?.context;
      if (root.mounted && messageContext != null) {
        unawaited(_showStoppedMessage(messageContext, television));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _removeAbove(NavigatorState navigator, Route<dynamic> anchor) {
    // Do not leave fullscreen/menu exit animations rendering a controller
    // that has already been torn down. Reading the top route with a true
    // predicate does not pop it; removeRoute then removes it without a fade.
    while (navigator.mounted && anchor.isActive) {
      Route<dynamic>? top;
      navigator.popUntil((candidate) {
        top = candidate;
        return true;
      });
      if (top == null || top == anchor || top!.isFirst) return;
      navigator.removeRoute(top!);
    }
  }

  Future<void> _showStoppedMessage(
      BuildContext context, bool television) async {
    if (television) {
      await showTvDialog<void>(
          context: context,
          title: tr('ad_blocker_title'),
          content: Text(tr('ad_blocker_playback_stopped')),
          actions: [
            TvDialogAction(
                label: tr('close'),
                isPrimary: true,
                onPressed: () => Navigator.pop(context))
          ]);
    } else {
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: Text(tr('ad_blocker_title')),
                content: Text(tr('ad_blocker_playback_stopped')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(tr('close')))
                ],
              ));
    }
  }

  @override
  void dispose() {
    _gate.removeListener(_onResult);
    WidgetsBinding.instance.removeObserver(this);
    _nextCheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
