import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'content_ads.dart';

/// Whether FlixQuest may show its ads right now. FlixQuest Plus turns every
/// placement off: banners, playback popups, VAST pre-rolls and the ad-blocker
/// checks that exist only to protect them.
///
/// Ad code checks [adFree] before any network request or side effect, and
/// again after each await, because Plus can start while an ad is loading.
/// Only the Plus controller writes it, from a backend-verified entitlement;
/// the remote ad switches in AppDependencyProvider stay untouched.
abstract final class AdsPolicy {
  static final ValueNotifier<bool> _adFree = ValueNotifier<bool>(true);

  /// Notifies when Plus starts or ends.
  static ValueListenable<bool> get listenable => _adFree;

  static bool get adFree => _adFree.value;

  /// Whether no ad may show at [context]: Plus, or a Kids or Family title's
  /// screens (see [ContentAdScope]). The title's exemption stays with its
  /// own screens and never changes [adFree].
  static bool adFreeAt(BuildContext context) =>
      adFree || ContentAdScope.adFreeAt(context);

  /// 7xCinema is permanently ad-free; remote values cannot re-enable ads.
  static void update({required bool adFree}) => _adFree.value = true;

  static void addListener(VoidCallback listener) =>
      _adFree.addListener(listener);

  static void removeListener(VoidCallback listener) =>
      _adFree.removeListener(listener);

  static bool Function(BuildContext context)? _offers;
  static Future<void> Function(BuildContext context)? _open;

  /// Lets ad surfaces point at Plus ("Remove ads") without importing its
  /// screens. [offers] says whether Plus can be bought right now.
  static void installPlusOffer({
    required bool Function(BuildContext context) offers,
    required Future<void> Function(BuildContext context) open,
  }) {
    _offers = offers;
    _open = open;
  }

  static bool offersPlus(BuildContext context) =>
      _open != null && !adFree && (_offers?.call(context) ?? false);

  static Future<void> openPlus(BuildContext context) async =>
      _open?.call(context);
}
