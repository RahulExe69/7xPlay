import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/billing_repository.dart';
import '../../mobile/widgets/plus_sheets.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../services/in_app_messaging_service.dart';
import '../../tv/widgets/tv_dialog.dart';
import 'plus_format.dart';

/// Offers the code from a flix.quest/c/… link as soon as someone signed in
/// can redeem it: straight away, or right after a guest signs in. Phones get
/// the redeem sheet with the code typed in; TVs a dialog to confirm.
class PlusCouponPrompt extends StatefulWidget {
  const PlusCouponPrompt({this.television = false, super.key});

  final bool television;

  @override
  State<PlusCouponPrompt> createState() => _PlusCouponPromptState();
}

class _PlusCouponPromptState extends State<PlusCouponPrompt> {
  bool _prompting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final plus = Provider.of<PlusController?>(context);
    if (plus != null &&
        plus.signedIn &&
        plus.pendingCoupon != null &&
        !_prompting) {
      _prompting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prompt(plus));
    }
  }

  Future<void> _prompt(PlusController plus) async {
    final code = plus.pendingCoupon;
    final host = InAppMessagingService.navigatorKey.currentContext;
    if (code == null || host == null || !plus.signedIn) {
      _prompting = false;
      return;
    }
    plus.takePendingCoupon();
    try {
      if (widget.television) {
        await _promptTv(host, plus, code);
      } else {
        await showRedeemSheet(host, code: code);
      }
    } finally {
      _prompting = false;
    }
  }

  Future<void> _promptTv(
      BuildContext host, PlusController plus, String code) async {
    final redeem = await showTvDialog<bool>(
      context: host,
      title: tr('plus_redeem_code_title', args: [code]),
      content: Text(tr('plus_redeem_intro')),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('plus_redeem'),
          isPrimary: true,
          onPressed: () => Navigator.of(host).pop(true),
        ),
        TvDialogAction(
          label: tr('cancel'),
          onPressed: () => Navigator.of(host).pop(false),
        ),
      ],
    );
    if (redeem != true || !host.mounted) return;
    String message;
    try {
      message = redemptionSummary(await plus.redeemCoupon(code));
    } on BillingError catch (error) {
      message = billingMessage(error);
    }
    if (!host.mounted) return;
    unawaited(showTvDialog<void>(
      context: host,
      title: tr('plus_name'),
      content: Text(message),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('plus_done'),
          isPrimary: true,
          onPressed: () => Navigator.of(host).pop(),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
