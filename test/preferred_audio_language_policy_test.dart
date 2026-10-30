import 'package:flixquest/functions/preferred_audio_language_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreferredAudioLanguagePolicy', () {
    test('prefers the title original language over available dubs', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['English', 'Hindi', 'Urdu'],
          originalLanguage: 'en',
        ),
        'en',
      );
    });

    test('uses Hindi when the original-language track is unavailable', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['Hindi', 'English'],
          originalLanguage: 'ja',
        ),
        'hi',
      );
    });

    test('uses Urdu when Hindi is absent and Urdu is available', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['English', 'Urdu'],
          originalLanguage: 'en',
        ),
        'ur',
      );
    });

    test('keeps a Hindi original ahead of another dub', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['Hindi', 'Urdu', 'English'],
          originalLanguage: 'hi',
        ),
        'hi',
      );
    });

    test('keeps an Urdu original ahead of another dub', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['Hindi', 'Urdu'],
          originalLanguage: 'ur',
        ),
        'ur',
      );
    });

    test('falls back to another available preferred dub when the original is absent', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['English', 'Urdu'],
          originalLanguage: 'hi',
        ),
        'ur',
      );
    });

    test('uses the title original language before English', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['English', 'Japanese'],
          originalLanguage: 'ja',
        ),
        'ja',
      );
    });

    test('uses English when it is original and no Hindi or Urdu dub exists', () {
      expect(
        PreferredAudioLanguagePolicy.select(
          availableLanguageLabels: ['English'],
          originalLanguage: 'en',
        ),
        'en',
      );
    });

    test('does not invent a language when metadata is missing', () {
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
