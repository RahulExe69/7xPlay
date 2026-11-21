import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/details_controller.dart';
import '../../catalog/media_item.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/bookmark_provider.dart';
import '../../provider/settings_provider.dart';
import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import '../widgets/experience_action.dart';
import '../widgets/experience_artwork.dart';
import '../widgets/experience_state_panel.dart';

typedef ExperienceDetailsLoader = Future<MediaDetailsData> Function(
  MediaItem item,
);
typedef ExperienceDetailsPlay = Future<void> Function(BuildContext context);
typedef ExperienceDetailsOpen = void Function(
  BuildContext context,
  MediaItem item,
);

/// 7xPlay's movie and series details surface. Playback and title navigation
/// are supplied by MobilePlayback so the player engine remains independent.
class ExperienceTitleDetailsScreen extends StatefulWidget {
  const ExperienceTitleDetailsScreen({
    required this.item,
    this.loadDetails,
    this.onPlay,
    this.onOpenTitle,
    this.canPlay = true,
    super.key,
  });

  final MediaItem item;
  final ExperienceDetailsLoader? loadDetails;
  final ExperienceDetailsPlay? onPlay;
  final ExperienceDetailsOpen? onOpenTitle;
  final bool canPlay;

  @override
  State<ExperienceTitleDetailsScreen> createState() =>
      _ExperienceTitleDetailsScreenState();
}

