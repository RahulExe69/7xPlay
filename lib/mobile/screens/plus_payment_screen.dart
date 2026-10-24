import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/billing.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/plus_sheets.dart';

/// Opens the payment screen for [topup], and NOWPayments' page with it when
/// [openCheckout].
Future<void> openPlusPayment(BuildContext context, WalletTopup topup,
    {bool openCheckout = false}) {
  final plus = context.read<PlusController>();
  if (plus.topup?.id != topup.id) plus.followTopup(topup);
  return Navigator.of(context).push<void>(MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/plus/payment'),
    builder: (_) => PlusPaymentScreen(openCheckout: openCheckout),
  ));
}

/// Opens a NOWPayments checkout in the browser; false when there is none or
/// it is not one of NOWPayments' own pages.
Future<bool> launchCheckout(WalletTopup topup) async {
  final url = topup.checkoutUrl;
  if (!isTrustedCheckout(url)) return false;
  try {
    return await launchUrl(Uri.parse(url!),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

enum _Step { page, payment, confirming, credited }

/// "Confirming payment" until Laravel credits the top-up. Closing the
/// browser or seeing NOWPayments' success page proves nothing; only this
/// screen's answer from Laravel does.
class PlusPaymentScreen extends StatefulWidget {
  const PlusPaymentScreen({this.openCheckout = false, super.key});

  final bool openCheckout;

  @override
  State<PlusPaymentScreen> createState() => _PlusPaymentScreenState();
}

class _PlusPaymentScreenState extends State<PlusPaymentScreen> {
  bool _launchFailed = false;
  bool _opened = false;
  late final PlusController _plus = context.read<PlusController>();

  @override
  void initState() {
    super.initState();
    _plus;
    if (widget.openCheckout) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  Future<void> _open() async {
    final topup = context.read<PlusController>().topup;
    if (topup == null) return;
    final launched = await launchCheckout(topup);
    if (mounted) {
      setState(() {
        _launchFailed = !launched;
        _opened = _opened || launched;
      });
    }
  }

  @override
  void dispose() {
    // A finished top-up has been seen; an open one stays followed.
    final topup = _plus.topup;
    if (topup != null && !topup.isOpen) scheduleMicrotask(_plus.dismissTopup);
    super.dispose();
  }

  _Step _step(WalletTopup topup) {
    if (topup.settled) return _Step.credited;
    if (topup.status == 'creating' || topup.status == 'unknown') {
      return _Step.page;
    }
    if (topup.payCurrency != null || topup.status == 'partially_paid') {
      return _Step.confirming;
    }
    return _opened ? _Step.payment : _Step.page;
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController>();
    final palette = AppPalette.of(context);
    final topup = plus.topup;
    final gutter = AppSpace.gutter(context);
    if (topup == null) {
      return Scaffold(
        backgroundColor: palette.page,
        appBar: PageAppBar(title: tr('plus_payment')),
        body: EmptyState(
          icon: PhosphorIcons.receipt(),
          title: tr('plus_no_payment'),
        ),
      );
    }
    final step = _step(topup);
    final (title, body) = _copy(topup, plus);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('plus_payment')),
      body: ReadableWidth(
        maxWidth: 560,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter,
              AppSpace.xxxl + MediaQuery.paddingOf(context).bottom),
          children: <Widget>[
            PlusAurora(
              borderRadius: BorderRadius.circular(AppRadii.hero),
              energy: topup.settled ? 1.4 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  children: <Widget>[
                    _StatusOrb(topup: topup),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      formatUsd(topup.amountCents),
                      style: const TextStyle(
                        fontFamily: 'FigtreeBlack',
                        fontSize: 40,
                        height: 1,
                        letterSpacing: -1,
                        color: PlusColors.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'FigtreeBold',
                        fontSize: 19,
                        color: PlusColors.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 14,
                        height: 1.45,
                        color: PlusColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            if (!topup.failed) ...<Widget>[
              for (final value in _Step.values)
                _StepRow(
                  label: tr('plus_step_${value.name}'),
                  state: value.index < step.index ||
                          (topup.settled && value == _Step.credited)
                      ? _StepState.done
                      : value == step
                          ? _StepState.current
                          : _StepState.later,
                  last: value == _Step.credited,
                ),
              const SizedBox(height: AppSpace.xl),
            ],
            if (topup.isOpen) ...<Widget>[
              _ExactAmountNote(),
              const SizedBox(height: AppSpace.lg),
            ],
            if (_launchFailed && topup.isOpen) ...<Widget>[
              Text(
                tr('plus_checkout_open_failed'),
                style: AppType.body
                    .copyWith(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AppSpace.md),
            ],
            ..._actions(context, plus, topup),
            const SizedBox(height: AppSpace.xxl),
            Text(
              topup.isOpen
                  ? tr('plus_payment_keep_checking')
                  : tr('plus_payment_reference_hint'),
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
            const SizedBox(height: AppSpace.sm),
            _Reference(id: topup.id),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(
      BuildContext context, PlusController plus, WalletTopup topup) {
    if (topup.settled) {
      return <Widget>[
        PillButton(
          label: tr('plus_done'),
          primary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    }
    if (topup.failed) {
      return <Widget>[
        PillButton(
          label: tr('plus_try_again'),
          icon: PhosphorIcons.arrowClockwise(),
          primary: true,
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(showAddFundsSheet(context));
          },
        ),
      ];
    }
    final payable = topup.nextAction == 'open_checkout' &&
        isTrustedCheckout(topup.checkoutUrl);
    return <Widget>[
      if (payable)
        PillButton(
          label: _opened
              ? tr('plus_reopen_payment_page')
              : tr('plus_open_payment_page'),
          icon: PhosphorIcons.arrowSquareOut(),
          primary: !_opened,
          onPressed: _open,
        ),
      const SizedBox(height: AppSpace.md),
      PillButton(
        label: plus.checkingTopup ? tr('plus_checking') : tr('plus_check_now'),
        icon: PhosphorIcons.arrowsClockwise(),
        primary: _opened || !payable,
        busy: plus.checkingTopup,
        onPressed: () => unawaited(plus.checkTopup(manual: true)),
      ),
    ];
  }

  (String, String) _copy(WalletTopup topup, PlusController plus) {
    if (topup.settled) {
      final started = topup.activatePlus && plus.adFree;
      return (
        tr('plus_payment_received'),
        started
            ? tr('plus_payment_received_plus',
                args: [formatDay(context, plus.activeUntil ?? DateTime.now())])
            : tr('plus_payment_received_balance',
                args: [formatUsd(plus.wallet?.spendableCents ?? 0)]),
      );
    }
    return switch (topup.status) {
      'partially_paid' => (
          tr('plus_payment_partial'),
          tr('plus_payment_partial_body')
        ),
      'expired' => (
          tr('plus_payment_expired'),
          tr('plus_payment_nothing_charged')
        ),
      'failed' => (
          tr('plus_payment_failed'),
          tr('plus_payment_nothing_charged')
        ),
      'reversed' => (
          tr('plus_payment_reversed'),
          tr('plus_payment_reversed_body')
        ),
      'creating' || 'unknown' => (
          tr('plus_payment_preparing'),
          tr('plus_payment_preparing_body')
        ),
      _ => plus.topupWatchExpired
          ? (
              tr('plus_payment_still_waiting'),
              tr('plus_payment_still_waiting_body')
            )
          : (tr('plus_payment_waiting'), tr('plus_payment_waiting_body')),
    };
  }
}

/// The emblem inside a slowly turning ring while the payment is open; a
/// check once it is credited, a cross when it failed.
class _StatusOrb extends StatefulWidget {
  const _StatusOrb({required this.topup});

  final WalletTopup topup;

  @override
  State<_StatusOrb> createState() => _StatusOrbState();
}

class _StatusOrbState extends State<_StatusOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StatusOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.topup.isOpen && !still) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topup = widget.topup;
    final Widget centre = topup.settled
        ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            size: 62, color: PlusColors.gold)
        : topup.failed
            ? Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                size: 62, color: PlusColors.coral)
            : const PlusEmblem(size: 58);
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (topup.isOpen)
            RotationTransition(
              turns: _spin,
              child: CustomPaint(
                size: const Size.square(96),
                painter: _OrbitPainter(),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale:
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: child,
            ),
            child: KeyedSubtree(key: ValueKey(topup.status), child: centre),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    canvas.drawArc(
      rect,
      0,
      4.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..shader = const SweepGradient(colors: <Color>[
          Color(0x00FFC56B),
          PlusColors.gold,
        ], stops: <double>[
          0,
          .7
        ]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => false;
}

enum _StepState { done, current, later }

class _StepRow extends StatelessWidget {
  const _StepRow(
      {required this.label, required this.state, required this.last});

  final String label;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final done = state == _StepState.done;
    final current = state == _StepState.current;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Column(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? palette.focusFill : Colors.transparent,
                    border: Border.all(
                      color: done || current
                          ? palette.foreground
                          : palette.idleFillStrong,
                      width: current ? 2 : 1.5,
                    ),
                  ),
                  child: done
                      ? Icon(PhosphorIcons.check(),
                          size: 13, color: palette.onFocus)
                      : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: done ? palette.foreground : palette.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1, bottom: AppSpace.lg),
              child: Text(
                label,
                style: AppType.cardTitle.copyWith(
                  fontSize: 15,
                  color: state == _StepState.later
                      ? palette.mutedText
                      : palette.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exchanges often round a send to "2 USDT"; the invoice needs every decimal.
class _ExactAmountNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(PhosphorIcons.warningCircle(),
              size: 20, color: palette.foreground),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              tr('plus_payment_exact_amount'),
              style: AppType.body.copyWith(color: palette.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// The local reference support asks for, copied with a tap.
class _Reference extends StatelessWidget {
  const _Reference({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: id));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('plus_reference_copied'))));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: <Widget>[
            Icon(PhosphorIcons.copy(), size: 16, color: palette.mutedText),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                tr('plus_reference', args: [id]),
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
