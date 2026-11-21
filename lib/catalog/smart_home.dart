import 'media_item.dart';

/// Small, deterministic helpers for making the existing Home catalogue feel
/// personal without a hosted recommendation service or another API request.
abstract final class SmartHome {
  /// Ranks already-loaded catalogue items by the genres present in [saved].
  ///
  /// Genre affinity is isolated by media kind. Popularity and rating only
  /// break ties between candidates with equal genre overlap. Titles already
  /// saved or currently being watched are never recommended again.
  static List<MediaItem> personalized({
    required Iterable<MediaItem> candidates,
    required Iterable<MediaItem> saved,
    Iterable<MediaItem> continueWatching = const <MediaItem>[],
    int limit = 12,
  }) {
    if (limit <= 0) return const <MediaItem>[];

    final genreWeights = <(MediaKind, int), int>{};
    final excluded = <String>{};
    final seenSaved = <String>{};
    for (final item in saved) {
      if (item.id < 0) continue;
      excluded.add(_titleKey(item));
      if (!seenSaved.add(_titleKey(item))) continue;
      for (final genreId in item.genreIds.toSet()) {
        if (genreId <= 0) continue;
        final key = (item.kind, genreId);
        genreWeights[key] = (genreWeights[key] ?? 0) + 1;
      }
    }
    for (final item in continueWatching) {
      if (item.id >= 0) excluded.add(_titleKey(item));
    }
    if (genreWeights.isEmpty) return const <MediaItem>[];

    final ranked = <({MediaItem item, int score})>[];
    final seen = <String>{};
    for (final item in candidates) {
      if (item.id < 0) continue;
      final key = _titleKey(item);
      if (excluded.contains(key) || !seen.add(key)) continue;
      var score = 0;
      for (final genreId in item.genreIds.toSet()) {
        score += genreWeights[(item.kind, genreId)] ?? 0;
      }
      if (score > 0) ranked.add((item: item, score: score));
    }

    ranked.sort((a, b) {
      final byGenre = b.score.compareTo(a.score);
      if (byGenre != 0) return byGenre;
      final byPopularity =
          (b.item.popularity ?? 0).compareTo(a.item.popularity ?? 0);
      if (byPopularity != 0) return byPopularity;
      final byRating = (b.item.rating ?? 0).compareTo(a.item.rating ?? 0);
      if (byRating != 0) return byRating;
      return a.item.title.toLowerCase().compareTo(
            b.item.title.toLowerCase(),
          );
    });

    return ranked
        .take(limit)
        .map((entry) => entry.item)
        .toList(growable: false);
  }

  /// Returns only saved titles currently present in [current] or [upcoming].
  ///
  /// Current/on-air titles come first, followed by upcoming titles. A title
  /// appearing in both lists is included once.
  static List<MediaItem> watchlistUpdates({
    required Iterable<MediaItem> saved,
    required Iterable<MediaItem> current,
    required Iterable<MediaItem> upcoming,
    int limit = 12,
  }) {
    if (limit <= 0) return const <MediaItem>[];
    final savedKeys = saved
        .where((item) => item.id >= 0)
        .map(_titleKey)
        .toSet();
    if (savedKeys.isEmpty) return const <MediaItem>[];

    final seen = <String>{};
    final updates = <MediaItem>[];
    for (final item in <MediaItem>[...current, ...upcoming]) {
      if (item.id < 0) continue;
      final key = _titleKey(item);
      if (savedKeys.contains(key) && seen.add(key)) {
        updates.add(item);
        if (updates.length >= limit) break;
      }
    }
    return updates.toList(growable: false);
  }

  static String _titleKey(MediaItem item) => '${item.kind.name}:${item.id}';
}
