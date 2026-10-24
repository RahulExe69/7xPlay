import 'package:flutter/material.dart';

import '../data/ads/content_ads.dart';
import '../services/adsterra_playback_ads_service.dart';

/// For player-to-player navigation: keep the loader unconstructed until the
/// interstitial finishes, while retaining the route that will hand off playback.
class AdsterraPlaybackGate extends StatefulWidget {
  const AdsterraPlaybackGate(
      {required this.builder,
      this.television = false,
      this.content,
      super.key});
  final WidgetBuilder builder;
  final bool television;

  /// The title the loader is for; a Kids or Family title skips the ad.
  final AdContent? content;

  /// Disabled interstitials build the loader directly, without creating a gate.
  static Widget buildLoader(BuildContext context,
      {required WidgetBuilder builder,
      bool television = false,
      AdContent? content}) {
    if (!AdsterraPlaybackAdsService.instance
        .needsBeforeLoader(context, television: television, content: content)) {
      return builder(context);
    }
    return AdsterraPlaybackGate(
        builder: builder, television: television, content: content);
  }

  @override
  State<AdsterraPlaybackGate> createState() => _AdsterraPlaybackGateState();
}

class _AdsterraPlaybackGateState extends State<AdsterraPlaybackGate> {
  bool _ready = false;
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    if (!AdsterraPlaybackAdsService.instance.needsBeforeLoader(context,
        television: widget.television, content: widget.content)) {
      _ready = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final proceed = await AdsterraPlaybackAdsService.instance.beforeLoader(
          context,
          television: widget.television,
          content: widget.content);
      if (!mounted) return;
      if (proceed) {
        setState(() => _ready = true);
      } else {
        final route = ModalRoute.of(context);
        if (route?.isActive == true) Navigator.of(context).removeRoute(route!);
      }
    });
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.builder(context)
      : const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
}
