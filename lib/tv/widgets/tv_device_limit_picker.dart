import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/error/failure.dart';
import '../../widgets/signed_in_device_labels.dart';
import 'tv_dialog.dart';
import 'tv_list_row.dart';

/// Asks which device to sign out when the account is at its device limit,
/// one row per device. Returns the chosen device's id, or null on Back or
/// Cancel.
Future<int?> showTvDeviceLimitPicker(
    BuildContext context, DeviceLimitFailure limit) {
  return showTvDialog<int>(
    context: context,
    barrierDismissible: true,
    title: tr('device_limit_title'),
    autofocusFirstAction: false,
    content: Builder(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(tr('device_limit_body')),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .45),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final (index, device) in limit.devices.indexed)
                    TvListRow(
                      autofocus: index == 0,
                      label: signedInDeviceName(device),
                      icon: signedInDeviceIcon(device),
                      value: signedInDeviceLastUsed(context, device),
                      showsNext: false,
                      semanticLabel:
                          '${tr('sign_out')} ${signedInDeviceName(device)}',
                      onActivate: () => Navigator.of(context).pop(device.id),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    actions: <TvDialogAction>[
      TvDialogAction(
        label: tr('cancel'),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
