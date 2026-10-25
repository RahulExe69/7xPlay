import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/plus_sheets.dart';
import '../widgets/settings_kit.dart';

/// Opens FlixQuest's checkout for [topup].
Future<void> openPlusPayment(BuildContext context, WalletTopup topup) {
  final plus = context.read<PlusController>();
  if (plus.topup?.id != topup.id) plus.followTopup(topup);
  return Navigator.of(context).push<void>(MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/plus/payment'),
    builder: (_) => const PlusPaymentScreen(),
  ));
}

/// The steps the progress line counts, in order.
const _steps = <String>['choose_coin', 'send', 'confirming', 'credited'];

int _stepIndex(String step) => switch (step) {
      'send' || 'send_remaining' => 1,
      'confirming' => 2,
      'credited' => 3,
      _ => 0,
    };

/// FlixQuest's own crypto checkout: choose a coin, then send the exact
/// amount to the address shown (QR, copy, wallet link), and follow it until
/// Laravel credits it. Nothing here proves a payment; only Laravel's answer
/// does, and the payment is known to it from the moment the coin is chosen.
class PlusPaymentScreen extends StatefulWidget {
  const PlusPaymentScreen({super.key});

  @override
  State<PlusPaymentScreen> createState() => _PlusPaymentScreenState();
}

class _PlusPaymentScreenState extends State<PlusPaymentScreen> {
  late final PlusController _plus = context.read<PlusController>();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Choosing another coin while the first one's address is showing.
  bool _changing = false;

