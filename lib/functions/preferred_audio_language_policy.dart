import 'language_names.dart';

/// Selects a predictable default audio language for 7xPlay.
///
/// The app prefers Hindi first, then English, then the title's original
/// language, followed by other known languages. This is an audio preference,
/// not a statement about the movie's country or original language.
abstract final class PreferredAudioLanguagePolicy {
  /// Whether source metadata can be trusted for [requestedLanguageCode].
  ///
  /// A manifest with recognised native languages is authoritative. If it
  /// exposes only English, a provider's stale "Hindi" label must not make the
  /// source eligible as Hindi. Empty/unrecognised track metadata leaves the
  /// provider label as the only available evidence (e.g. progressive files).
  static bool nativeTracksAllowSourceLabel({
    required String requestedLanguageCode,
    required Iterable<String> nativeTrackLabels,
  }) {
    final nativeCodes = <String>{
      for (final label in nativeTrackLabels)
        if (languageCodeForLabel(label) case final code?) code,
    };
    return nativeCodes.isEmpty || nativeCodes.contains(requestedLanguageCode);
  }
  static List<String> orderAvailable({
    required Iterable<String> availableLanguageLabels,
    String? originalLanguage,
  }) {
    final available = <String>{
      for (final label in availableLanguageLabels)
        if (languageCodeForLabel(label) case final code?) code,
    };
    if (available.isEmpty) return const <String>[];

    final ordered = <String>[];

    void addIfAvailable(String? code) {
      if (code != null && available.contains(code) && !ordered.contains(code)) {
        ordered.add(code);
      }
    }

    addIfAvailable('hi');
    addIfAvailable('en');
    addIfAvailable(languageCodeForLabel(originalLanguage));

    // Keep the remaining choices deterministic and familiar.
    for (final language in appLanguages) {
      addIfAvailable(language.code);
    }
    for (final code in available.toList()..sort()) {
      addIfAvailable(code);
    }
    return List<String>.unmodifiable(ordered);
  }

  static String? select({
    required Iterable<String> availableLanguageLabels,
    String? originalLanguage,
  }) {
    final ordered = orderAvailable(
      availableLanguageLabels: availableLanguageLabels,
      originalLanguage: originalLanguage,
    );
    return ordered.isEmpty ? null : ordered.first;
  }
}
