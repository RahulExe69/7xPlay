import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/sync/sync_runtime.dart';
import '../../data/sync/sync_runner.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../presentation/session/auth_runtime.dart';

/// The handheld sync page. It reports the existing runners' actual states and
/// delegates all work to the current coordinator; this file only composes UI.
class LaravelSyncScreen extends StatelessWidget {
  const LaravelSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AuthRuntime.session;
    final coordinator = SyncRuntime.coordinator;
    final palette = AppPalette.of(context);
    final localOnly =
        !SyncRuntime.enabled || coordinator == null || session.user == null;

    if (localOnly) {
      return Scaffold(
        backgroundColor: palette.page,
        appBar: PageAppBar(title: tr('sync'), contentWidth: 760),
        body: SafeArea(
          child: EmptyState(
            icon: PhosphorIcons.cloudSlash(),
            title: tr('sync_local_title'),
            message: session.user == null
                ? tr('sync_guest_message')
                : tr('sync_unavailable_message'),
          ),
        ),
      );
    }

    final runners = <_SyncSection>[
      _SyncSection(
        title: tr('bookmarks'),
        detail: tr('no_movies_bookmarked'),
        icon: PhosphorIcons.bookmarkSimple(),
        runner: coordinator.bookmarks,
      ),
      _SyncSection(
        title: tr('continue_watching'),
        detail: tr('sync_progress_detail'),
        icon: PhosphorIcons.playCircle(),
        runner: coordinator.recents,
      ),
      _SyncSection(
        title: tr('wellness'),
        detail: tr('sync_insights_detail'),
        icon: PhosphorIcons.chartLineUp(),
        runner: coordinator.wellnessSync,
      ),
    ];

    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: tr('sync'),
        contentWidth: 760,
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            session,
            for (final runner in runners) runner.status,
            for (final runner in runners) runner.lastSynced,
          ]),
          builder: (context, _) {
            final busy = runners.any(
              (section) => section.runner.status.value == 'syncing',
            );
            final gutter = AppSpace.gutter(context);
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverReadableWidth(
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        AppSpace.lg,
                        gutter,
                        AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: SliverList.list(
                        children: <Widget>[
                          const _SyncIntroCard(),
                          const SizedBox(height: AppSpace.xxl),
                          KickerHeading(
                            tr('sync_sections_heading'),
                            padding: EdgeInsets.only(bottom: AppSpace.sm),
                          ),
                          for (final section in runners) ...<Widget>[
                            _SyncStatusCard(section: section),
                            const SizedBox(height: AppSpace.sm),
                          ],
                          const SizedBox(height: AppSpace.lg),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: PillButton(
                              primary: true,
                              height: 52,
                              icon: PhosphorIcons.arrowsClockwise(),
                              busy: busy,
                              label: busy
                                  ? tr('ins_syncing')
                                  : tr('sync_now'),
                              onPressed: busy
                                  ? null
                                  : () => _syncAll(context, coordinator),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _syncAll(
    BuildContext context,
    dynamic coordinator,
  ) async {
    final success = await coordinator.syncAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success ? tr('sync_all_success') : tr('sync_all_partial_failure'),
          ),
        ),
      );
  }
}

class _SyncSection {
  const _SyncSection({
    required this.title,
    required this.detail,
    required this.icon,
    required this.runner,
  });

  final String title;
  final String detail;
  final IconData icon;
  final SyncRunner runner;
}

class _SyncIntroCard extends StatelessWidget {
  const _SyncIntroCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.idleFill,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Icon(
              PhosphorIcons.cloudArrowUp(),
              color: palette.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr('sync_hero_title'),
                  style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold,
                    color: palette.foreground,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  tr('sync_hero_message'),
                  style: AppType.body.copyWith(color: palette.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.section});

  final _SyncSection section;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final runner = section.runner;
    final status = runner.status.value;
    final syncing = status == 'syncing';
    final failed = status == 'error';
    final stamp = runner.lastSynced.value?.toLocal();
    final statusColor = failed
        ? Theme.of(context).colorScheme.error
        : syncing
            ? palette.accent
            : palette.mutedText;
    final statusText = syncing
        ? tr('ins_syncing')
        : failed
            ? tr('sync_status_waiting_retry')
            : stamp == null
                ? tr('ins_ready_sync')
                : tr(
                    'last_synced_at',
                    namedArgs: {'time': _formatSyncTime(context, stamp)},
                  );

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.idleFill,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Icon(
              section.icon,
              color: palette.mutedText,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle.copyWith(
                    color: palette.foreground,
                    fontFamily: AppType.semiBold,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.metadata.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          if (syncing)
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            )
          else
            Icon(
              failed
                  ? PhosphorIcons.warningCircle()
                  : status == 'success'
                      ? PhosphorIcons.checkCircle()
                      : PhosphorIcons.clock(),
              color: statusColor,
              size: 20,
            ),
        ],
      ),
    );
  }
}

String _formatSyncTime(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(dateTime)} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime))}';
}

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) => const LaravelSyncScreen();
}
