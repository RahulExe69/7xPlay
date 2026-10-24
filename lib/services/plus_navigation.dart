import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ads/ads_policy.dart';
import '../mobile/screens/plus_screen.dart';
import '../presentation/billing/plus_controller.dart';
import '../tv/screens/tv_plus_screen.dart';
import 'device_presentation_service.dart';

/// Opens FlixQuest Plus: the TV page with its QR checkout on Android TV, the
/// phone page everywhere else.
Future<void> openPlus(BuildContext context) {
  final television = DevicePresentationService.instance.isTelevision;
  return Navigator.of(context).push<void>(MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/plus'),
    builder: (_) => television ? const TvPlusScreen() : const PlusScreen(),
  ));
}

/// A flix.quest/c/… link: the code waits in the controller, and
/// PlusCouponPrompt offers it once someone signed in can redeem it. A guest
/// is taken to Plus, which asks them to sign up first.
void openCouponLink(NavigatorState navigator, String code) {
  final plus = Provider.of<PlusController?>(navigator.context, listen: false);
  if (plus == null) return;
  plus.offerCoupon(code);
  if (!plus.signedIn) unawaited(openPlus(navigator.context));
}

/// Lets ad surfaces offer Plus ("Remove ads", the ad-blocker prompt) only
/// while it is on sale and the viewer does not have it.
void installPlusOffer() => AdsPolicy.installPlusOffer(
      offers: (context) =>
          Provider.of<PlusController?>(context, listen: false)?.shouldSuggest ??
          false,
      open: openPlus,
    );
