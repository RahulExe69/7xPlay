import 'language_names.dart';

/// Chooses a sensible default audio track without assuming every title is
/// English. Prefer the title's TMDB original language whenever the source
/// exposes it. Hindi/Urdu are fallback preferences when that original is absent.
abstract final class PreferredAudioLanguagePolicy {
  static const List<String> _preferredDubOrder = <String>['hi', 'ur'];

  static String? select({
    required Iterable<String> availableLanguageLabels,
    String? originalLanguage,
  }) {
    final available = <String>{
      for (final label in availableLanguageLabels)
        if (languageCodeForLabel(label) case final code?) code,
    };
    if (available.isEmpty) return null;

    final original = languageCodeForLabel(originalLanguage);
    if (original != null && available.contains(original)) return original;

    for (final preferred in _preferredDubOrder) {
      if (available.contains(preferred)) return preferred;
    }

    if (original != null && available.contains(original)) return original;
    if (available.contains('en')) return 'en';

    // When metadata is incomplete, use a stable available language rather
    // than silently forcing English.
    for (final language in appLanguages) {
      if (available.contains(language.code)) return language.code;
    }
    return available.first;
  }
}
