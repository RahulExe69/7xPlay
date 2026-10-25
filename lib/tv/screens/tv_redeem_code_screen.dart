import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../app/tv_design.dart';
import '../widgets/tv_form_keyboard.dart';
import '../widgets/tv_pill_button.dart';

/// Redeems a FlixQuest code on the TV, typed with FlixQuest's own keyboard:
/// the code on the left, the keyboard on the right, and Redeem as the
/// keyboard's wide key. Codes are letters, digits and dashes, so anything
/// else is ignored and letters show in capitals, the way codes are printed.
class TvRedeemCodeScreen extends StatefulWidget {
  const TvRedeemCodeScreen({super.key});

  static Future<void> open(BuildContext context) {
    final plus = context.read<PlusController>();
    return Navigator.of(context).push<void>(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/plus/redeem'),
      builder: (_) => ChangeNotifierProvider<PlusController>.value(
        value: plus,
        child: const TvRedeemCodeScreen(),
      ),
    ));
  }

  @override
  State<TvRedeemCodeScreen> createState() => _TvRedeemCodeScreenState();
}

class _TvRedeemCodeScreenState extends State<TvRedeemCodeScreen> {
  final _keyboard = GlobalKey<TvFormKeyboardState>();
  String _code = '';
  bool _busy = false;
  String? _error;
  CouponRedemption? _done;

  static const _maxLength = 40;
  static final _codeCharacter = RegExp(r'[A-Za-z0-9-]');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.currentState?.requestFocus();
    });
  }

  void _type(String text) {
    final typed = text.split('').where(_codeCharacter.hasMatch).join();
    if (typed.isEmpty || _code.length >= _maxLength) return;
    final next = _code + typed.toUpperCase();
    setState(() {
      _code = next.length > _maxLength ? next.substring(0, _maxLength) : next;
      _error = null;
    });
  }

  void _delete() {
    if (_code.isEmpty) return;
    setState(() {
      _code = _code.substring(0, _code.length - 1);
      _error = null;
    });
  }

  void _clear() => setState(() {
        _code = '';
        _error = null;
      });

  Future<void> _redeem() async {
    if (_busy) return;
    if (_code.isEmpty) {
      setState(() => _error = tr('plus_tv_code_hint'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final done = await context.read<PlusController>().redeemCoupon(_code);
      if (mounted) setState(() => _done = done);
    } on BillingError catch (error) {
      if (mounted) setState(() => _error = billingMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            final done = _done;
            if (done != null) return _result(context, done, compact);
            final keyboardWidth = <double>[
              constraints.maxWidth * 0.5,
              TvFormKeyboard.widthFor(
                constraints.maxHeight - (compact ? 64 : 84),
              ),
              620,
            ].reduce((a, b) => a < b ? a : b);
            return Row(
              children: <Widget>[
                Expanded(child: _form(context, compact)),
                SizedBox(width: compact ? 32 : 48),
                SizedBox(
                  width: keyboardWidth,
                  child: Center(
                    child: TvFormKeyboard(
                      key: _keyboard,
                      width: keyboardWidth,
                      onType: _type,
                      onDelete: _delete,
                      onClear: _clear,
                      onAction: _redeem,
                      actionLabel:
                          _busy ? tr('tv_please_wait') : tr('plus_redeem'),
                      actionIcon: PhosphorIcons.ticket(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context, bool compact) {
    final palette = TvPalette.of(context);
    final valueSize = compact ? 24.0 : 30.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          tr('plus_redeem_code'),
          style: TextStyle(
            color: palette.foreground,
            fontFamily: 'FigtreeBold',
            fontSize: compact ? 28 : 36,
            letterSpacing: -0.45,
            height: 1.1,
          ),
        ),
        SizedBox(height: compact ? 6 : 10),
        Text(
          tr('plus_redeem_intro'),
          style: TextStyle(
            color: palette.mutedText,
            fontSize: compact ? 15 : 18,
            height: 1.3,
          ),
        ),
        SizedBox(height: compact ? 18 : 28),
        Container(
          height: compact ? 64 : 76,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: palette.idleFill,
            borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
            border: Border.all(
              color: _error != null
                  ? Theme.of(context).colorScheme.error
                  : palette.foreground,
              width: 2,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(PhosphorIcons.ticket(), color: palette.mutedText, size: 24),
              const SizedBox(width: 14),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(
                    _code,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: valueSize,
                      letterSpacing: 2,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
              Container(
                width: 2,
                height: valueSize + 2,
                margin: const EdgeInsetsDirectional.only(start: 2),
                color: palette.foreground,
              ),
              if (_code.isEmpty) ...<Widget>[
                const SizedBox(width: 10),
                Text(
                  tr('plus_code'),
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: compact ? 18 : 22,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 14),
        Text(
          _error ?? tr('plus_tv_code_hint'),
          style: TextStyle(
            color: _error != null
                ? Theme.of(context).colorScheme.error
                : palette.mutedText,
            fontFamily: _error != null ? 'FigtreeSB' : null,
            fontSize: compact ? 15 : 17,
          ),
        ),
      ],
    );
  }

  Widget _result(BuildContext context, CouponRedemption done, bool compact) {
    final palette = TvPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlusEmblem(size: compact ? 72 : 96),
            SizedBox(height: compact ? 18 : 26),
            Text(
              tr('plus_redeemed'),
              style: TextStyle(
                color: palette.foreground,
                fontFamily: 'FigtreeBold',
                fontSize: compact ? 28 : 36,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              redemptionSummary(done),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: compact ? 15 : 18,
                height: 1.4,
              ),
            ),
            SizedBox(height: compact ? 22 : 30),
            TvPillButton(
              label: tr('plus_done'),
              autofocus: true,
              prominent: true,
              onActivate: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