  /// The coin whose payment is being created.
  String? _paying;
  String? _payError;
  bool _emailReceipt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_plus.loadCoins()));
  }

  @override
  void dispose() {
    _search.dispose();
    // A finished top-up has been seen; an open one stays followed.
    final topup = _plus.topup;
    if (topup != null && !topup.isOpen) scheduleMicrotask(_plus.dismissTopup);
    super.dispose();
  }

  Future<void> _pay(String coin) async {
    if (_paying != null) return;
    setState(() {
      _paying = coin;
      _payError = null;
    });
    try {
      await _plus.payWith(coin, emailReceipt: _emailReceipt);
      if (mounted) setState(() => _changing = false);
    } on BillingError catch (error) {
      if (mounted) setState(() => _payError = billingMessage(error));
    } finally {
      if (mounted) setState(() => _paying = null);
    }
  }

  Future<void> _openWallet(String uri) async {
    var opened = false;
    try {
      opened =
          await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
    } catch (_) {/* No app takes this link. */}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('plus_open_wallet_failed'))));
    }
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
    final payment = topup.payment;
    final step = _changing && topup.step == 'send' ? 'choose_coin' : topup.step;
    final content = switch (step) {
      'choose_coin' => _chooseCoin(context, plus, topup),
      'send' ||
      'send_remaining' when payment != null && payment.address != null =>
        _send(context, plus, topup, payment,
            remaining: step == 'send_remaining'),
      _ => _status(context, plus, topup, step),
    };
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('plus_payment')),
      body: ReadableWidth(
        maxWidth: 560,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter,
              AppSpace.xxxl + MediaQuery.paddingOf(context).bottom),
          children: <Widget>[
            if (step != 'closed') ...<Widget>[
              _Progress(step: step),
              const SizedBox(height: AppSpace.lg),
            ],
            ...content,
            const SizedBox(height: AppSpace.xxl),
            Text(
              topup.isOpen
                  ? tr('plus_payment_keep_checking')
                  : tr('plus_payment_reference_hint'),
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
            const SizedBox(height: AppSpace.sm),
            _Reference(
                text: tr('plus_reference', args: [topup.id]), copy: topup.id),
            if (payment?.id case final id?)
              _Reference(text: tr('plus_payment_id', args: [id]), copy: id),
          ],
        ),
      ),
    );
  }

  // ---- choose a coin ------------------------------------------------------

  List<Widget> _chooseCoin(
      BuildContext context, PlusController plus, WalletTopup topup) {
    final palette = AppPalette.of(context);
    final current = topup.payment?.coin;
    final coins = plus.coins;
    final shown = coins?.where((coin) => coin.matches(_query)).toList() ??
        const <PayCoin>[];
    final popular = _query.isEmpty
        ? shown.where((coin) => coin.popular).toList()
        : const <PayCoin>[];
    final rest =
        _query.isEmpty ? shown.where((coin) => !coin.popular).toList() : shown;
    return <Widget>[
      _Heading(
        title: tr('plus_choose_coin'),
        body: tr('plus_choose_coin_body', args: [formatUsd(topup.amountCents)]),
      ),
      if (_changing && current != null) ...<Widget>[
        const SizedBox(height: AppSpace.md),
        PillButton(
          label: tr('plus_keep_coin', args: [current.ticker]),
          icon: PhosphorIcons.arrowUUpLeft(),
          onPressed: () => setState(() => _changing = false),
        ),
      ],
      const SizedBox(height: AppSpace.lg),
      SearchPill(
        controller: _search,
        hint: tr('plus_search_coins'),
        onChanged: (value) => setState(() => _query = value),
      ),
      const SizedBox(height: AppSpace.sm),
      MergeSemantics(
        child: ListRow(
          flush: true,
          icon: PhosphorIcons.envelopeSimple(),
          label: tr('plus_email_receipt'),
          subtitle: tr('plus_email_receipt_body'),
          showsNext: false,
          onTap: () => setState(() => _emailReceipt = !_emailReceipt),
          trailing: ExcludeSemantics(
            child: AppSwitch(
              value: _emailReceipt,
              onChanged: (value) => setState(() => _emailReceipt = value),
            ),
          ),
        ),
      ),
      if (_payError != null) ...<Widget>[
        const SizedBox(height: AppSpace.sm),
        Text(
          _payError!,
          style:
              AppType.body.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (coins == null && plus.coinsError != null) ...<Widget>[
        const SizedBox(height: AppSpace.xl),
        Text(
          billingMessage(plus.coinsError!),
          style: AppType.body.copyWith(color: palette.mutedText),
        ),
        const SizedBox(height: AppSpace.md),
        PillButton(
          label: tr('plus_try_again'),
          icon: PhosphorIcons.arrowClockwise(),
          busy: plus.loadingCoins,
          onPressed: () => unawaited(plus.loadCoins(force: true)),
        ),
      ] else if (coins == null)
        const ListSkeleton(
          rows: 6,
          circle: true,
          leadingWidth: 36,
          leadingHeight: 36,
          padding: EdgeInsets.only(top: AppSpace.lg),
        )
      else ...<Widget>[
        if (popular.isNotEmpty) ...<Widget>[
          KickerHeading(tr('plus_coins_popular'),
              padding: const EdgeInsets.only(top: AppSpace.lg, bottom: 4)),
          for (final coin in popular) _coinRow(coin),
        ],
        if (rest.isNotEmpty) ...<Widget>[
          KickerHeading(
              _query.isEmpty ? tr('plus_coins_all') : tr('plus_coins_matches'),
              padding: const EdgeInsets.only(top: AppSpace.lg, bottom: 4)),
          for (final coin in rest) _coinRow(coin),
        ],
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xl),
            child: Text(
              tr('plus_coins_none'),
              style: AppType.body.copyWith(color: palette.mutedText),
            ),
          ),
      ],
    ];
  }

  Widget _coinRow(PayCoin coin) {
    final palette = AppPalette.of(context);
    final paying = _paying == coin.code;
    return ListRow(
      flush: true,
      leading: CoinLogo(coin: coin),
      label: coin.ticker,
      subtitle: coin.name,
      value: coin.networkLabel,
      trailing: paying
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: palette.mutedText),
            )
          : null,
      showsNext: !paying,
      onTap: _paying == null ? () => unawaited(_pay(coin.code)) : null,
    );
  }

  // ---- send ---------------------------------------------------------------

  List<Widget> _send(BuildContext context, PlusController plus,
      WalletTopup topup, TopupPayment payment,
      {required bool remaining}) {
    final coin = payment.coin;
    final due = payment.due ?? '';
    final address = payment.address!;
    final extraId = payment.extraId;
    final tag = coin.extraId == 'destination_tag';
    final expires = payment.expiresAt;
    return <Widget>[
      _Heading(
        leading: CoinLogo(coin: coin, size: 40),
        title: remaining
            ? tr('plus_send_rest')
            : tr('plus_send_amount', args: [due, coin.ticker]),
        body: remaining
            ? tr('plus_send_rest_body', args: [
                '${payment.paid ?? '0'} ${coin.ticker}',
                '${payment.amount ?? ''} ${coin.ticker}',
                '$due ${coin.ticker}',
              ])
            : tr('plus_coin_on_network',
                args: [coin.ticker, coin.networkLabel]),
      ),
      const SizedBox(height: AppSpace.xl),
      Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.hero),
          ),
          child: QrImageView(
            data: address,
            size: 196,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            semanticsLabel: tr('plus_qr_label', args: [coin.ticker]),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.xl),
      _CopyField(
        label: remaining ? tr('plus_remaining_label') : tr('plus_amount_label'),
        value: due,
        suffix: coin.ticker,
        large: true,
      ),
      _CopyField(
        label: tr('plus_address_label', args: [coin.networkLabel]),
        value: address,
      ),
      if (extraId != null)
        _CopyField(
          label: tag ? tr('plus_tag_label') : tr('plus_memo_label'),
          value: extraId,
          highlight: true,
        ),
      const SizedBox(height: AppSpace.sm),
      _Notice(lines: <String>[
        tr('plus_network_warning', args: [coin.ticker, coin.networkLabel]),
        if (extraId != null)
          tag ? tr('plus_tag_warning') : tr('plus_memo_warning'),
        tr('plus_exchange_fee_warning'),
      ]),
      if (!remaining && expires != null) ...<Widget>[
        const SizedBox(height: AppSpace.lg),
        _QuoteTimer(
          expiresAt: expires,
          busy: _paying == coin.code,
          onRefresh: () => unawaited(_pay(coin.code)),
        ),
      ],
      if (_payError != null) ...<Widget>[
        const SizedBox(height: AppSpace.md),
        Text(
          _payError!,
          style:
              AppType.body.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: AppSpace.lg),
      if (payment.uri case final uri?) ...<Widget>[
        PillButton(
          label: tr('plus_open_wallet'),
          icon: PhosphorIcons.wallet(),
          primary: true,
          onPressed: () => unawaited(_openWallet(uri)),
        ),
        const SizedBox(height: AppSpace.md),
      ],
      PillButton(
        label: plus.checkingTopup ? tr('plus_checking') : tr('plus_check_now'),
        icon: PhosphorIcons.arrowsClockwise(),
        primary: payment.uri == null,
        busy: plus.checkingTopup,
        onPressed: () => unawaited(plus.checkTopup(manual: true)),
      ),
      if (!remaining) ...<Widget>[
        const SizedBox(height: AppSpace.md),
        PillButton(
          label: tr('plus_change_coin'),
          icon: PhosphorIcons.swap(),
          onPressed: () {
            unawaited(plus.loadCoins());
            setState(() {
              _changing = true;
              _payError = null;
            });
          },
        ),
      ],
      const SizedBox(height: AppSpace.lg),
      _LiveLine(
        text: plus.topupWatchExpired
            ? tr('plus_payment_still_waiting_body')
            : tr('plus_waiting_live'),
        live: !plus.topupWatchExpired,
      ),
    ];
  }

  // ---- preparing, confirming and the outcome ------------------------------

  List<Widget> _status(BuildContext context, PlusController plus,
      WalletTopup topup, String step) {
    final (title, body) = _copy(topup, plus, step);
    return <Widget>[
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
      ..._outcomeActions(context, plus, topup),
    ];
  }

  List<Widget> _outcomeActions(
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
    if (!topup.isOpen) {
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
    return <Widget>[
      PillButton(
        label: plus.checkingTopup ? tr('plus_checking') : tr('plus_check_now'),
        icon: PhosphorIcons.arrowsClockwise(),
        primary: true,
        busy: plus.checkingTopup,
        onPressed: () => unawaited(plus.checkTopup(manual: true)),
      ),
    ];
  }

  (String, String) _copy(WalletTopup topup, PlusController plus, String step) {
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
    final coin = topup.payment?.coin;
    return switch (topup.status) {
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
      'partially_paid' => (
          tr('plus_payment_partial'),
          tr('plus_payment_partial_body')
        ),
      _ when step == 'preparing' => (
          tr('plus_payment_preparing'),
          tr('plus_payment_preparing_body')
        ),
      _ => (
          plus.topupWatchExpired
              ? tr('plus_payment_still_waiting')
              : tr('plus_payment_confirming_title',
                  args: [formatUsd(topup.amountCents)]),
          coin == null
              ? tr('plus_payment_confirming_body')
              : tr('plus_confirming_body',
                  args: [coin.ticker, coin.networkLabel]),
        ),
    };
  }
}

