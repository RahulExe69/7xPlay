import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:flixquest/data/models/app_user.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../catalog/continue_watching.dart';
import '../../catalog/media_item.dart';
import '../../data/playlists/playlist.dart';
import '../../design/app_palette.dart';
import '../widgets/page_kit.dart';
import '../../design/app_tokens.dart';
import '../../models/offline_download.dart';
import '../../provider/bookmark_provider.dart';
import '../../provider/playlist_provider.dart';
import '../../provider/offline_download_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/about.dart';
import '../../screens/common/bookmark_screen.dart';
import '../../screens/common/downloads_screen.dart';
import '../../screens/common/server_status_screen.dart';
import '../../screens/common/settings.dart' as app_settings;
import '../../screens/common/sync_screen.dart';
import '../../screens/common/update_screen.dart';
import '../../screens/user/edit_profile.dart';
import '../../screens/wellness/wellness_screen.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/plus_navigation.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../playlists.dart';
import '../widgets/media_rows.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/plus_card.dart';
import '../widgets/verified_badge.dart';
import '../widgets/section_header.dart';
import 'playlists_screen.dart';

/// The phone library and account tab. Local media is useful immediately and
/// remote profile data only enhances the header when it is available.
class LaravelMyFlixQuestScreen extends StatefulWidget {
  const LaravelMyFlixQuestScreen({super.key});

  @override
  State<LaravelMyFlixQuestScreen> createState() => _MyFlixQuestScreenState();
}

class _MyFlixQuestScreenState extends State<LaravelMyFlixQuestScreen> {
  AppUser? _user;

