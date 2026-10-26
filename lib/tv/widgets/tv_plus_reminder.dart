import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../presentation/billing/plus_controller.dart';
import '../../services/plus_navigation.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_reminder.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../app/tv_design.dart';
import 'tv_pill_button.dart';

/// TV Home's occasional Plus reminder, above the rows like the update
/// panel: on the shared [PlusReminderSchedule], never for members or while
/// Plus is not on sale. Get Plus opens the QR top-up page.
class TvPlusReminder extends StatefulWidget {
  const TvPlusReminder({super.key});

  @override
  State<TvPlusReminder> createState() => _TvPlusReminderState();
}

class _TvPlusReminderState extends State<TvPlusReminder> {
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
    if (plus == null || _schedule.due != true || !plus.shouldSuggest) {
      return const SizedBox.shrink();
    }
    _schedule.shown();
    final price = plus.plan?.amountCents ?? 200;
    final interval = plus.plan?.intervalDays ?? 31;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PlusAurora(
        borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
        energy: .8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
          child: Row(
            children: <Widget>[
              const PlusEmblem(size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      plus.signedIn
                          ? tr('plus_cta_member')
                          : tr('plus_cta_guest'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlusColors.ink,
                        fontFamily: 'FigtreeBold',
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('plus_tv_reminder_body',
                          args: [formatPrice(price), '$interval']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlusColors.mutedInk,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TvPillButton(
                label: tr('plus_get'),
                leading: const PlusMark(),
                prominent: true,
                onActivate: () {
                  _schedule.opened();
                  return openPlus(context);
                },
              ),
              const SizedBox(width: 10),
              TvPillButton(
                label: tr('plus_not_now'),
                onActivate: () => setState(_schedule.dismissed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
