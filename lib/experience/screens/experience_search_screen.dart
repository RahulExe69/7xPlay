import '../../catalog/media_search.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_controller.dart';
import '../../catalog/media_item.dart';
import '../../models/person.dart';
import '../../mobile/app/mobile_tabs.dart';
import '../../mobile/playback.dart';
import '../../preferences/setting_preferences.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/person/searchedperson.dart';
import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import '../widgets/experience_artwork.dart';
import '../widgets/experience_state_panel.dart';

enum ExperienceSearchFilter { all, movies, series, people }

/// A redesigned search surface that keeps the original catalogue pipeline,
/// parallel movie/series/people lookup, debouncing and recent-query storage.
class ExperienceSearchScreen extends StatefulWidget {
  const ExperienceSearchScreen({
    this.source,
    this.loadSuggestions,
    this.preferences,
    this.openTitle,
    super.key,
  });

  final SearchSource? source;
  final Future<SearchSuggestions> Function()? loadSuggestions;
  final SettingsPreferences? preferences;
  final void Function(BuildContext context, MediaItem item)? openTitle;

  @override
  State<ExperienceSearchScreen> createState() => _ExperienceSearchScreenState();
}

class _ExperienceSearchScreenState extends State<ExperienceSearchScreen> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: '7xPlay search');
  late final SettingsPreferences _preferences =
      widget.preferences ?? SettingsPreferences();
  Timer? _debounce;
  MobileTabController? _tabs;
  MobileTab? _lastTab;
  Future<SearchSuggestions>? _suggestions;
  SearchResults? _results;
  List<String> _recents = const [];
  ExperienceSearchFilter _filter = ExperienceSearchFilter.all;
  int _generation = 0;
  bool _searching = false;

  String get _text => _query.text.trim();
  bool get _typed => MediaSearch.searchable(_text);

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecents());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      _tabs
        ?..removeListener(_onTab)
        ..removeResetListener(MobileTab.search, _reset);
      _tabs = tabs
        ?..addListener(_onTab)
        ..addResetListener(MobileTab.search, _reset);
      _lastTab = tabs?.current;
    }
    _suggestions ??= widget.loadSuggestions?.call() ??
        const CatalogController().loadSearchSuggestions(
          settings: context.read<SettingsProvider>(),
          dependencies: context.read<AppDependencyProvider>(),
        );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs
      ?..removeListener(_onTab)
      ..removeResetListener(MobileTab.search, _reset);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTab() {
    final current = _tabs?.current;
    if (current == MobileTab.search && _lastTab != MobileTab.search) {
      _focus.requestFocus();
    } else if (current != MobileTab.search) {
      _focus.unfocus();
    }
    _lastTab = current;
  }

  Future<void> _loadRecents() async {
    final values = await _preferences.getRecentSearches();
    if (mounted) setState(() => _recents = values);
  }

  Future<void> _remember(String query) async {
    if (!MediaSearch.searchable(query)) return;
    await _preferences.addRecentSearch(query.trim());
    await _loadRecents();
  }

  Future<void> _forget(String query) async {
    await _preferences.removeRecentSearch(query);
    await _loadRecents();
  }

  Future<void> _clearRecents() async {
    await _preferences.clearRecentSearches();
    await _loadRecents();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (!MediaSearch.searchable(query)) {
      _generation++;
      setState(() {
        _searching = false;
        if (query.isEmpty) _results = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(MediaSearch.debounce, () => _search(query));
  }

  void _submitted(String value) {
    final query = value.trim();
    if (!MediaSearch.searchable(query)) return;
    unawaited(_remember(query));
    _debounce?.cancel();
    unawaited(_search(query));
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    setState(() => _searching = true);
    final source = widget.source ?? TmdbSearchSource(
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    );
    final results = await MediaSearch.run(source, query);
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _fill(String query) {
    _query.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focus.requestFocus();
    _changed(query);
  }

  void _reset() {
    _debounce?.cancel();
    _generation++;
    _query.clear();
    _focus.unfocus();
    setState(() {
      _results = null;
      _searching = false;
      _filter = ExperienceSearchFilter.all;
    });
  }

  void _openTitle(MediaItem item) {
    unawaited(_remember(_text));
    (widget.openTitle ?? MobilePlayback.openDetails)(context, item);
  }

  void _openPerson(Person person) {
    unawaited(_remember(_text));
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => SearchedPersonDetailPage(
        person: person,
        heroId: 'experience-search-person-' + person.id.toString(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final results = _results;
    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _tabs?.scrollController(MobileTab.search),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _searchField(context)),
            if (!_typed)
              SliverToBoxAdapter(child: _suggestionContent(context))
            else if (results == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ExperienceStatePanel(
                  kind: ExperienceStateKind.loading,
                  title: _searching ? 'Searching the catalogue' : 'Search',
                  description: 'Movies, series and people',
                ),
              )
            else if (results.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ExperienceStatePanel(
                  kind: ExperienceStateKind.empty,
                  title: 'No matches found',
                  description: 'Try another title, person or keyword.',
                ),
              )
            else
              SliverToBoxAdapter(child: _resultsPanel(context, results)),
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
        ExperienceTokens.phoneGutter, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FIND YOUR NEXT STORY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.primaryAction, fontWeight: FontWeight.w900,
              letterSpacing: 1.6)),
          const SizedBox(height: 5),
          Text('Search',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: palette.foreground, fontWeight: FontWeight.w900,
              letterSpacing: -.8)),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 0,
        ExperienceTokens.phoneGutter, 12),
      child: Material(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(18),
        child: TextField(
          controller: _query,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          onSubmitted: _submitted,
          style: TextStyle(color: palette.foreground),
          decoration: InputDecoration(
            hintText: 'Movies, series, actors…',
            hintStyle: TextStyle(color: palette.mutedText),
            prefixIcon: Icon(Icons.search_rounded, color: palette.primaryAction),
            suffixIcon: _query.text.isEmpty ? null : IconButton(
              tooltip: 'Clear search',
              onPressed: _reset,
              icon: const Icon(Icons.close_rounded)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: palette.hairline)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: palette.hairline)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: palette.primaryAction, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _suggestionContent(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return FutureBuilder<SearchSuggestions>(
      future: _suggestions,
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? SearchSuggestions.empty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recents.isNotEmpty) ...[
              _sectionHeader(context, 'Recent searches',
                action: TextButton(
                  onPressed: _clearRecents,
                  child: Text('Clear all',
                    style: TextStyle(color: palette.secondaryText)))),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceTokens.phoneGutter),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    for (final query in _recents)
                      InputChip(
                        label: Text(query),
                        onPressed: () => _fill(query),
                        onDeleted: () => _forget(query),
                        backgroundColor: palette.surface,
                        side: BorderSide(color: palette.hairline),
                        labelStyle: TextStyle(color: palette.foreground),
                      ),
                  ],
                ),
              ),
            ],
            _sectionHeader(context, 'Popular right now'),
            if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(height: 120, child: Center(
                child: CircularProgressIndicator()))
            else
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceTokens.phoneGutter),
                  itemCount: suggestions.topSearches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = suggestions.topSearches[index];
                    final path = item.posterPath;
                    final image = path == null || path.isEmpty ? null :
                        NetworkImage('https://image.tmdb.org/t/p/w342' + path);
                    return SizedBox(
                      width: 120,
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
            if (suggestions.movieGenres.isNotEmpty ||
                suggestions.seriesGenres.isNotEmpty) ...[
              _sectionHeader(context, 'Browse by genre',
                action: TextButton(
                  onPressed: () => _tabs?.select(MobileTab.discover),
                  child: Text('See all',
                    style: TextStyle(color: palette.primaryAction)))),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceTokens.phoneGutter),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    for (final genre in [
                      ...suggestions.movieGenres.take(8),
                      ...suggestions.seriesGenres.take(4),
                    ])
                      ActionChip(
                        label: Text(genre.genreName ?? ''),
                        onPressed: () => _fill(genre.genreName ?? ''),
                        backgroundColor: palette.surface,
                        side: BorderSide(color: palette.hairline),
                        labelStyle: TextStyle(color: palette.foreground),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _resultsPanel(BuildContext context, SearchResults results) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final titleItems = switch (_filter) {
      ExperienceSearchFilter.all => [...results.movies, ...results.series],
      ExperienceSearchFilter.movies => results.movies,
      ExperienceSearchFilter.series => results.series,
      ExperienceSearchFilter.people => const <MediaItem>[],
    };
    final counts = {
      ExperienceSearchFilter.all: results.movies.length + results.series.length,
      ExperienceSearchFilter.movies: results.movies.length,
      ExperienceSearchFilter.series: results.series.length,
      ExperienceSearchFilter.people: results.people.length,
    };
    const labels = {
      ExperienceSearchFilter.all: 'Titles',
      ExperienceSearchFilter.movies: 'Movies',
      ExperienceSearchFilter.series: 'Series',
      ExperienceSearchFilter.people: 'People',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ExperienceTokens.phoneGutter),
            itemCount: ExperienceSearchFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = ExperienceSearchFilter.values[index];
              final selected = filter == _filter;
              return ChoiceChip(
                label: Text(labels[filter]! + ' ' + counts[filter]!.toString()),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = filter),
                backgroundColor: palette.surface,
                selectedColor: palette.primaryAction,
                side: BorderSide(
                  color: selected ? palette.primaryAction : palette.hairline),
                labelStyle: TextStyle(
                  color: selected ? palette.onPrimaryAction : palette.secondaryText,
                  fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
        if (_filter == ExperienceSearchFilter.people)
          _people(context, results.people)
        else ...[
          if (_filter == ExperienceSearchFilter.all && results.topResult != null)
            _topResult(context, results.topResult!),
          if (titleItems.isEmpty)
            const ExperienceStatePanel(
              kind: ExperienceStateKind.empty,
              title: 'No titles in this category')
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceTokens.phoneGutter),
              child: Column(
                children: [
                  for (final item in titleItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _resultTile(context, item)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _topResult(BuildContext context, MediaItem item) {
    final path = item.backdropPath ?? item.posterPath;
    final image = path == null || path.isEmpty ? null :
        NetworkImage('https://image.tmdb.org/t/p/w780' + path);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 14,
        ExperienceTokens.phoneGutter, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ExperienceTokens.heroRadius),
        child: SizedBox(
          height: 244,
          child: Stack(fit: StackFit.expand, children: [
            ExperienceArtwork(imageProvider: image, aspectRatio: 16 / 9,
              borderRadius: BorderRadius.zero),
            DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: .93)]))),
            PositionedDirectional(
              start: 16, end: 16, bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BEST MATCH', style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w900,
                    letterSpacing: 1.2)),
                  const SizedBox(height: 5),
                  Text(item.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _openTitle(item),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('View details')),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _people(BuildContext context, List<Person> people) {
    final palette = ExperienceThemeExtension.of(context).palette;
    if (people.isEmpty) {
      return const ExperienceStatePanel(
        kind: ExperienceStateKind.empty, title: 'No people found');
    }
    return Column(children: [
      for (final person in people)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ExperienceTokens.phoneGutter, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: palette.raisedSurface,
            backgroundImage: person.profilePath == null ? null :
              NetworkImage('https://image.tmdb.org/t/p/w185' + person.profilePath!),
            child: person.profilePath == null
                ? Icon(Icons.person_outline, color: palette.mutedText) : null),
          title: Text(person.name ?? 'Unknown',
            style: TextStyle(color: palette.foreground,
              fontWeight: FontWeight.w700)),
          subtitle: Text(person.department ?? 'Person',
            style: TextStyle(color: palette.secondaryText)),
          trailing: Icon(Icons.chevron_right_rounded, color: palette.mutedText),
          onTap: () => _openPerson(person),
        ),
    ]);
  }

  Widget _resultTile(BuildContext context, MediaItem item) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final path = item.posterPath;
    final image = path == null || path.isEmpty ? null :
        NetworkImage('https://image.tmdb.org/t/p/w342' + path);
    return InkWell(
      onTap: () => _openTitle(item),
      borderRadius: BorderRadius.circular(ExperienceTokens.cardRadius),
      child: SizedBox(
        height: 112,
        child: Row(children: [
          SizedBox(width: 76, child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(aspectRatio: 2 / 3,
              child: ExperienceArtwork(imageProvider: image,
                aspectRatio: 2 / 3, borderRadius: BorderRadius.zero)))),
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
              ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.secondaryText)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: palette.mutedText),
        ]),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, {Widget? action}) {
    final palette = ExperienceThemeExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceTokens.phoneGutter, 24,
        ExperienceTokens.phoneGutter, 12),
      child: Row(children: [
        Expanded(child: Text(title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.foreground, fontWeight: FontWeight.w900))),
        if (action != null) action,
      ]),
    );
  }
}
