import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/models/signed_in_device.dart';

/// The device's own name, or what kind of device it is when the app that
/// signed in did not send one.
String signedInDeviceName(SignedInDevice device) =>
    device.name ??
    switch (device.platform) {
      'tv' => tr('device_platform_tv'),
      'ios' => tr('device_platform_ios'),
      'android' => tr('device_platform_android'),
      _ => tr('device_unknown'),
    };

/// "Last used Oct 26, 2026", from when it last reached FlixQuest.
String? signedInDeviceLastUsed(BuildContext context, SignedInDevice device) {
  final at = device.lastUsedAt ?? device.signedInAt;
  if (at == null) return null;
  return tr('device_last_used', namedArgs: {
    'date': DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .format(at.toLocal()),
  });
}

IconData signedInDeviceIcon(SignedInDevice device) => switch (device.platform) {
      'tv' => PhosphorIcons.television(),
      'ios' || 'android' => PhosphorIcons.deviceMobile(),
      _ => PhosphorIcons.devices(),
    };
