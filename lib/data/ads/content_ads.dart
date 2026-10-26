import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/endpoints.dart';
import '../../catalog/media_item.dart';
import '../../functions/network.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';

/// The TMDB genres FlixQuest never shows ads around, with or without Plus:
/// Family, for movies and series, and Kids, which only series have.
abstract final class FamilyGenres {
  static const family = 10751;
  static const kids = 10762;

  /// Whether a title of these genres is ad-free. One qualifying genre is
  /// enough, whatever else the title is.
  static bool includes({
    required bool series,
    required Iterable<int> genreIds,
  }) =>
      genreIds.contains(family) || (series && genreIds.contains(kids));
}

/// A title as the ad rules see it: its kind, TMDB id and, when the list it
/// came from carried them, its genre ids.
class AdContent {
  const AdContent({required this.series, required this.id, this.genreIds});

  factory AdContent.of(MediaItem item) => AdContent(
        series: item.kind == MediaKind.series,
        id: item.id,
        genreIds: item.genreIds,
      );

  final bool series;
  final int id;
  final List<int>? genreIds;

  /// Ad-free or not from the genre ids alone; null when they are missing,
  /// as on bookmarks saved before genres were kept.
  bool? get knownAdFree {
    final ids = genreIds;
    if (ids == null || ids.isEmpty) return null;
    return FamilyGenres.includes(series: series, genreIds: ids);
  }

  (bool, int) get _key => (series, id);
}

/// Whether titles are ad-free, from their genre ids or else TMDB's details.
/// Answers are kept for the session, so every screen of one title asks once.
abstract final class ContentAds {
  static final Map<(bool, int), bool> _known = {};
  static final Map<(bool, int), Future<bool>> _pending = {};

  /// Reads [content]'s genre ids from TMDB; null when they can't be read.
  /// Replaced by tests.
  static Future<List<int>?> Function(BuildContext context, AdContent content)
      lookup = _lookup;

  /// The answer for [content] without waiting, or null until it is known.
  static bool? known(AdContent content) =>
      content.knownAdFree ?? _known[content._key];

  /// Whether [content] plays without ads. A title whose genres can't be read
  /// is treated as ad-free for now, and asked about again next time.
  static Future<bool> resolve(BuildContext context, AdContent content) {
    final known = ContentAds.known(content);
    if (known != null) return Future.value(known);
    final key = content._key;
    return _pending[key] ??= () async {
      try {
        final ids = await lookup(context, content);
        if (ids == null) return true;
        return _known[key] =
            FamilyGenres.includes(series: content.series, genreIds: ids);
      } catch (error) {
        debugPrint('[ContentAds] genres unavailable for '
            '${content.series ? 'tv' : 'movie'} ${content.id}: $error');
        return true;
      } finally {
        _pending.remove(key);
      }
    }();
  }

  static Future<List<int>?> _lookup(
      BuildContext context, AdContent content) async {
    final settings = context.read<SettingsProvider?>();
    final dependencies = context.read<AppDependencyProvider?>();
    if (settings == null || dependencies == null) return null;
    // The details page asks for the same URL, so this is usually cached.
    final genres = await fetchGenre(
      content.series
          ? Endpoints.tvDetailsUrl(content.id, settings.appLanguage)
          : Endpoints.movieDetailsUrl(content.id, settings.appLanguage),
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
    return genres.map((genre) => genre.genreID).whereType<int>().toList();
  }

  @visibleForTesting
  static void reset() {
    _known.clear();
    _pending.clear();
    lookup = _lookup;
  }
}

/// Marks a subtree as an ad-free title's screens: its details, seasons and
/// episodes, a Kids or Family genre page, its loader and its player. Every
/// ad surface reads it through `AdsPolicy.adFreeAt`, so nothing is
/// requested there. It says nothing about Plus.
///
/// A pushed route is the navigator's child, not the pusher's, so it does
/// not inherit this; [carry] takes it along.
class ContentAdScope extends InheritedWidget {
  const ContentAdScope({required this.adFree, required super.child, super.key});

  final bool adFree;

  /// Whether [context] is inside an ad-free title's screens. [listen]
  /// rebuilds the caller when that changes, as when genres arrive.
  static bool adFreeAt(BuildContext context, {bool listen = false}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<ContentAdScope>()
        : context.getInheritedWidgetOfExactType<ContentAdScope>();
    return scope?.adFree ?? false;
  }

  /// Wraps a route pushed from [from] in the scope [from] is in. Read now,
  /// so it works after [from] has gone.
  static Widget Function(Widget child) carry(BuildContext from) {
    final adFree = from.getInheritedWidgetOfExactType<ContentAdScope>()?.adFree;
    return (child) =>
        adFree == null ? child : ContentAdScope(adFree: adFree, child: child);
  }

  @override
  bool updateShouldNotify(ContentAdScope oldWidget) =>
      adFree != oldWidget.adFree;
}

/// [child] as [content]'s screen in a [ContentAdScope]. Until its genres
/// are known, its ads are held. [holdChild] also keeps [child] unbuilt till
/// then, for a loader whose first frame already asks for ads.
class ContentAdGate extends StatefulWidget {
  const ContentAdGate({
    required this.content,
    required this.child,
    this.holdChild = false,
    super.key,
  });

  final AdContent content;
  final Widget child;
  final bool holdChild;

  @override
  State<ContentAdGate> createState() => _ContentAdGateState();
}

class _ContentAdGateState extends State<ContentAdGate> {
  bool? _adFree;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    _adFree = ContentAds.known(widget.content);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ContentAdGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content._key == oldWidget.content._key) return;
    _adFree = ContentAds.known(widget.content);
    _asked = false;
    _resolve();
  }

  void _resolve() {
    if (_adFree != null || _asked) return;
    _asked = true;
    final content = widget.content;
    ContentAds.resolve(context, content).then((adFree) {
      if (!mounted || widget.content._key != content._key) return;
      setState(() => _adFree = adFree);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adFree = _adFree;
    if (adFree == null && widget.holdChild) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return ContentAdScope(adFree: adFree ?? true, child: widget.child);
  }
}