class _ExperienceTitleDetailsScreenState
    extends State<ExperienceTitleDetailsScreen> {
  final MediaDetailsController _controller = const MediaDetailsController();
  MediaDetailsData? _details;
  bool _loading = false;
  bool _failed = false;
  bool _saving = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final loader = widget.loadDetails;
      final data = loader != null
          ? await loader(widget.item)
          : await _controller.load(
              item: widget.item,
              settings: context.read<SettingsProvider>(),
              dependencies: context.read<AppDependencyProvider>(),
            );
      if (!mounted) return;
      setState(() {
        _details = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  bool _isSaved(BookmarkProvider? bookmarks) {
    if (bookmarks == null) return false;
    return widget.item.kind == MediaKind.movie
        ? bookmarks.isMovieBookmarked(widget.item.id)
        : bookmarks.isTVBookmarked(widget.item.id);
  }

  Future<void> _toggleSaved(BookmarkProvider? bookmarks) async {
    if (bookmarks == null || _saving) return;
    setState(() => _saving = true);
    try {
      final item = widget.item;
      if (item.kind == MediaKind.movie) {
        if (bookmarks.isMovieBookmarked(item.id)) {
          await bookmarks.removeMovie(item.id);
        } else {
          await bookmarks.addMovie(item.movie ?? Movie(
            id: item.id,
            title: item.title,
            originalTitle: item.title,
            overview: item.overview,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            voteAverage: item.rating,
            releaseDate: item.releaseDate,
            genreIds: item.genreIds,
          ));
        }
      } else {
        if (bookmarks.isTVBookmarked(item.id)) {
          await bookmarks.removeTV(item.id);
        } else {
          await bookmarks.addTV(item.series ?? TV(
            id: item.id,
            name: item.title,
            originalName: item.title,
            overview: item.overview,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            voteAverage: item.rating,
            firstAirDate: item.releaseDate,
            genreIds: item.genreIds,
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update My List. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openTitle(MediaItem item) {
    final callback = widget.onOpenTitle;
    if (callback != null) {
      callback(context, item);
      return;
    }
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ExperienceTitleDetailsScreen(
        item: item,
        loadDetails: widget.loadDetails,
        onPlay: null,
        canPlay: false,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final bookmarks = context.watch<BookmarkProvider?>();
    final saved = _isSaved(bookmarks);
    final item = widget.item;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        foregroundColor: palette.foreground,
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Add to My List',
            onPressed: () => _toggleSaved(bookmarks),
            icon: Icon(saved ? Icons.bookmark_added_rounded :
              Icons.bookmark_add_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _hero(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ExperienceTokens.phoneGutter, 18,
                ExperienceTokens.phoneGutter, 0),
              child: _actions(context, bookmarks, saved),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: SizedBox(height: 120, child: ExperienceStatePanel(
                kind: ExperienceStateKind.loading,
                title: 'Loading title details', compact: true)),
            ),
          if (_failed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ExperienceTokens.phoneGutter, 14,
                  ExperienceTokens.phoneGutter, 0),
                child: ExperienceStatePanel(
                  kind: ExperienceStateKind.error,
                  title: 'Some details could not be loaded',
                  description: 'The title information is still available.',
                  actionLabel: 'Retry',
                  onAction: _load,
                  compact: true,
                ),
              ),
            ),
          SliverToBoxAdapter(child: _overview(context)),
          if (_details?.seasons.isNotEmpty ?? false)
            SliverToBoxAdapter(child: _seasons(context)),
          if (_details?.recommendations.isNotEmpty ?? false)
            SliverToBoxAdapter(child: _recommendations(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final item = widget.item;
    final path = item.backdropPath ?? item.posterPath;
    final image = path == null || path.isEmpty ? null :
      NetworkImage('https://image.tmdb.org/t/p/w1280' + path);
    final facts = _details?.facts ?? <String>[
      if (item.year != null) item.year!,
      if (item.rating != null && item.rating! > 0)
        '★ ' + item.rating!.toStringAsFixed(1),
    ];
    return SizedBox(
      height: 340,
      child: Stack(fit: StackFit.expand, children: [
        ExperienceArtwork(
          imageProvider: image,
          aspectRatio: 16 / 9,
          borderRadius: BorderRadius.zero,
          semanticLabel: item.title + ' backdrop',
        ),
        DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.page.withValues(alpha: .08),
              palette.page.withValues(alpha: .3),
              palette.page,
            ],
            stops: const [0, .54, 1],
          ),
        )),
        PositionedDirectional(
          start: ExperienceTokens.phoneGutter,
          end: ExperienceTokens.phoneGutter,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow(item.kind == MediaKind.movie ? 'MOVIE' : 'SERIES'),
              const SizedBox(height: 10),
              Text(item.title, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: palette.foreground, fontWeight: FontWeight.w900,
                  letterSpacing: -.8)),
              if (_details?.tagline?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 5),
                Text(_details!.tagline!,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.secondaryText, fontStyle: FontStyle.italic)),
              ],
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final fact in facts) _factPill(context, fact),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _actions(
    BuildContext context,
    BookmarkProvider? bookmarks,
    bool saved,
  ) {
    return Row(children: [
      if (widget.canPlay && widget.onPlay != null)
        Expanded(child: ExperienceAction(
          label: 'Play',
          leading: const Icon(Icons.play_arrow_rounded),
          onPressed: () => widget.onPlay!(context),
          expand: true,
        )),
      if (widget.canPlay && widget.onPlay != null)
        const SizedBox(width: 10),
      Expanded(child: ExperienceAction(
        label: _saving ? 'Saving…' : saved ? 'In My List' : 'Add to My List',
        tone: ExperienceActionTone.secondary,
        leading: Icon(saved ? Icons.bookmark_added_rounded :
          Icons.bookmark_add_outlined),
        isLoading: _saving,
        onPressed: bookmarks == null ? null : () => _toggleSaved(bookmarks),
        expand: true,
      )),
    ]);
  }

  Widget _overview(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final item = widget.item;
    final overview = item.overview.trim().isEmpty
        ? 'No synopsis is available for this title yet.'
        : item.overview.trim();
    final companies = _details?.movieDetails?.productionCompanies
        ?.map((entry) => entry.name)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList() ?? const <String>[];
    final networks = _details?.seriesDetails?.networks
        ?.map((entry) => entry.networkName)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList() ?? const <String>[];
    final languages = _details?.movieDetails?.spokenLanguages
        ?.map((entry) => entry.englishName)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList() ?? _details?.seriesDetails?.spokenLanguages
          ?.map((entry) => entry.englishName)
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toList() ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 26,
        ExperienceTokens.phoneGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.foreground, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Text(overview, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: palette.secondaryText, height: 1.55)),
          if (companies.isNotEmpty || networks.isNotEmpty ||
              languages.isNotEmpty || _details?.status != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (_details?.status case final status? when status.isNotEmpty)
              _metadataRow(context, 'Status', status),
            if (companies.isNotEmpty)
              _metadataRow(context, 'Studio', companies.take(3).join(', ')),
            if (networks.isNotEmpty)
              _metadataRow(context, 'Network', networks.take(3).join(', ')),
            if (languages.isNotEmpty)
              _metadataRow(context, 'Language', languages.take(4).join(', ')),
          ],
        ],
      ),
    );
  }

  Widget _seasons(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final seasons = _details!.seasons;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ExperienceTokens.phoneGutter),
            child: Text('Seasons', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: palette.foreground, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceTokens.phoneGutter),
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final season = seasons[index];
                final path = season.posterPath;
                final image = path == null || path.isEmpty ? null :
                  NetworkImage('https://image.tmdb.org/t/p/w185' + path);
                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 62,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ExperienceArtwork(
                          imageProvider: image,
                          aspectRatio: 2 / 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(season.name ?? 'Season',
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.foreground,
                            fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text((season.episodeCount ?? 0).toString() + ' episodes',
                          style: TextStyle(color: palette.mutedText, fontSize: 12)),
                        if (season.airDate != null)
                          Text(season.airDate!,
                            style: TextStyle(color: palette.mutedText, fontSize: 11)),
                      ],
                    )),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendations(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final items = _details!.recommendations;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ExperienceTokens.phoneGutter),
            child: Text('You may also like',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.foreground, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 224,
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
                  width: 128,
                  child: InkWell(
                    onTap: () => _openTitle(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: ExperienceArtwork(
                          imageProvider: image, aspectRatio: 2 / 3,
                          semanticLabel: item.title + ' poster')),
                        const SizedBox(height: 7),
                        Text(item.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: palette.foreground,
                            fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataRow(BuildContext context, String label, String value) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(label,
          style: TextStyle(color: palette.mutedText, fontSize: 12))),
        Expanded(child: Text(value,
          style: TextStyle(color: palette.secondaryText, fontSize: 12))),
      ]),
    );
  }

  Widget _factPill(BuildContext context, String label) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(label, style: TextStyle(
          color: palette.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _eyebrow(String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ),
    );
  }
}