  /// Leaving the guest session waits on the network; the pill spins until
  /// the sign-in page takes over.
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    try {
      _user = AuthRuntime.session.user;
      AuthRuntime.session.addListener(_onSessionChanged);
    } catch (_) {
      _user = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadLocalLibrary());
    });
  }

  Future<void> _loadLocalLibrary() async {
    final downloads = context.read<OfflineDownloadProvider>();
    final bookmarks = context.read<BookmarkProvider>();
    final recent = context.read<RecentProvider>();
    if (downloads.downloads.isEmpty && !downloads.loading) {
      try {
        await downloads.refresh();
      } catch (_) {
        // The existing local snapshot, even an empty one, is still usable.
      }
    }
    await Future.wait<void>(<Future<void>>[
      _quietly(bookmarks.fetchBookmarks),
      _quietly(recent.fetchMovies),
      _quietly(recent.fetchEpisodes),
    ]);
  }

  Future<void> _quietly(Future<void> Function() load) async {
    try {
      await load();
    } catch (_) {
      // My FlixQuest is an offline-first surface. A stale local section is
      // preferable to an error replacing the whole page.
    }
  }

  void _onSessionChanged() {
    if (mounted) setState(() => _user = AuthRuntime.session.user);
  }

  @override
  void dispose() {
    AuthRuntime.maybeSession?.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final recent = context.watch<RecentProvider>();
    final bookmarks = context.watch<BookmarkProvider>();
    final downloads = context.watch<OfflineDownloadProvider>().downloads;
    final continueWatching = continueWatchingItems(
      movies: recent.movies,
      episodes: recent.episodes,
      upNext: recent.upNext,
    );
    final saved = <MediaItem>[
      ...bookmarks.movies.map(MediaItem.fromMovie),
      ...bookmarks.tvShows.map(MediaItem.fromSeries),
    ];

    final activity = <Widget>[
      SectionHeader(
        title: tr('downloads'),
        onSeeAll: () => _push(const DownloadsScreen()),
      ),
      if (downloads.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpace.gutter(context),
            vertical: AppSpace.md,
          ),
          child: Text(
            tr('no_downloads_yet'),
            style: AppType.body.copyWith(color: palette.mutedText),
          ),
        )
      else
        for (final download in downloads.take(3))
          _DownloadSummaryRow(
            download: download,
            onTap: () => _push(const DownloadsScreen()),
          ),
      const SizedBox(height: AppSpace.xxl),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
        child: WellnessPreviewCard(
          onTap: () => _push(const WellnessScreen()),
        ),
      ),
    ];
    final links = <Widget>[
      if (_isSignedIn)
        ListRow(
          leading: PlusMark(size: 22, color: palette.mutedText),
          label: tr('plus_name'),
          onTap: () => unawaited(openPlus(context)),
        ),
      ListRow(
        icon: PhosphorIcons.slidersHorizontal(),
        label: tr('settings'),
        onTap: () => _push(const app_settings.Settings()),
      ),
      ListRow(
        icon: PhosphorIcons.arrowsDownUp(),
        label: tr('sync'),
        onTap: () => _push(const SyncScreen()),
      ),
      ListRow(
        icon: PhosphorIcons.database(),
        label: tr('check_server'),
        onTap: () => _push(const ServerStatusScreen()),
      ),
      ListRow(
        icon: PhosphorIcons.arrowCircleUp(),
        label: tr('check_for_update'),
        onTap: () => _push(const UpdateScreen(isForced: false)),
      ),
      ListRow(
        icon: PhosphorIcons.shareNetwork(),
        label: tr('shared_the_app'),
        showsNext: false,
        onTap: _shareApp,
      ),
      ListRow(
        icon: PhosphorIcons.info(),
        label: tr('about'),
        onTap: () => _push(const AboutPage()),
      ),
      // A guest has nothing to sign out of; the header offers sign-in.
      if (_isSignedIn)
        ListRow(
          icon: PhosphorIcons.signOut(),
          label: tr('sign_out'),
          destructive: true,
          showsNext: false,
          onTap: _confirmSignOut,
        ),
    ];
    // A wide tablet page keeps the account's links beside what it has been
    // doing, instead of stretching every row across it.
    final twoColumns = AppBreakpoints.isTablet(context) &&
        MediaQuery.sizeOf(context).width >= AppBreakpoints.wide;

    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            top: AppSpace.md,
            bottom: 112 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
              child: Text(
                tr('my_flixquest'),
                style: AppType.scaled(context, AppType.pageTitle).copyWith(
                  color: palette.foreground,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
              child: _ProfileHeader(
                user: _user,
                onProfile: () => _push(const ProfileEdit()),
                onSignIn: _leaveGuestSession,
                signingIn: _signingIn,
                plus: context.watch<PlusController?>()?.adFree ?? false,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter(context), AppSpace.xl, AppSpace.gutter(context), 0),
              child: const PlusCard(),
            ),
            if (continueWatching.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.xxl),
              ContinueRow(
                title: tr('continue_watching'),
                items: continueWatching,
              ),
            ],
            if (saved.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.xxl),
              PosterRow(
                title: tr('my_list'),
                items: saved,
                onSeeAll: () => _push(const BookmarkScreen()),
              ),
            ],
            if (context.watch<PlaylistProvider?>()
                case final playlists?) ...<Widget>[
              const SizedBox(height: AppSpace.xxl),
              SectionHeader(
                title: tr('playlists'),
                onSeeAll: () => _push(const PlaylistsScreen()),
              ),
              _PlaylistShelf(
                lists: playlists.lists,
                onOpen: (id) => openPlaylist(context, id),
                onCreate: () async {
                  final id = await createPlaylist(context);
                  if (id != null && context.mounted) {
                    await openPlaylist(context, id);
                  }
                },
              ),
            ],
            const SizedBox(height: AppSpace.xxl),
            if (twoColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: activity,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: links,
                    ),
                  ),
                ],
              )
            else ...<Widget>[
              ...activity,
              const SizedBox(height: AppSpace.xxl),
              ...links,
            ],
          ],
        ),
      ),
    );
  }

  bool get _isSignedIn {
    final user = _user;
    return user != null;
  }

  Future<void> _shareApp() async {
    context.read<SettingsProvider>().analytics.trackShare(shareType: 'App');
    await Share.share(tr('share_text'));
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showConfirmDialog(
      context,
      icon: PhosphorIcons.signOut(),
      title: tr('sign_out'),
      message: tr('want_to_sign_out'),
      confirmLabel: tr('sign_out'),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final analytics = context.read<SettingsProvider>().analytics;
    analytics.trackSignOut();
    analytics.resetUser();
    await _signOut();
  }

  /// Guests go to the sign-in screens keeping their guest account, which a
  /// sign-up then upgrades in place.
  Future<void> _leaveGuestSession() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await _signOut();
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await FlixQuestAuthService().signOut();
    if (!mounted) return;
    await AuthNavigationService.returnToSignedOutRoot(context);
  }

  void _push(Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onProfile,
    required this.onSignIn,
    this.signingIn = false,
    this.plus = false,
  });

  final AppUser? user;
  final VoidCallback onProfile;
  final VoidCallback onSignIn;
  final bool signingIn;

  /// A Plus member: a foil ring round the avatar and "FlixQuest Plus".
  final bool plus;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    final guest = user == null;
    final fallback = _ProfileSnapshot(
      name: guest ? tr('guest') : _fallbackName(user),
      photoUrl: guest ? '' : user.photoUrl ?? '',
      profileId: 0,
    );
    if (guest) {
      return _ProfileHeaderContent(
        profile: fallback,
        status: tr('guest'),
        actionLabel: tr('login_signup'),
        actionIcon: PhosphorIcons.signIn(),
        onAction: onSignIn,
        busy: signingIn,
      );
    }
    return _ProfileHeaderContent(
      profile: _ProfileSnapshot(
          name: user.name,
          photoUrl: user.photoUrl ?? '',
          profileId: user.profileId),
      verified: user.isAccountVerified,
      status: plus ? tr('plus_name') : tr('signed_in'),
      actionLabel: tr('profile'),
      actionIcon: PhosphorIcons.user(),
      onAction: onProfile,
      plus: plus,
    );
  }

  static String _fallbackName(AppUser user) {
    final displayName = user.name.trim();
    if (displayName.isNotEmpty) return displayName;
    final email = user.email;
    final localPart = email.split('@').first.trim();
    return localPart.isEmpty ? tr('not_available') : localPart;
  }
}