/// A coin's logo from NOWPayments, or its ticker's first letters.
class CoinLogo extends StatelessWidget {
  const CoinLogo({required this.coin, this.size = 36, super.key});

  final PayCoin coin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final initials = Center(
      child: Text(
        coin.ticker.length > 3 ? coin.ticker.substring(0, 3) : coin.ticker,
        style: AppType.cardTitle.copyWith(
          fontSize: size * .3,
          color: palette.foreground,
        ),
      ),
    );
    final logo = coin.trustedLogo;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.idleFill,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: logo == null
            ? initials
            : SvgPicture.network(
                logo,
                width: size,
                height: size,
                placeholderBuilder: (_) => initials,
                errorBuilder: (_, __, ___) => initials,
              ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.body, this.leading});

  final String title;
  final String body;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final leading = this.leading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading,
          const SizedBox(width: AppSpace.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppType.pageTitle.copyWith(
                    fontSize: 24,
                    height: 1.2,
                    color: palette.foreground,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                body,
                style: AppType.body.copyWith(color: palette.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Four short bars and the name of the step the payment is on.
class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final String step;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final at = _stepIndex(step);
    final done = step == 'credited';
    final name = tr('plus_step_${_steps[at]}');
    return Semantics(
      label: tr('plus_step_of', args: ['${at + 1}', '${_steps.length}', name]),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (var i = 0; i < _steps.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < at || i == at || done
                            ? PlusColors.gold
                            : palette.idleFillStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              tr('plus_step_of', args: ['${at + 1}', '${_steps.length}', name])
                  .toUpperCase(),
              style: AppType.kicker.copyWith(color: palette.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

/// One value to copy into a wallet: the amount, the address or the memo.
class _CopyField extends StatelessWidget {
  const _CopyField({
    required this.label,
    required this.value,
    this.suffix,
    this.large = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final bool large;

  /// A memo or tag, which is easy to forget and loses the payment.
  final bool highlight;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    unawaited(HapticFeedback.selectionClick());
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(tr('plus_copied_value', args: [label]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final suffix = this.suffix;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_copy(context)),
          child: Container(
            decoration: highlight
                ? BoxDecoration(
                    border: Border.all(color: PlusColors.gold, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  )
                : null,
            padding: const EdgeInsets.fromLTRB(
                AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style:
                            AppType.metadata.copyWith(color: palette.mutedText),
                      ),
                      const SizedBox(height: 4),
                      SelectableText.rich(
                        TextSpan(children: <InlineSpan>[
                          TextSpan(text: value),
                          if (suffix != null)
                            TextSpan(
                              text: ' $suffix',
                              style: TextStyle(color: palette.mutedText),
                            ),
                        ]),
                        style: TextStyle(
                          fontFamily: large ? AppType.bold : 'monospace',
                          fontSize: large ? 22 : 15,
                          height: 1.3,
                          color: palette.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('plus_copy'),
                  onPressed: () => unawaited(_copy(context)),
                  icon: Icon(PhosphorIcons.copy(), color: palette.foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ways a crypto send goes wrong, said before it is sent.
class _Notice extends StatelessWidget {
  const _Notice({required this.lines});

  final List<String> lines;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (index, line) in lines.indexed) ...<Widget>[
                  if (index > 0) const SizedBox(height: AppSpace.sm),
                  Text(
                    line,
                    style: (index == 0 ? AppType.cardTitle : AppType.body)
                        .copyWith(fontSize: 14, color: palette.foreground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How long the quoted coin amount holds; once it runs out, a fresh quote
/// for the same address.
class _QuoteTimer extends StatefulWidget {
  const _QuoteTimer({
    required this.expiresAt,
    required this.busy,
    required this.onRefresh,
  });

  final DateTime expiresAt;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  State<_QuoteTimer> createState() => _QuoteTimerState();
}

class _QuoteTimerState extends State<_QuoteTimer> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_left == Duration.zero) _tick?.cancel();
    });
  }

  @override
  void didUpdateWidget(_QuoteTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh quote counts down again.
    if (oldWidget.expiresAt != widget.expiresAt) _start();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration get _left {
    final left = widget.expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final left = _left;
    if (left == Duration.zero) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            tr('plus_quote_expired'),
            style: AppType.body.copyWith(color: palette.foreground),
          ),
          const SizedBox(height: AppSpace.md),
          PillButton(
            label: tr('plus_quote_refresh'),
            icon: PhosphorIcons.arrowClockwise(),
            busy: widget.busy,
            onPressed: widget.onRefresh,
          ),
        ],
      );
    }
    final minutes = left.inMinutes.toString().padLeft(2, '0');
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: <Widget>[
        Icon(PhosphorIcons.timer(), size: 18, color: palette.mutedText),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            tr('plus_quote_held', args: ['$minutes:$seconds']),
            style: AppType.body.copyWith(
              color: palette.mutedText,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Waiting for your payment", with a slow pulse while checks run.
class _LiveLine extends StatelessWidget {
  const _LiveLine({required this.text, required this.live});

  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: <Widget>[
          if (live) ...<Widget>[
            const _Pulse(),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(
            child: Text(
              text,
              style: AppType.body.copyWith(color: palette.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _beat.stop();
    } else if (!_beat.isAnimating) {
      _beat.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 1, end: .25).animate(_beat),
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: PlusColors.gold,
            shape: BoxShape.circle,
          ),
        ),
      );
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

/// A reference support asks for, copied with a tap.
class _Reference extends StatelessWidget {
  const _Reference({required this.text, required this.copy});

  final String text;
  final String copy;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: copy));
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
                text,
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
