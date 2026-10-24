import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../design/app_tokens.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../services/plus_navigation.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_reminder.dart';
import '../../widgets/plus/plus_visuals.dart';

/// My FlixQuest's Plus card. Members get a living card (the aurora drifting
/// behind their days left); everyone else, while Plus is on sale, a quiet
/// invitation. It hides when there is nothing true to say.
class PlusCard extends StatefulWidget {
  const PlusCard({super.key});

  @override
  State<PlusCard> createState() => _PlusCardState();
}

class _PlusCardState extends State<PlusCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(prepareDates(context).then((_) {
        if (mounted) setState(() {});
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController?>();
    if (plus == null) return const SizedBox.shrink();
    final Widget card;
    if (plus.adFree) {
      card = _MemberCard(key: const ValueKey('member'), plus: plus);
    } else if (plus.shouldSuggest ||
        (plus.wallet?.spendableCents ?? 0) > 0 ||
        plus.renewal?.mode != null) {
      card = _InviteCard(key: const ValueKey('invite'), plus: plus);
    } else {
      card = const SizedBox.shrink(key: ValueKey('none'));
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: card,
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap, this.label});

  final Widget child;
  final VoidCallback onTap;
  final String? label;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _down ? .975 : 1,
            duration: const Duration(milliseconds: 110),
            child: widget.child,
          ),
        ),
      );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.plus, super.key});

  final PlusController plus;

  @override
  Widget build(BuildContext context) {
    final until = plus.activeUntil;
    final left = until == null ? null : daysLeft(plus.serverNow, until);
    final renewal = plus.renewal;
    final renewing = renewal?.autoRenew == true;
    return _Pressable(
      label: tr('plus_name'),
      onTap: () => unawaited(openPlus(context)),
      child: PlusAurora(
        borderRadius: BorderRadius.circular(AppRadii.hero),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const PlusWordmark(size: 22),
                    const SizedBox(height: 12),
                    Text(
                      tr('plus_youre_ad_free'),
                      style: const TextStyle(
                        fontFamily: 'FigtreeBold',
                        fontSize: 18,
                        height: 1.2,
                        color: PlusColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      until == null
                          ? tr('plus_welcome_body')
                          : renewing
                              ? tr('plus_renews_on',
                                  args: [formatDay(context, until)])
                              : tr('plus_ad_free_until',
                                  args: [formatDay(context, until)]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 13,
                        height: 1.35,
                        color: PlusColors.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        PlusChip(
                          icon: PhosphorIcons.wallet(),
                          label: formatUsd(plus.wallet?.spendableCents ?? 0),
                        ),
                        PlusChip(
                          icon: renewing
                              ? PhosphorIcons.arrowsClockwise()
                              : PhosphorIcons.pause(),
                          label: renewing
                              ? tr('plus_auto_renew_on')
                              : tr('plus_auto_renew_off'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (left != null)
                PlusPeriodRing(
                  used: plus.periodProgress,
                  size: 84,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$left',
                        style: const TextStyle(
                          fontFamily: 'FigtreeBlack',
                          fontSize: 24,
                          height: 1,
                          color: PlusColors.ink,
                        ),
                      ),
                      Text(
                        plural('plus_days_left', left),
                        style: const TextStyle(
                          fontFamily: 'FigtreeSB',
                          fontSize: 10,
                          color: PlusColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const PlusEmblem(size: 56),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.plus, super.key});

  final PlusController plus;

  @override
  Widget build(BuildContext context) {
    final price = plus.plan?.amountCents ?? 200;
    final interval = plus.plan?.intervalDays ?? 31;
    final ended =
        plus.renewal?.mode != null && plus.entitlement?.expiresAt != null;
    final title = ended
        ? tr('plus_come_back')
        : plus.signedIn
            ? tr('plus_cta_member')
            : tr('plus_cta_guest');
    final subtitle =
        tr('plus_price_line', args: [formatPrice(price), '$interval']);
    return _Pressable(
      label: title,
      onTap: () => unawaited(openPlus(context)),
      child: PlusAurora(
        borderRadius: BorderRadius.circular(AppRadii.hero),
        energy: .75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: LayoutBuilder(builder: (context, constraints) {
            // A narrow card (small phone, large text) puts the pill under
            // the words instead of squeezing them.
            final narrow = constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(10) > 12;
            final pill = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xF2FFFFFF),
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              child: Text(
                plus.signedIn ? tr('plus_get') : tr('plus_sign_in_short'),
                style: const TextStyle(
                  fontFamily: 'FigtreeSB',
                  fontSize: 13,
                  color: Color(0xFF000000),
                ),
              ),
            );
            return Row(
              children: <Widget>[
                const PlusEmblem(size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'FigtreeBold',
                          fontSize: 16,
                          height: 1.2,
                          color: PlusColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12.5,
                          height: 1.35,
                          color: PlusColors.mutedInk,
                        ),
                      ),
                      if (narrow) ...<Widget>[
                        const SizedBox(height: 10),
                        pill,
                      ],
                    ],
                  ),
                ),
                if (!narrow) ...<Widget>[
                  const SizedBox(width: 8),
                  pill,
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// An occasional Plus reminder between Home's rows, on the schedule
/// [PlusReminderSchedule] keeps. Never for members, or while Plus is not on
/// sale.
class PlusSpotlight extends StatefulWidget {
  const PlusSpotlight({super.key});

  @override
  State<PlusSpotlight> createState() => _PlusSpotlightState();
}

class _PlusSpotlightState extends State<PlusSpotlight> {
  final _schedule = PlusReminderSchedule.instance;

  @override
  void initState() {
    super.initState();
    if (_schedule.due == null) {
      _schedule.decide().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController?>();
    final show = _schedule.due == true && plus != null && plus.shouldSuggest;
    if (show) _schedule.shown();
    if (!show) return const SizedBox.shrink();
    final price = plus.plan?.amountCents ?? 200;
    final interval = plus.plan?.intervalDays ?? 31;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
      child: _Pressable(
        label: plus.signedIn ? tr('plus_cta_member') : tr('plus_cta_guest'),
        onTap: () {
          _schedule.opened();
          unawaited(openPlus(context));
        },
        child: PlusAurora(
          borderRadius: BorderRadius.circular(AppRadii.hero),
          energy: .8,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
            child: Row(
              children: <Widget>[
                const PlusEmblem(size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        plus.signedIn
                            ? tr('plus_cta_member')
                            : tr('plus_cta_guest'),
                        style: const TextStyle(
                          fontFamily: 'FigtreeBold',
                          fontSize: 15,
                          color: PlusColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('plus_spotlight_body',
                            args: [formatPrice(price), '$interval']),
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12.5,
                          height: 1.35,
                          color: PlusColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('plus_not_now'),
                  onPressed: () => setState(_schedule.dismissed),
                  icon: Icon(PhosphorIcons.x(),
                      size: 18, color: PlusColors.mutedInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
