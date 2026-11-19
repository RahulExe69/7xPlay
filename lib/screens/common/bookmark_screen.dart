import 'package:easy_localization/easy_localization.dart';
import '../../presentation/session/auth_runtime.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/home_feed_controller.dart';
import '../../catalog/media_item.dart';
import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/my_list.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../mobile/widgets/poster_grid.dart';
import '../../mobile/widgets/skeletons.dart';
import '../../provider/bookmark_provider.dart';
import '../../services/bookmark_sync_service.dart';
import '../../services/globle_method.dart';
import '/screens/common/sync_screen.dart';
import '../../widgets/hosted_ads_banner.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({
    this.embedded = false,
    this.onDiscover,
    super.key,
  });

  final bool embedded;

  /// Returns to the root shell's Discover destination when the viewer chooses
  /// to browse from an empty list. The caller owns the tab controller because
  /// pushed routes do not inherit MobileTabScope from the page below them.
  final VoidCallback? onDiscover;

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  int _selectedKind = 0;

  @override
  void initState() {
    super.initState();
    _triggerAutoSync();
  }

  void _triggerAutoSync() async {
    if (BookmarkSyncService.instance.canSync) {
      await BookmarkSyncService.instance.autoSyncIfSignedIn();
      if (mounted) {
        context.read<BookmarkProvider>().fetchBookmarks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: widget.embedded
          ? null
          : PageAppBar(
              title: tr('my_list'),
              actions: <Widget>[
                IconButton(
                  tooltip: tr('sync'),
                  color: palette.mutedText,
                  onPressed: _syncBookmarks,
                  icon: Icon(PhosphorIcons.arrowsClockwise()),
                ),
              ],
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.embedded)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter(context),
                  AppSpace.lg,
                  AppSpace.gutter(context),
                  AppSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('my_list'),
                        style: AppType.scaled(context, AppType.pageTitle)
                            .copyWith(color: palette.foreground),
                      ),
                    ),
                    PillButton(
                      label: tr('sync'),
                      icon: PhosphorIcons.arrowsClockwise(),
                      onPressed: _syncBookmarks,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpace.gutter(context),
                widget.embedded ? AppSpace.xs : AppSpace.md,
                AppSpace.gutter(context),
                AppSpace.md,
              ),
              child: _MyListOverview(
                movies: bookmarkProvider.movies.length,
                series: bookmarkProvider.tvShows.length,
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
              child: SegmentSwitch<int>(
                selected: _selectedKind,
                onChanged: (value) => setState(() => _selectedKind = value),
                segments: <Segment<int>>[
                  Segment<int>(0, tr('movies'),
                      icon: PhosphorIcons.filmStrip()),
                  Segment<int>(1, tr('tv_series'),
                      icon: PhosphorIcons.television()),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            RemoteHostedAdsBanner(
              placement: 'bookmarks',
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedKind,
                children: <Widget>[
                  _SavedGrid(
                    items: MyList.items(context, filter: HomeFilter.movies),
                    loading: bookmarkProvider.isLoading,
                    emptyMessage: tr('no_movies_bookmarked'),
                    onDiscover: widget.onDiscover,
                  ),
                  _SavedGrid(
                    items: MyList.items(context, filter: HomeFilter.series),
                    loading: bookmarkProvider.isLoading,
                    emptyMessage: tr('no_tv_bookmarked'),
                    onDiscover: widget.onDiscover,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _syncBookmarks() {
    if (AuthRuntime.maybeSession?.user == null) {
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(
          content: Text(
            tr('bookmark_feature_notice'),
            style: kTextVerySmallBodyStyle,
            maxLines: 6,
          ),
        ),
        context,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncScreen()),
    ).then((_) {
      if (!mounted) return;
      context.read<BookmarkProvider>().fetchBookmarks();
    });
  }
}


/// The saved library's snapshot and filter context. Counts come directly
/// from the local bookmark provider, so they remain accurate offline.
class _MyListOverview extends StatelessWidget {
  const _MyListOverview({required this.movies, required this.series});

  final int movies;
  final int series;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final total = movies + series;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$total',
                  style: AppType.heroTitle.copyWith(
                    fontSize: 28,
                    color: palette.foreground,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${tr('movies')}: $movies  ·  ${tr('tv_series')}: $series',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Icon(
            PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.bold),
            size: 30,
            color: palette.accent,
          ),
        ],
      ),
    );
  }
}

/// One kind of saved titles: the browse grid while there are any, its
/// skeleton while the first read is on its way, and the empty state after.
class _SavedGrid extends StatelessWidget {
  const _SavedGrid({
    required this.items,
    required this.loading,
    required this.emptyMessage,
    this.onDiscover,
  });

  final List<MediaItem> items;
  final bool loading;
  final String emptyMessage;
  final VoidCallback? onDiscover;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && loading) return const PosterGridSkeleton();
    if (items.isEmpty) {
      return EmptyState(
        icon: PhosphorIcons.bookmarkSimple(),
        title: emptyMessage,
        message: tr('my_list_empty_hint'),
        actionLabel: onDiscover == null ? null : tr('discover'),
        actionIcon:
            onDiscover == null ? null : PhosphorIcons.compass(),
        onAction: onDiscover == null
            ? null
            : () {
                onDiscover!();
                Navigator.of(context).maybePop();
              },
      );
    }
    return PosterGrid(items: items);
  }
}
