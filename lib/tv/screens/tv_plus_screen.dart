import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../app/tv_design.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_pill_button.dart';

/// FlixQuest Plus on Android TV. Nobody types a wallet address with a
/// remote: the TV shows a large QR code of this account's own checkout, the
/// viewer pays on their phone, and the TV waits for Laravel to confirm.
class TvPlusScreen extends StatefulWidget {
  const TvPlusScreen({super.key});

  @override
  State<TvPlusScreen> createState() => _TvPlusScreenState();
}

class _TvPlusScreenState extends State<TvPlusScreen> {
  String? _message;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final plus = context.read<PlusController>();
      unawaited(plus.refresh(full: true));
      if (plus.catalog == null) unawaited(plus.refreshCatalog());
      unawaited(prepareDates(context).then((_) {
        if (mounted) setState(() {});
      }));
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await action();
    } on BillingError catch (error) {
      if (mounted) setState(() => _message = billingMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  int _price(PlusController plus) =>
      plus.plan?.amountCents ?? plus.renewal?.amountCents ?? 200;

  int _interval(PlusController plus) =>
      plus.plan?.intervalDays ?? plus.renewal?.intervalDays ?? 31;

  Future<void> _topUp(PlusController plus, int cents) async {
    var activate = false;
    if (!plus.adFree && plus.renewal?.autoRenew != true) {
      final choice = await showTvDialog<bool>(
        context: context,
        title: tr('plus_tv_start_with_topup', args: [formatUsd(cents)]),
        content: Text(tr('plus_start_when_confirmed_consent',
            args: [formatUsd(_price(plus)), '${_interval(plus)}'])),
        actions: <TvDialogAction>[
          TvDialogAction(
            label: tr('plus_tv_topup_and_start'),
            isPrimary: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          TvDialogAction(
            label: tr('plus_tv_only_add_funds'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      );
      if (choice == null || !mounted) return;
      activate = choice;
    }
    await _run(() => plus.startTopup(cents, activatePlus: activate));
  }

  Future<void> _enable(PlusController plus) async {
    final chargesNow = !plus.adFree;
    final until = plus.activeUntil;
    final agreed = await showTvDialog<bool>(
      context: context,
      title: chargesNow ? tr('plus_start_plus') : tr('plus_turn_on_renewal'),
      content: Text(
        '${chargesNow ? tr('plus_consent_now', args: [
                formatUsd(_price(plus)),
                '${_interval(plus)}'
              ]) : tr('plus_consent_later', args: [
                formatUsd(_price(plus)),
                until == null ? '' : formatDay(context, until),
                '${_interval(plus)}'
              ])}\n\n${tr('plus_consent_stop_anytime')}',
      ),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('plus_agree_and_continue'),
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        TvDialogAction(
          label: tr('cancel'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
    if (agreed == true && mounted) await _run(plus.enableRenewal);
  }

  Future<void> _disable(PlusController plus) async {
    final until = plus.activeUntil;
    final confirmed = await showTvDialog<bool>(
      context: context,
      title: tr('plus_turn_off_renewal'),
      content: Text(until == null
          ? tr('plus_turn_off_body_no_time')
          : tr('plus_turn_off_body', args: [formatDay(context, until)])),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('cancel'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        TvDialogAction(
          label: tr('plus_turn_off'),
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed == true && mounted) await _run(plus.disableRenewal);
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController>();
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: LayoutBuilder(builder: (context, constraints) {
        final metrics = TvShellMetrics.fromConstraints(constraints);
        final compact = metrics.compact;
        final gap = compact ? 20.0 : 32.0;
        return Padding(
          padding: EdgeInsets.all(metrics.safeInset + metrics.contentPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: _StatusPanel(plus: plus, compact: compact),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 6,
                child: FocusTraversalGroup(
                  child: _actions(context, plus, compact),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _actions(BuildContext context, PlusController plus, bool compact) {
    final palette = TvPalette.of(context);
    final topup = plus.topup;
    final title = TextStyle(
      fontFamily: 'FigtreeBold',
      fontSize: compact ? 24 : 30,
      height: 1.1,
      color: palette.foreground,
    );
    final body = TextStyle(
      fontSize: compact ? 14 : 17,
      height: 1.4,
      color: palette.mutedText,
    );
    final message = _message == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(_message!,
                style:
                    body.copyWith(color: Theme.of(context).colorScheme.error)),
          );

    if (!plus.signedIn) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(tr('plus_tv_sign_in_title'), style: title),
          const SizedBox(height: 12),
          Text(tr('plus_tv_sign_in_body'), style: body),
          const SizedBox(height: 26),
          TvPillButton(
            label: tr('plus_sign_in_to_get'),
            icon: PhosphorIcons.signIn(),
            autofocus: true,
            prominent: true,
            onActivate: () async {
              await FlixQuestAuthService().signOut();
              if (context.mounted) {
                await AuthNavigationService.returnToSignedOutRoot(context);
              }
            },
          ),
        ],
      );
    }

    if (topup != null) {
      return _CheckoutPanel(
        key: ValueKey(topup.id),
        plus: plus,
        topup: topup,
        compact: compact,
        message: message,
      );
    }

    final suggested =
        (plus.catalog?.wallet ?? const TopupLimits()).offeredCents;
    final fundable = (plus.wallet?.spendableCents ?? 0) >= _price(plus);
    final open = plus.catalog?.purchasesEnabled ?? false;
    final renewing = plus.renewal?.autoRenew == true;
    final frozen = plus.wallet?.frozen == true;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!plus.adFree && fundable) ...<Widget>[
          Text(tr('plus_tv_ready_title'), style: title),
          const SizedBox(height: 10),
          Text(
              tr('plus_tv_ready_body', args: [
                formatUsd(plus.wallet?.spendableCents ?? 0),
                formatUsd(_price(plus))
              ]),
              style: body),
          const SizedBox(height: 22),
          TvPillButton(
            label:
                tr('plus_start_from_balance', args: [formatUsd(_price(plus))]),
            leading: const PlusMark(),
            autofocus: true,
            prominent: true,
            enabled: !_working,
            onActivate: () => _enable(plus),
          ),
          const SizedBox(height: 30),
        ],
        Text(tr('plus_add_funds'), style: title),
        const SizedBox(height: 10),
        Text(
          frozen
              ? tr('plus_wallet_on_hold_body')
              : open
                  ? tr('plus_tv_add_funds_body')
                  : tr('plus_not_on_sale'),
          style: body,
        ),
        const SizedBox(height: 20),
        if (open && !frozen)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (var i = 0; i < suggested.length; i++)
                TvPillButton(
                  label: formatPrice(suggested[i]),
                  autofocus: i == 0 && (plus.adFree || !fundable),
                  prominent: suggested[i] == 1000,
                  enabled: !_working,
                  onActivate: () => _topUp(plus, suggested[i]),
                ),
            ],
          ),
        if (plus.adFree || renewing) ...<Widget>[
          const SizedBox(height: 30),
          TvPillButton(
            label: renewing
                ? tr('plus_turn_off_renewal')
                : tr('plus_turn_on_renewal'),
            icon: renewing
                ? PhosphorIcons.pause()
                : PhosphorIcons.arrowsClockwise(),
            autofocus: !open || frozen,
            enabled: !_working,
            onActivate: () => renewing ? _disable(plus) : _enable(plus),
          ),
        ],
        message,
        const SizedBox(height: 22),
        Text(tr('plus_tv_redeem_hint'),
            style: body.copyWith(fontSize: compact ? 12 : 14)),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.plus, required this.compact});

  final PlusController plus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final until = plus.activeUntil;
    final ends = plus.entitlement?.expiresAt;
    final price = plus.plan?.amountCents ?? 200;
    final interval = plus.plan?.intervalDays ?? 31;
    final renewal = plus.renewal;
    final body = TextStyle(
      fontFamily: 'Figtree',
      fontSize: compact ? 14 : 17,
      height: 1.45,
      color: PlusColors.mutedInk,
    );
    return PlusAurora(
      borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
      child: Padding(
        padding: EdgeInsets.all(compact ? 24 : 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PlusWordmark(size: compact ? 30 : 40),
            const Spacer(),
            if (plus.adFree && ends != null) ...<Widget>[
              PlusPeriodRing(
                used: plus.periodProgress,
                size: compact ? 110 : 150,
                stroke: compact ? 7 : 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${daysLeft(plus.serverNow, ends)}',
                      style: TextStyle(
                        fontFamily: 'FigtreeBlack',
                        fontSize: compact ? 32 : 44,
                        height: 1,
                        color: PlusColors.ink,
                      ),
                    ),
                    Text(
                      plural('plus_days_left', daysLeft(plus.serverNow, ends)),
                      style: TextStyle(
                        fontFamily: 'FigtreeSB',
                        fontSize: compact ? 11 : 13,
                        color: PlusColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 26),
            ] else ...<Widget>[
              PlusEmblem(size: compact ? 72 : 96),
              SizedBox(height: compact ? 18 : 26),
            ],
            Text(
              plus.adFree ? tr('plus_youre_ad_free') : tr('plus_headline'),
              style: TextStyle(
                fontFamily: 'FigtreeBold',
                fontSize: compact ? 28 : 38,
                height: 1.1,
                letterSpacing: -.6,
                color: PlusColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              until != null
                  ? renewal?.autoRenew == true
                      ? tr('plus_renews_on', args: [formatDay(context, until)])
                      : tr('plus_ad_free_until',
                          args: [formatDay(context, until)])
                  : tr('plus_price_line',
                      args: [formatPrice(price), '$interval']),
              style: body,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (plus.signedIn)
                  PlusChip(
                    icon: PhosphorIcons.wallet(),
                    label: tr('plus_balance_chip',
                        args: [formatUsd(plus.wallet?.spendableCents ?? 0)]),
                  ),
                PlusChip(
                    icon: PhosphorIcons.prohibit(),
                    label: tr('plus_tv_chip_no_ads')),
                PlusChip(
                    icon: PhosphorIcons.deviceMobile(),
                    label: tr('plus_tv_chip_devices')),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({
    required this.plus,
    required this.topup,
    required this.compact,
    required this.message,
    super.key,
  });

  final PlusController plus;
  final WalletTopup topup;
  final bool compact;
  final Widget message;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final url = topup.checkoutUrl;
    final scannable = topup.isOpen &&
        topup.nextAction == 'open_checkout' &&
        isTrustedCheckout(url);
    final title = TextStyle(
      fontFamily: 'FigtreeBold',
      fontSize: compact ? 24 : 30,
      height: 1.1,
      color: palette.foreground,
    );
    final body = TextStyle(
      fontSize: compact ? 14 : 17,
      height: 1.4,
      color: palette.mutedText,
    );
    final (heading, detail) = topup.settled
        ? (
            tr('plus_payment_received'),
            topup.activatePlus && plus.adFree
                ? tr('plus_payment_received_plus', args: [
                    formatDay(context, plus.activeUntil ?? DateTime.now())
                  ])
                : tr('plus_payment_received_balance',
                    args: [formatUsd(plus.wallet?.spendableCents ?? 0)])
          )
        : topup.failed
            ? (tr('plus_payment_failed'), tr('plus_payment_nothing_charged'))
            : topup.status == 'partially_paid'
                ? (tr('plus_payment_partial'), tr('plus_payment_partial_body'))
                : scannable
                    ? (
                        tr('plus_tv_scan_title',
                            args: [formatUsd(topup.amountCents)]),
                        tr('plus_tv_scan_body')
                      )
                    : (
                        tr('plus_payment_preparing'),
                        tr('plus_payment_preparing_body')
                      );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (scannable) ...<Widget>[
          Semantics(
            label:
                tr('plus_tv_scan_title', args: [formatUsd(topup.amountCents)]),
            image: true,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
              ),
              child: QrImageView(
                data: url!,
                size: compact ? 176 : 300,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(18),
              ),
            ),
          ),
          SizedBox(width: compact ? 20 : 36),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!scannable && topup.isOpen)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: palette.mutedText),
                  ),
                ),
              Text(heading, style: title),
              const SizedBox(height: 10),
              Text(detail, style: body),
              if (topup.isOpen) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  plus.topupWatchExpired
                      ? tr('plus_payment_still_waiting_body')
                      : tr('plus_tv_waiting_line'),
                  style: body.copyWith(fontSize: compact ? 12 : 14),
                ),
              ],
              message,
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  if (topup.isOpen)
                    TvPillButton(
                      label: tr('plus_check_now'),
                      icon: PhosphorIcons.arrowsClockwise(),
                      autofocus: true,
                      prominent: true,
                      onActivate: () => plus.checkTopup(manual: true),
                    ),
                  TvPillButton(
                    label: topup.isOpen
                        ? tr('plus_tv_pay_later')
                        : tr('plus_done'),
                    autofocus: !topup.isOpen,
                    prominent: !topup.isOpen,
                    onActivate: plus.dismissTopup,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                tr('plus_reference', args: [topup.id]),
                style: body.copyWith(fontSize: compact ? 11 : 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
