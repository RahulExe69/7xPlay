import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/error/failure.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../widgets/signed_in_device_labels.dart';
import 'page_kit.dart' show appSheetConstraints;

/// Asks which device to sign out when the account is at its device limit.
/// Returns the chosen device's id, or null when the person backs out.
Future<int?> showDeviceLimitSheet(
    BuildContext context, DeviceLimitFailure limit) {
  final palette = AppPalette.of(context);
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: palette.surface,
    constraints: appSheetConstraints(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (context) => _DeviceLimitSheet(limit: limit),
  );
}

class _DeviceLimitSheet extends StatelessWidget {
  const _DeviceLimitSheet({required this.limit});

  final DeviceLimitFailure limit;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tr('device_limit_title'),
                style: AppType.sectionHeader.copyWith(
                  fontFamily: AppType.bold,
                  fontSize: 18,
                  color: palette.foreground,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                tr('device_limit_body'),
                style: AppType.body.copyWith(color: palette.secondaryText),
              ),
            ),
            for (final device in limit.devices)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading:
                    Icon(signedInDeviceIcon(device), color: palette.foreground),
                title: Text(
                  signedInDeviceName(device),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(
                    fontFamily: AppType.semiBold,
                    fontSize: 15,
                    color: palette.foreground,
                  ),
                ),
                subtitle: switch (signedInDeviceLastUsed(context, device)) {
                  final String lastUsed => Text(lastUsed,
                      style:
                          AppType.metadata.copyWith(color: palette.mutedText)),
                  null => null,
                },
                trailing: Text(
                  tr('sign_out'),
                  style: AppType.button
                      .copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                onTap: () => Navigator.of(context).pop(device.id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('cancel')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
