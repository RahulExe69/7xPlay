import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../catalog/continue_watching.dart';
import '../../catalog/media_item.dart';
import '../../data/models/app_user.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../presentation/session/auth_runtime.dart';
import '../../provider/bookmark_provider.dart';
import '../../provider/offline_download_provider.dart';
import '../../provider/playlist_provider.dart';
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
import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../../services/plus_navigation.dart';
import '../app/mobile_tabs.dart';
import '../playback.dart';
import 'flix_ai_screen.dart';
import 'playlists_screen.dart';
import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import '../widgets/experience_action.dart';
import '../widgets/experience_artwork.dart';
import '../widgets/experience_state_panel.dart';

/// New My Space dashboard. Personal media remains local-first and every
/// shortcut opens the existing feature route rather than a placeholder page.
class ExperienceMySpaceScreen extends StatefulWidget {
  const ExperienceMySpaceScreen({super.key});

  @override
  State<ExperienceMySpaceScreen> createState() => _ExperienceMySpaceScreenState();
}

class _ExperienceMySpaceScreenState extends State<ExperienceMySpaceScreen> {
  AppUser? _user;
  bool _signingIn = false;
  bool _started = false;

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
      if (mounted && !_started) {
        _started = true;
        unawaited(_loadLocalLibrary());
      }
    });
  }

  @override
  void dispose() {
    AuthRuntime.maybeSession?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    try {
      setState(() => _user = AuthRuntime.session.user);
    } catch (_) {
      setState(() => _user = null);
    }
  }

  Future<void> _loadLocalLibrary() async {
    final downloads = context.read<OfflineDownloadProvider>();
    final bookmarks = context.read<BookmarkProvider>();
    final recent = context.read<RecentProvider>();
    final playlists = context.read<PlaylistProvider?>();
    if (downloads.downloads.isEmpty && !downloads.loading) {
      await _quietly(downloads.refresh);
    }
    await Future.wait<void>([
      _quietly(bookmarks.fetchBookmarks),
      _quietly(recent.fetchMovies),
      _quietly(recent.fetchEpisodes),
      if (playlists != null) _quietly(playlists.load),
    ]);
  }

  Future<void> _quietly(Future<void> Function() load) async {
    try {
      await load();
    } catch (_) {
      // One unavailable section must not take the personal dashboard down.
    }
  }

  bool get _signedIn => _user != null;

  void _push(Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _openMyList() {
    _push(BookmarkScreen(
      onDiscover: () => MobileTabScope.maybeOf(context)
          ?.select(MobileTab.discover),
    ));
  }

  Future<void> _leaveGuestSession() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await FlixQuestAuthService().signOut();
      if (mounted) await AuthNavigationService.returnToSignedOutRoot(context);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your locally saved library stays on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<SettingsProvider>().analytics.trackSignOut();
    context.read<SettingsProvider>().analytics.resetUser();
    await _leaveGuestSession();
  }

  Future<void> _shareApp() async {
    context.read<SettingsProvider>().analytics.trackShare(shareType: 'App');
    await Share.share(tr('share_text'));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final recent = context.watch<RecentProvider>();
    final bookmarks = context.watch<BookmarkProvider>();
    final offline = context.watch<OfflineDownloadProvider>();
    final playlists = context.watch<PlaylistProvider?>();
    final continueWatching = continueWatchingItems(
      movies: recent.movies,
      episodes: recent.episodes,
      upNext: recent.upNext,
    );
    final saved = <MediaItem>[
      ...bookmarks.movies.map(MediaItem.fromMovie),
      ...bookmarks.tvShows.map(MediaItem.fromSeries),
    ];
    final plus = context.watch<PlusController?>()?.adFree ?? false;

    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceTokens.phoneGutter),
                child: _profileCard(context, plus),
              ),
            ),
            SliverToBoxAdapter(
              child: _sectionHeader(context, 'Your space'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceTokens.phoneGutter),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.65,
                ),
                delegate: SliverChildListDelegate([
                  _shortcut(context, 'My List', 'Saved movies & series',
                    Icons.bookmark_border_rounded, _openMyList),
                  _shortcut(context, 'Downloads',
                    offline.downloads.length.toString() + ' offline items',
                    Icons.download_rounded,
                    () => _push(const DownloadsScreen())),
                  _shortcut(context, 'Playlists',
                    playlists == null ? 'Personal collections' :
                      playlists.lists.length.toString() + ' collections',
                    Icons.queue_music_rounded,
                    () => _push(const PlaylistsScreen())),
                  _shortcut(context, '7x AI', 'Your viewing companion',
                    Icons.auto_awesome_rounded,
                    () => _push(const FlixAiScreen())),
                ]),
              ),
            ),
            if (continueWatching.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _sectionHeader(context, 'Continue watching',
                  trailing: continueWatching.length.toString() + ' in progress'),
              ),
              SliverToBoxAdapter(
                child: _mediaRail(context, continueWatching, continueMode: true),
              ),
            ],
            if (saved.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _sectionHeader(context, 'Your watchlist',
                  trailing: saved.length.toString() + ' saved',
                  actionLabel: 'View all', onAction: _openMyList),
              ),
              SliverToBoxAdapter(child: _mediaRail(context, saved)),
            ] else if (!bookmarks.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceTokens.phoneGutter),
                  child: _emptyCard(
                    context, 'Your watchlist is waiting',
                    'Save titles from their detail pages and they’ll appear here.',
                    Icons.bookmark_add_outlined),
                ),
              ),
            if (playlists != null && playlists.lists.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _sectionHeader(context, 'Your playlists',
                  trailing: playlists.lists.length.toString() + ' lists',
                  actionLabel: 'Open', onAction: () => _push(const PlaylistsScreen())),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ExperienceTokens.phoneGutter),
                    itemCount: playlists.lists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final list = playlists.lists[index];
                      return SizedBox(
                        width: 190,
                        child: Material(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _push(const PlaylistsScreen()),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.queue_music_rounded,
                                    color: palette.primaryAction),
                                  Text(list.name, maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: palette.foreground,
                                      fontWeight: FontWeight.w800)),
                                  Text(list.entries.length.toString() + ' titles',
                                    style: TextStyle(color: palette.mutedText,
                                      fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: _sectionHeader(context, 'Offline library',
                trailing: offline.downloads.length.toString() + ' items',
                actionLabel: 'Manage',
                onAction: () => _push(const DownloadsScreen()),
              ),
            ),
            if (offline.loading && offline.downloads.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(height: 84, child: ExperienceStatePanel(
                  kind: ExperienceStateKind.loading,
                  title: 'Loading downloads', compact: true)),
              )
            else if (offline.downloads.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceTokens.phoneGutter),
                  child: _emptyCard(
                    context, 'Nothing downloaded yet',
                    'Keep a few favourites ready for offline viewing.',
                    Icons.cloud_download_outlined),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceTokens.phoneGutter),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final download = offline.downloads[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          download.isComplete
                              ? Icons.check_circle_outline_rounded
                              : Icons.downloading_rounded,
                          color: palette.primaryAction),
                        title: Text(download.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.foreground,
                            fontWeight: FontWeight.w700)),
                        subtitle: Text(download.isComplete
                            ? 'Ready offline'
                            : download.progress.round().toString() + '% downloaded',
                          style: TextStyle(color: palette.mutedText)),
                        trailing: Icon(Icons.chevron_right_rounded,
                          color: palette.mutedText),
                        onTap: () => _push(const DownloadsScreen()),
                      );
                    },
                    childCount: offline.downloads.length.clamp(0, 3).toInt(),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: _sectionHeader(context, 'Account & app')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceTokens.phoneGutter),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _menuRow(context, 'Settings', Icons.tune_rounded,
                    () => _push(const app_settings.Settings())),
                  if (_signedIn)
                    _menuRow(context, tr('plus_name'), Icons.workspace_premium_outlined,
                      () => unawaited(openPlus(context))),
                  _menuRow(context, 'Sync', Icons.sync_rounded,
                    () => _push(const SyncScreen())),
                  _menuRow(context, 'Server status', Icons.dns_outlined,
                    () => _push(const ServerStatusScreen())),
                  _menuRow(context, 'Wellness', Icons.insights_rounded,
                    () => _push(const WellnessScreen())),
                  _menuRow(context, 'Check for updates', Icons.system_update_alt_rounded,
                    () => _push(const UpdateScreen(isForced: false))),
                  _menuRow(context, 'Share 7xPlay', Icons.ios_share_rounded, _shareApp),
                  _menuRow(context, 'About', Icons.info_outline_rounded,
                    () => _push(const AboutPage())),
                  if (_signedIn)
                    _menuRow(context, 'Sign out', Icons.logout_rounded,
                      _confirmSignOut, destructive: true),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 18,
        ExperienceTokens.phoneGutter, 20),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR PERSONAL LIBRARY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.primaryAction, fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
            const SizedBox(height: 5),
            Text('My Space',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: palette.foreground, fontWeight: FontWeight.w900,
                letterSpacing: -.8)),
          ],
        )),
        IconButton.filledTonal(
          tooltip: 'Settings',
          onPressed: () => _push(const app_settings.Settings()),
          icon: const Icon(Icons.tune_rounded),
        ),
      ]),
    );
  }

  Widget _profileCard(BuildContext context, bool plus) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final user = _user;
    final guest = user == null;
    final displayName = guest
        ? 'Guest profile'
        : user.name.trim().isNotEmpty
            ? user.name.trim()
            : user.email.split('@').first;
    final photo = guest ? null : user.photoUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ExperienceTokens.heroRadius),
        border: Border.all(color: palette.hairline),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            palette.raisedSurface,
            Color.lerp(palette.raisedSurface, palette.secondaryAccent, .14)!,
            palette.surface,
          ],
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: plus ? palette.primaryAction : palette.hairline,
              width: plus ? 2 : 1),
          ),
          child: CircleAvatar(
            radius: 29,
            backgroundColor: palette.surface,
            backgroundImage: photo == null || photo.isEmpty
                ? null : NetworkImage(photo),
            child: photo == null || photo.isEmpty
                ? Icon(Icons.person_rounded, color: palette.mutedText, size: 30)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.foreground, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(guest ? 'Your library stays on this device' :
              plus ? '7xPlay Plus member' : 'Signed in',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.secondaryText)),
            if (!guest && user.isAccountVerified) ...[
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.verified_rounded, color: palette.success, size: 14),
                const SizedBox(width: 5),
                Text('Verified account', style: TextStyle(
                  color: palette.success, fontSize: 11,
                  fontWeight: FontWeight.w700)),
              ]),
            ],
          ],
        )),
        const SizedBox(width: 8),
        if (guest)
          ExperienceAction(
            label: _signingIn ? 'Opening…' : 'Sign in',
            isLoading: _signingIn,
            onPressed: _signingIn ? null : _leaveGuestSession,
          )
        else
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => _push(const ProfileEdit()),
            icon: Icon(Icons.edit_outlined, color: palette.foreground),
          ),
      ]),
    );
  }

  Widget _shortcut(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: palette.primaryAction, size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.foreground, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.mutedText)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    String? trailing,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 26,
        ExperienceTokens.phoneGutter, 12),
      child: Row(children: [
        Expanded(child: Text(title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.foreground, fontWeight: FontWeight.w900))),
        if (trailing != null) Text(trailing,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.mutedText)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ]),
    );
  }

  Widget _mediaRail(
    BuildContext context,
    List<MediaItem> items, {
    bool continueMode = false,
  }) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ExperienceTokens.phoneGutter),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final path = item.posterPath;
          final image = path == null || path.isEmpty ? null :
            NetworkImage('https://image.tmdb.org/t/p/w342' + path);
          return SizedBox(
            width: 126,
            child: InkWell(
              onTap: () => continueMode
                  ? MobilePlayback.play(context, item)
                  : MobilePlayback.openDetails(context, item),
              borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Stack(fit: StackFit.expand, children: [
                    ExperienceArtwork(imageProvider: image, aspectRatio: 2 / 3),
                    if (continueMode && item.progress != null)
                      PositionedDirectional(
                        start: 7, end: 7, bottom: 7,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            color: palette.primaryAction,
                          ),
                        ),
                      ),
                  ])),
                  const SizedBox(height: 7),
                  Text(item.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.foreground, fontWeight: FontWeight.w700)),
                  if (continueMode && item.progressLabel != null)
                    Text(item.progressLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedText)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(children: [
        Icon(icon, color: palette.mutedText, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(
              color: palette.foreground, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(
              color: palette.secondaryText, fontSize: 12)),
          ],
        )),
      ]),
    );
  }

  Widget _menuRow(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
        color: destructive ? palette.error : palette.secondaryText),
      title: Text(title, style: TextStyle(
        color: destructive ? palette.error : palette.foreground,
        fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: palette.mutedText),
      onTap: onTap,
    );
  }
}
