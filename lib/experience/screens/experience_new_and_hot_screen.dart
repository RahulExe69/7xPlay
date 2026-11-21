import '../design/experience_palette.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/media_item.dart';
import '../../catalog/new_and_hot.dart';
import '../../mobile/app/mobile_tabs.dart';
import '../../mobile/playback.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import '../widgets/experience_action.dart';
import '../widgets/experience_artwork.dart';
import '../widgets/experience_state_panel.dart';

/// Editorial New & Hot destination backed by the existing catalogue contract.
class ExperienceNewAndHotScreen extends StatefulWidget {
  const ExperienceNewAndHotScreen({this.source, this.now, super.key});

  final NewAndHotSource? source;
  final DateTime Function()? now;

  @override
  State<ExperienceNewAndHotScreen> createState() =>
      _ExperienceNewAndHotScreenState();
}

class _ExperienceNewAndHotScreenState extends State<ExperienceNewAndHotScreen> {
  HotSegment _segment = HotSegment.comingSoon;
  MobileTabController? _tabs;
  bool _started = false;
  final Map<HotSegment, NewAndHotFeed> _feeds = {};
  final Set<HotSegment> _loading = {};
  final Set<HotSegment> _failed = {};
  final Map<HotSegment, int> _generations = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      _tabs?.removeResetListener(MobileTab.newAndHot, _reset);
      _tabs = tabs?..addResetListener(MobileTab.newAndHot, _reset);
    }
    if (_started) return;
    _started = true;
    unawaited(_load(_segment));
  }

  @override
  void dispose() {
    _tabs?.removeResetListener(MobileTab.newAndHot, _reset);
    super.dispose();
  }

  NewAndHotSource _source() => widget.source ?? CatalogNewAndHotSource(
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );

  Future<void> _load(HotSegment segment, {bool refresh = false}) async {
    if (_loading.contains(segment) ||
        (!refresh && _feeds.containsKey(segment))) return;
    final generation = (_generations[segment] ?? 0) + 1;
    _generations[segment] = generation;
    setState(() {
      _loading.add(segment);
      _failed.remove(segment);
      if (refresh) _feeds.remove(segment);
    });
    try {
      final feed = await NewAndHotCatalog(
        _source(),
        now: widget.now ?? DateTime.now,
      ).load(segment);
      if (!mounted || generation != _generations[segment]) return;
      setState(() {
        _feeds[segment] = feed;
        _loading.remove(segment);
      });
    } catch (_) {
      if (!mounted || generation != _generations[segment]) return;
      setState(() {
        _loading.remove(segment);
        _failed.add(segment);
      });
    }
  }

  void _select(HotSegment segment) {
    if (segment == _segment) return;
    setState(() => _segment = segment);
    final scroll = _tabs?.scrollController(MobileTab.newAndHot);
    if (scroll?.hasClients ?? false) scroll!.jumpTo(0);
    unawaited(_load(segment));
  }

  void _reset() => _select(HotSegment.comingSoon);

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final feed = _feeds[_segment];
    final loading = _loading.contains(_segment);
    final failed = _failed.contains(_segment);
    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _tabs?.scrollController(MobileTab.newAndHot),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _segments(palette)),
            if (feed == null && loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ExperienceStatePanel(
                  kind: ExperienceStateKind.loading,
                  title: 'Finding what is worth watching',
                  description: 'Fresh releases and today’s popular picks',
                ),
              )
            else if (feed == null && failed)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ExperienceStatePanel(
                  kind: ExperienceStateKind.error,
                  title: 'New & Hot did not load',
                  description: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => unawaited(_load(_segment, refresh: true)),
                ),
              )
            else if (feed == null || feed.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ExperienceStatePanel(
                  kind: ExperienceStateKind.empty,
                  title: 'Nothing new here yet',
                  description: 'Try another category or refresh later.',
                ),
              )
            else
              ..._content(context, feed),
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 18, ExperienceTokens.phoneGutter, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THE 7X EDIT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.primaryAction,
                    fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                const SizedBox(height: 5),
                Text('New & Hot',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: palette.foreground, fontWeight: FontWeight.w900,
                    letterSpacing: -.8)),
                const SizedBox(height: 4),
                Text('Fresh drops. Big conversations.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.secondaryText)),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Refresh',
            onPressed: () => unawaited(_load(_segment, refresh: true)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _segments(ExperiencePalette palette) {
    const labels = {
      HotSegment.comingSoon: 'Coming soon',
      HotSegment.everyoneWatching: 'Trending',
      HotSegment.topMovies: 'Top movies',
      HotSegment.topSeries: 'Top series',
    };
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ExperienceTokens.phoneGutter),
        itemCount: HotSegment.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final segment = HotSegment.values[index];
          final selected = segment == _segment;
          return ChoiceChip(
            label: Text(labels[segment]!),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => _select(segment),
            backgroundColor: palette.surface,
            selectedColor: palette.primaryAction,
            side: BorderSide(
              color: selected ? palette.primaryAction : palette.hairline),
            labelStyle: TextStyle(
              color: selected ? palette.onPrimaryAction : palette.secondaryText,
              fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, NewAndHotFeed feed) {
    if (_segment != HotSegment.comingSoon) return _ranked(context, feed.items);
    final widgets = <Widget>[];
    if (feed.groups.isNotEmpty && feed.groups.first.items.isNotEmpty) {
      widgets.add(SliverToBoxAdapter(
        child: _feature(context, feed.groups.first.items.first)));
    }
    for (final group in feed.groups) {
      widgets.add(SliverToBoxAdapter(
        child: _sectionTitle(
          context,
          MaterialLocalizations.of(context).formatMediumDate(group.date),
          trailing: group.items.length.toString() + ' titles',
        )));
      widgets.add(SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ExperienceTokens.phoneGutter),
            itemCount: group.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _poster(context, group.items[index]),
          ),
        )));
    }
    return widgets;
  }

  List<Widget> _ranked(BuildContext context, List<MediaItem> items) {
    if (items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ExperienceStatePanel(
            kind: ExperienceStateKind.empty,
            title: 'No titles in this list yet'),
        ),
      ];
    }
    final title = _segment == HotSegment.everyoneWatching
        ? 'Everyone is watching'
        : _segment == HotSegment.topMovies
            ? 'Top 10 movies today'
            : 'Top 10 series today';
    return [
      SliverToBoxAdapter(child: _sectionTitle(
        context, title, trailing: 'Updated today')),
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: ExperienceTokens.phoneGutter),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _rankedTile(context, index + 1, items[index])),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  Widget _feature(BuildContext context, MediaItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 18, ExperienceTokens.phoneGutter, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ExperienceTokens.heroRadius),
        child: SizedBox(
          height: 320,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExperienceArtwork(
                imageProvider: _backdrop(item),
                aspectRatio: 16 / 9,
                borderRadius: BorderRadius.zero,
                semanticLabel: item.title + ' coming soon artwork'),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .02),
                      Colors.black.withValues(alpha: .94),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 18, end: 18, bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('FIRST LOOK'),
                    const SizedBox(height: 9),
                    Text(item.title, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(item.releaseDate ?? 'Release date to be announced',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70)),
                    const SizedBox(height: 14),
                    Row(children: [
                      ExperienceAction(
                        label: 'View details',
                        tone: ExperienceActionTone.secondary,
                        leading: const Icon(Icons.info_outline_rounded),
                        onPressed: () => MobilePlayback.openDetails(context, item)),
                      if (MobilePlayback.canPlay(context)) ...[
                        const SizedBox(width: 8),
                        ExperienceAction(
                          label: 'Play',
                          leading: const Icon(Icons.play_arrow_rounded),
                          onPressed: () => MobilePlayback.play(context, item)),
                      ],
                    ]),
                  ],
                ),
              ),
              PositionedDirectional(top: 16, start: 16,
                child: _eyebrow('UP NEXT')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, {String? trailing}) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 24, ExperienceTokens.phoneGutter, 12),
      child: Row(children: [
        Expanded(child: Text(title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.foreground, fontWeight: FontWeight.w900))),
        if (trailing != null) Text(trailing,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.mutedText)),
      ]),
    );
  }

  Widget _poster(BuildContext context, MediaItem item) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return SizedBox(
      width: 124,
      child: InkWell(
        onTap: () => MobilePlayback.openDetails(context, item),
        borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ExperienceArtwork(
                imageProvider: _posterImage(item),
                aspectRatio: 2 / 3,
                borderRadius: BorderRadius.zero,
                semanticLabel: item.title + ' poster'),
            ),
          )),
          const SizedBox(height: 7),
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: palette.foreground, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _rankedTile(BuildContext context, int rank, MediaItem item) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return InkWell(
      onTap: () => MobilePlayback.openDetails(context, item),
      borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
      child: SizedBox(
        height: 116,
        child: Row(children: [
          SizedBox(width: 42, child: Text(
            rank.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: palette.primaryAction, fontWeight: FontWeight.w900))),
          SizedBox(width: 76, child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ExperienceArtwork(
                imageProvider: _posterImage(item), aspectRatio: 2 / 3,
                borderRadius: BorderRadius.zero),
            ),
          )),
          const SizedBox(width: 14),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.foreground, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text([
                item.kind == MediaKind.movie ? 'Movie' : 'Series',
                if (item.year != null) item.year!,
                if (item.rating != null) '★ ' + item.rating!.toStringAsFixed(1),
              ].join('  •  '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.secondaryText)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: palette.mutedText),
        ]),
      ),
    );
  }

  Widget _eyebrow(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white24)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 10,
        fontWeight: FontWeight.w900, letterSpacing: 1)),
    ),
  );

  ImageProvider<Object>? _posterImage(MediaItem item) {
    final path = item.posterPath;
    return path == null || path.isEmpty
        ? null : NetworkImage('https://image.tmdb.org/t/p/w342' + path);
  }

  ImageProvider<Object>? _backdrop(MediaItem item) {
    final path = item.backdropPath ?? item.posterPath;
    return path == null || path.isEmpty
        ? null : NetworkImage('https://image.tmdb.org/t/p/w1280' + path);
  }
}