class _ProfileHeaderContent extends StatelessWidget {
  const _ProfileHeaderContent({
    required this.profile,
    required this.status,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.busy = false,
    this.plus = false,
    this.verified = false,
  });

  final _ProfileSnapshot profile;

  /// The admin-granted badge: a tick after the name.
  final bool verified;
  final String status;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final bool busy;
  final bool plus;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The pill may take everything but the avatar and its gaps, so it
        // stays against the far end and gives way only when it must.
        final maxPill = (constraints.maxWidth -
                _ProfileAvatar.size -
                AppSpace.lg -
                AppSpace.md)
            .clamp(0.0, double.infinity);
        return Row(
          children: <Widget>[
            _ProfileAvatar(profile: profile, plus: plus),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sectionHeader.copyWith(
                            color: palette.foreground,
                          ),
                        ),
                      ),
                      if (verified) ...<Widget>[
                        const SizedBox(width: 5),
                        const VerifiedBadge(size: 19),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (plus)
                    PlusSheen(
                      child: Text(
                        status,
                        style: AppType.metadata.copyWith(
                          fontFamily: AppType.semiBold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Text(
                      status,
                      style:
                          AppType.metadata.copyWith(color: palette.mutedText),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxPill),
              child: PillButton(
                label: actionLabel,
                icon: actionIcon,
                busy: busy,
                onPressed: onAction,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, this.plus = false});

  static const size = 64.0;

  final _ProfileSnapshot profile;
  final bool plus;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget asset() => Image.asset(
          'assets/images/profiles/${profile.profileId}.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/profiles/0.png',
            fit: BoxFit.cover,
          ),
        );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: plus ? null : Border.all(color: palette.hairline),
        gradient: plus
            ? const SweepGradient(colors: <Color>[
                PlusColors.gold,
                PlusColors.coral,
                PlusColors.violet,
                PlusColors.gold,
              ])
            : null,
      ),
      child: ClipOval(
        child: profile.photoUrl.trim().isEmpty
            ? asset()
            : Image.network(
                profile.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => asset(),
              ),
      ),
    );
  }
}

class _ProfileSnapshot {
  const _ProfileSnapshot({
    required this.name,
    required this.photoUrl,
    required this.profileId,
  });

  final String name;
  final String photoUrl;
  final Object profileId;
}

class _DownloadSummaryRow extends StatelessWidget {
  const _DownloadSummaryRow({required this.download, required this.onTap});

  final OfflineDownload download;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final failed = download.state == OfflineDownloadState.failed;
    // Always determinate: a failed or queued item must not look busy.
    final progress = download.isComplete
        ? 1.0
        : (download.progress / 100).clamp(0.0, 1.0).toDouble();
    return ListRow(
      icon: PhosphorIcons.downloadSimple(),
      label: download.title,
      subtitle: tr('download_status_${download.state.name}'),
      onTap: onTap,
      trailing: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              download.isComplete ? '100%' : '${download.progress.round()}%',
              style: AppType.metadata.copyWith(
                color: failed
                    ? Theme.of(context).colorScheme.error
                    : palette.mutedText,
              ),
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              backgroundColor: palette.idleFill,
            ),
          ],
        ),
      ),
    );
  }
}

class MyFlixQuestScreen extends StatelessWidget {
  const MyFlixQuestScreen({super.key});
  @override
  Widget build(BuildContext context) => const LaravelMyFlixQuestScreen();
}

/// The lists as a row of covers, with a new list always first so the row is
/// never empty and making one is a tap away.
class _PlaylistShelf extends StatelessWidget {
  const _PlaylistShelf({
    required this.lists,
    required this.onOpen,
    required this.onCreate,
  });

  final List<Playlist> lists;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;

  static const _width = 112.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    Widget caption(String title, String? subtitle) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: AppSpace.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.cardTitle
                  .copyWith(fontSize: 14, color: palette.foreground),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.metadata
                    .copyWith(fontSize: 12, color: palette.mutedText),
              ),
          ],
        );
    return SizedBox(
      height: _width * 3 / 2 + 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: lists.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SizedBox(
              width: _width,
              child: InkWell(
                onTap: onCreate,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: _width,
                      height: _width * 3 / 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: palette.hairline),
                      ),
                      child: Icon(PhosphorIcons.plus(),
                          size: 32, color: palette.mutedText),
                    ),
                    caption(tr('playlist_new'), null),
                  ],
                ),
              ),
            );
          }
          final list = lists[index - 1];
          return SizedBox(
            width: _width,
            child: Semantics(
              button: true,
              label: list.name,
              child: InkWell(
                onTap: () => onOpen(list.id),
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PlaylistCover(list: list, width: _width),
                    caption(
                      list.name,
                      plural('playlist_title_count', list.entries.length,
                          namedArgs: {'count': '${list.entries.length}'}),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
