import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/home_feed_controller.dart';
import '../../catalog/media_item.dart';
import '../../models/genres.dart';
import '../../mobile/app/mobile_tabs.dart';
import '../../mobile/playback.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import '../widgets/experience_artwork.dart';
import '../widgets/experience_state_panel.dart';

/// Genre-led discovery using the existing catalogue and title-opening logic.
class ExperienceDiscoverScreen extends StatefulWidget {
  const ExperienceDiscoverScreen({this.source, super.key});

  final HomeFeedSource? source;

  @override
  State<ExperienceDiscoverScreen> createState() =>
      _ExperienceDiscoverScreenState();
}

class _ExperienceDiscoverScreenState extends State<ExperienceDiscoverScreen> {
  MediaKind _kind = MediaKind.movie;
  MobileTabController? _tabs;
  bool _started = false;
  int _generation = 0;
  int? _selectedGenre;
  List<Genres> _genres = const [];
  List<MediaItem> _results = const [];
  bool _loadingGenres = false;
  bool _loadingResults = false;
  bool _failedGenres = false;
  bool _failedResults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) _tabs = tabs;
    if (_started) return;
    _started = true;
    unawaited(_loadGenres());
  }

  HomeFeedSource _source() => widget.source ?? CatalogHomeFeedSource(
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );

  Future<void> _loadGenres() async {
    final generation = ++_generation;
    setState(() {
      _loadingGenres = true;
      _failedGenres = false;
      _selectedGenre = null;
      _results = const [];
      _failedResults = false;
    });
    try {
      final genres = await _source().genres(_kind);
      if (!mounted || generation != _generation) return;
      int? firstId;
      for (final genre in genres) {
        if (genre.genreID != null) {
          firstId = genre.genreID;
          break;
        }
      }
      setState(() {
        _genres = genres;
        _selectedGenre = firstId;
        _loadingGenres = false;
      });
      if (firstId != null) {
        await _loadGenre(firstId, requestGeneration: generation);
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingGenres = false;
        _failedGenres = true;
      });
    }
  }

  Future<void> _loadGenre(int genreId, {int? requestGeneration}) async {
    final generation = requestGeneration ?? ++_generation;
    setState(() {
      _selectedGenre = genreId;
      _loadingResults = true;
      _failedResults = false;
      _results = const [];
    });
    try {
      final items = await _source().genre(_kind, genreId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = items;
        _loadingResults = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingResults = false;
        _failedResults = true;
      });
    }
  }

  void _switchKind(MediaKind kind) {
    if (_kind == kind) return;
    setState(() => _kind = kind);
    unawaited(_loadGenres());
  }

  void _selectGenre(int? id) {
    if (id == null || id == _selectedGenre) return;
    unawaited(_loadGenre(id));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    Genres? selected;
    for (final genre in _genres) {
      if (genre.genreID == _selectedGenre) {
        selected = genre;
        break;
      }
    }
    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _tabs?.scrollController(MobileTab.discover),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _kindPicker(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ExperienceTokens.phoneGutter, 22,
                  ExperienceTokens.phoneGutter, 12),
                child: Text('Choose your mood',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: palette.foreground, fontWeight: FontWeight.w900)),
              ),
            ),
            if (_loadingGenres)
              const SliverToBoxAdapter(
                child: SizedBox(height: 180, child: ExperienceStatePanel(
                  kind: ExperienceStateKind.loading,
                  title: 'Loading genres', compact: true))),
            if (_failedGenres)
              SliverToBoxAdapter(child: ExperienceStatePanel(
                kind: ExperienceStateKind.error,
                title: 'Genres could not be loaded',
                actionLabel: 'Retry',
                onAction: () => unawaited(_loadGenres()),
                compact: true)),
            if (!_loadingGenres && !_failedGenres)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceTokens.phoneGutter),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _genreTile(
                      context, _genres[index], index),
                    childCount: _genres.length),
                ),
              ),
            if (selected != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ExperienceTokens.phoneGutter, 28,
                    ExperienceTokens.phoneGutter, 12),
                  child: Row(children: [
                    Expanded(child: Text(
                      'Explore ' + (selected.genreName ?? 'titles'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.foreground, fontWeight: FontWeight.w900))),
                    Text(_results.length.toString() + ' titles',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedText)),
                  ]),
                ),
              ),
            if (_loadingResults)
              const SliverToBoxAdapter(
                child: SizedBox(height: 180, child: ExperienceStatePanel(
                  kind: ExperienceStateKind.loading,
                  title: 'Finding your next watch', compact: true))),
            if (_failedResults)
              SliverToBoxAdapter(child: ExperienceStatePanel(
                kind: ExperienceStateKind.error,
                title: 'Titles could not be loaded',
                actionLabel: 'Retry',
                onAction: () {
                  final id = _selectedGenre;
                  if (id != null) unawaited(_loadGenre(id));
                },
                compact: true)),
            if (!_loadingResults && !_failedResults &&
                _results.isEmpty && selected != null)
              const SliverToBoxAdapter(child: ExperienceStatePanel(
                kind: ExperienceStateKind.empty,
                title: 'No titles in this genre yet', compact: true)),
            if (!_loadingResults && _results.isNotEmpty)
              SliverToBoxAdapter(child: _titleRail(context)),
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
        ExperienceTokens.phoneGutter, 18,
        ExperienceTokens.phoneGutter, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EXPLORE SOMETHING DIFFERENT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.primaryAction, fontWeight: FontWeight.w900,
              letterSpacing: 1.6)),
          const SizedBox(height: 5),
          Text('Discover',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: palette.foreground, fontWeight: FontWeight.w900,
              letterSpacing: -.8)),
          const SizedBox(height: 4),
          Text('Find a new favourite by genre.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.secondaryText)),
        ],
      ),
    );
  }

  Widget _kindPicker(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceTokens.phoneGutter),
      child: SegmentedButton<MediaKind>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: MediaKind.movie,
            label: Text('Movies'),
            icon: Icon(Icons.movie_creation_outlined)),
          ButtonSegment(value: MediaKind.series,
            label: Text('Series'),
            icon: Icon(Icons.live_tv_outlined)),
        ],
        selected: {_kind},
        onSelectionChanged: (selection) => _switchKind(selection.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? palette.primaryAction : palette.surface),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? palette.onPrimaryAction : palette.secondaryText),
        ),
      ),
    );
  }

  Widget _genreTile(BuildContext context, Genres genre, int index) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final active = genre.genreID == _selectedGenre;
    final accent = [
      palette.primaryAction, palette.secondaryAccent,
      palette.userAccent, palette.warning,
    ][index % 4];
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: genre.genreID == null ? null : () => _selectGenre(genre.genreID),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
            border: Border.all(
              color: active ? accent : palette.hairline,
              width: active ? 1.8 : 1),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [accent.withValues(alpha: .2), palette.raisedSurface]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(_genreIcon(index), color: accent, size: 24),
              Row(children: [
                Expanded(child: Text(genre.genreName ?? 'Genre',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.foreground, fontWeight: FontWeight.w800))),
                if (active) Icon(
                  Icons.check_circle_rounded, color: accent, size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  IconData _genreIcon(int index) => switch (index % 8) {
    0 => Icons.bolt_rounded,
    1 => Icons.explore_rounded,
    2 => Icons.animation_rounded,
    3 => Icons.sentiment_very_satisfied_rounded,
    4 => Icons.policy_outlined,
    5 => Icons.theater_comedy_rounded,
    6 => Icons.auto_awesome_rounded,
    _ => Icons.public_rounded,
  };

  Widget _titleRail(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return SizedBox(
      height: 238,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ExperienceTokens.phoneGutter),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _results[index];
          final path = item.posterPath;
          final image = path == null || path.isEmpty ? null :
              NetworkImage('https://image.tmdb.org/t/p/w342' + path);
          return SizedBox(
            width: 128,
            child: InkWell(
              onTap: () => MobilePlayback.openDetails(context, item),
              borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ExperienceArtwork(
                    imageProvider: image,
                    aspectRatio: 2 / 3,
                    semanticLabel: item.title + ' poster')),
                  const SizedBox(height: 8),
                  Text(item.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.foreground, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
