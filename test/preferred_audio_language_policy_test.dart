import 'package:flixquest/functions/preferred_audio_language_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreferredAudioLanguagePolicy', () {
    test('rejects a Hindi source label when native tracks are English only', () {
      expect(
        PreferredAudioLanguagePolicy.nativeTracksAllowSourceLabel(
          requestedLanguageCode: 'hi',
          nativeTrackLabels: ['English', 'en'],
        ),
        isFalse,
      );
    });

    test('accepts a source label when native tracks confirm Hindi', () {
      expect(
        PreferredAudioLanguagePolicy.nativeTracksAllowSourceLabel(
          requestedLanguageCode: 'hi',
          nativeTrackLabels: ['English', 'Hindi'],
        ),
        isTrue,
      );
    });

    test('allows source metadata when native track languages are unavailable', () {
      expect(
        PreferredAudioLanguagePolicy.nativeTracksAllowSourceLabel(
          requestedLanguageCode: 'hi',
          nativeTrackLabels: ['Audio track 1', 'Unknown'],
        ),
        isTrue,
      );
    });

    test('allows explicit language metadata when a source has no track list', () {
      expect(
        PreferredAudioLanguagePolicy.nativeTracksAllowSourceLabel(
          requestedLanguageCode: 'hi',
          nativeTrackLabels: const [],
        ),
        isTrue,
      );
    });
    test('prefers Hindi before English and the title original language', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['English', 'Japanese', 'Hindi'],
          originalLanguage: 'ja',
        ),
        'hi',
      );
    });

    test('prefers English when Hindi is unavailable, before original audio', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['Japanese', 'English'],
          originalLanguage: 'ja',
        ),
        'en',
      );
    });

    test('uses the original language after Hindi and English are unavailable', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['Japanese', 'Bengali'],
          originalLanguage: 'ja',
        ),
        'ja',
      );
    });

    test('uses a stable available language when original is absent', () {
      final ordered = PreferredAudioLanguagePolicy.orderAvailable(
        availableLanguageLabels: ['Bengali', 'Japanese'],
      );
      expect(ordered.toSet(), {'bn', 'ja'});
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['Bengali', 'Japanese'],
        ),
        ordered.first,
      );
    });

    test('orders the audio picker Hindi, English, original, then other options', () {
      expect(
        PreferredAudioLanguagePolicy.orderAvailable(
          availableLanguageLabels: [
            'Japanese',
            'Bengali',
            'English',
            'Hindi',
            'Urdu',
          ],
          originalLanguage: 'ja',
        ).take(4),
        ['hi', 'en', 'ja', 'bn'],
      );
    });

    test('does not invent a language when no labels are available', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: const [],
          originalLanguage: 'en',
        ),
        isNull,
      );
    });
  });
}
