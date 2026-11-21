import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../catalog/home_feed_controller.dart';
import '../../catalog/media_item.dart';
import '../../mobile/app/mobile_tabs.dart';
import '../../mobile/playback.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import '../widgets/experience_action.dart';
import '../widgets/experience_artwork.dart';
import '../widgets/experience_state_panel.dart';

/// New Home composition backed by the existing catalogue and playback contracts.
class ExperienceHomeScreen extends StatefulWidget {
  const ExperienceHomeScreen({this.source, super.key});
  final HomeFeedSource? source;
  @override
  State<ExperienceHomeScreen> createState() => _ExperienceHomeScreenState();
}

class _ExperienceHomeScreenState extends State<ExperienceHomeScreen> {
  HomeFilter _filter = HomeFilter.all;
  bool _started = false;
  MobileTabController? _tabs;
  final Map<HomeFilter, int> _generations = <HomeFilter, int>{};
  final Map<HomeFilter, HomeFeed> _feeds = {};
  final Set<HomeFilter> _loading = {};
  final Set<HomeFilter> _failed = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      _tabs?.removeResetListener(MobileTab.home, _reset);
      _tabs = tabs?..addResetListener(MobileTab.home, _reset);
    }
    if (_started) return;
    _started = true;
    _filter = tabs?.initialHomeFilter ?? HomeFilter.all;
    unawaited(_load(_filter));
  }

  @override
  void dispose() {
    _tabs?.removeResetListener(MobileTab.home, _reset);
    super.dispose();
  }

  void _reset() => _select(HomeFilter.all);

  HomeFeedSource _source() => widget.source ?? CatalogHomeFeedSource(
    settings: context.read<SettingsProvider>(),
    dependencies: context.read<AppDependencyProvider>(),
  );

  Future<void> _load(HomeFilter filter, {bool refresh = false}) async {
    final generation = (_generations[filter] ?? 0) + 1;
    _generations[filter] = generation;
    if (refresh) _feeds.remove(filter);
    _failed.remove(filter);
    setState(() => _loading.add(filter));
    try {
      final feed = await HomeFeedController(_source()).load(filter);
      if (!mounted || generation != _generations[filter]) return;
      setState(() {
        _feeds[filter] = feed;
        _loading.remove(filter);
      });
    } catch (_) {
      if (!mounted || generation != _generations[filter]) return;
      setState(() {
        _loading.remove(filter);
        _failed.add(filter);
      });
    }
  }

  void _select(HomeFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    if (!_feeds.containsKey(filter) && !_loading.contains(filter)) {
      unawaited(_load(filter));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final feed = _feeds[_filter];
    final loading = _loading.contains(_filter);
    final failed = _failed.contains(_filter);
    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: palette.primaryAction,
          onRefresh: () => _load(_filter, refresh: true),
          child: ListView(
            controller: _tabs?.scrollController(MobileTab.home),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 40),
            children: [
              _topBar(context),
              const SizedBox(height: 20),
              _filters(palette),
              const SizedBox(height: 16),
              if (feed == null && loading)
                const SizedBox(height: 420, child: ExperienceStatePanel(
                  kind: ExperienceStateKind.loading,
                  title: 'Finding your next favourite',
                  description: 'Curating films and series for you',
                ))
              else if (feed == null && failed)
                SizedBox(height: 420, child: ExperienceStatePanel(
                  kind: ExperienceStateKind.error,
                  title: 'Could not load your home feed',
                  description: 'Check your connection and try again.',
                  actionLabel: 'Try again',
                  onAction: () => unawaited(_load(_filter, refresh: true)),
                ))
              else if (feed == null || feed.isEmpty)
                const SizedBox(height: 420, child: ExperienceStatePanel(
                  kind: ExperienceStateKind.empty,
                  title: 'Nothing to show just yet',
                  description: 'Pull down to refresh your catalogue.',
                ))
              else ...[
                if (feed.hero case final hero?) _hero(context, hero),
                const SizedBox(height: 20),
                ..._shelves(context, feed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExperienceTokens.phoneGutter),
      child: Row(children: [
        Container(
          width: 42, height: 42, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.raisedSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.hairline),
          ),
          child: Text('7x', style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.primaryAction, fontWeight: FontWeight.w900,
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('7xPlay', style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.foreground, fontWeight: FontWeight.w900,
          )),
          Text('Stories worth staying in for.', style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.secondaryText,
          )),
        ])),
        IconButton.filledTonal(
          tooltip: 'Search',
          onPressed: () => MobileTabScope.maybeOf(context)?.select(MobileTab.search),
          icon: const Icon(Icons.search_rounded),
        ),
      ]),
    );
  }

  Widget _filters(ExperiencePalette palette) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ExperienceTokens.phoneGutter),
      children: [
        _filterChip('For you', HomeFilter.all, palette),
        const SizedBox(width: 8),
        _filterChip('Movies', HomeFilter.movies, palette),
        const SizedBox(width: 8),
        _filterChip('Series', HomeFilter.series, palette),
      ],
    ),
  );

  Widget _filterChip(String label, HomeFilter filter, ExperiencePalette palette) {
    final selected = filter == _filter;
    return ChoiceChip(
      label: Text(label), selected: selected, onSelected: (_) => _select(filter),
      showCheckmark: false,
      backgroundColor: palette.surface,
      selectedColor: palette.primaryAction,
      side: BorderSide(color: selected ? palette.primaryAction : palette.hairline),
      labelStyle: TextStyle(
        color: selected ? palette.onPrimaryAction : palette.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    );
  }

  Widget _hero(BuildContext context, MediaItem item) {
    final path = item.backdropPath ?? item.posterPath;
    final image = path == null || path.isEmpty
        ? null
        : NetworkImage('https://image.tmdb.org/t/p/w1280$path');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExperienceTokens.phoneGutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ExperienceTokens.heroRadius),
        child: SizedBox(
          height: 420,
          child: Stack(fit: StackFit.expand, children: [
            ExperienceArtwork(
              imageProvider: image, aspectRatio: 16 / 9,
              borderRadius: BorderRadius.zero,
              semanticLabel: '${item.title} featured artwork',
            ),
            DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: .08), Colors.black.withValues(alpha: .25), Colors.black.withValues(alpha: .94)],
                stops: const [0, .4, 1],
              ),
            )),
            PositionedDirectional(
              start: 20, end: 20, bottom: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 8, children: [
                  _tag(item.kind == MediaKind.movie ? 'MOVIE' : 'SERIES'),
                  if (item.year != null) _tag(item.year!),
                  if (item.rating != null) _tag('★ ${item.rating!.toStringAsFixed(1)}'),
                ]),
                const SizedBox(height: 12),
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900, height: 1.02,
                  )),
                if (item.overview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(item.overview, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .82),
                    )),
                ],
                const SizedBox(height: 16),
                Wrap(spacing: 8, children: [
                  ExperienceAction(
                    label: 'Details', tone: ExperienceActionTone.secondary,
                    leading: const Icon(Icons.info_outline_rounded, size: 18),
                    onPressed: () => MobilePlayback.openDetails(context, item),
                  ),
                  if (MobilePlayback.canPlay(context))
                    ExperienceAction(
                      label: 'Play now',
                      leading: const Icon(Icons.play_arrow_rounded, size: 19),
                      onPressed: () => MobilePlayback.play(context, item),
                    ),
                ]),
              ]),
            ),
            PositionedDirectional(top: 16, end: 16, child: _tag('SPOTLIGHT')),
          ]),
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .58),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: .2)),
    ),
    child: Text(text, style: const TextStyle(
      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6,
    )),
  );

  List<Widget> _shelves(BuildContext context, HomeFeed feed) {
    final widgets = <Widget>[];
    for (final kind in _filter.kinds) {
      final rows = feed.of(kind);
      if (_filter == HomeFilter.all && !rows.isEmpty) {
        widgets.add(_heading(context, kind == MediaKind.movie ? 'MOVIES' : 'SERIES'));
      }
      _addShelf(widgets, context, 'Trending now', rows.trending);
      _addShelf(widgets, context, 'Popular', rows.popular);
      _addShelf(widgets, context, 'New & noteworthy', rows.newReleases);
      _addShelf(widgets, context, 'Top rated', rows.topRated);
      _addShelf(widgets, context, 'Coming soon', rows.upcoming);
      _addShelf(widgets, context, 'Top picks', rows.topTen);
    }
    return widgets;
  }

  void _addShelf(List<Widget> out, BuildContext context, String title, List<MediaItem> items) {
    if (items.isEmpty) return;
    out.add(_heading(context, title));
    out.add(SizedBox(
      height: 238,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: ExperienceTokens.phoneGutter),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _poster(context, items[index]),
      ),
    ));
    out.add(const SizedBox(height: 20));
  }

  Widget _heading(BuildContext context, String title) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: palette.foreground, fontWeight: FontWeight.w900, letterSpacing: -.4,
      )),
    );
  }

  Widget _poster(BuildContext context, MediaItem item) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final path = item.posterPath;
    final image = path == null || path.isEmpty
        ? null
        : NetworkImage('https://image.tmdb.org/t/p/w342$path');
    return SizedBox(
      width: 132,
      child: InkWell(
        onTap: () => MobilePlayback.openDetails(context, item),
        borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            ExperienceArtwork(imageProvider: image, aspectRatio: 2 / 3, semanticLabel: '${item.title} poster'),
            if (item.rating != null)
              PositionedDirectional(top: 7, end: 7, child: _tag('★ ${item.rating!.toStringAsFixed(1)}')),
          ])),
          const SizedBox(height: 8),
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: palette.foreground, fontWeight: FontWeight.w700,
            )),
          if (item.year != null) Text(item.year!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: palette.mutedText)),
        ]),
      ),
    );
  }
}
