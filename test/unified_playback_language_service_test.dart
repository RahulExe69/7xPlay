import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/video_providers/common.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flixquest/video_providers/provider_loader.dart';
import 'package:flixquest/services/unified_playback_language_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  final providers = [
    VideoProvider.scraper(id: 'one', name: 'Provider One'),
    VideoProvider.scraper(id: 'two', name: 'Provider Two'),
    VideoProvider.scraper(id: 'unknown', name: 'Provider Unknown'),
  ];

  ProviderAttempt attempt(int index) => ProviderAttempt(
        index: index,
        provider: providers[index],
        result: ProviderLoadResult(
          success: true,
          videoLinks: [
            RegularVideoLinks(
              url: 'https://example.com/$index.m3u8',
              isM3U8: true,
            ),
          ],
        ),
      );

  test('groups duplicate language reports and retains all compatible providers',
      () {
    final attempts = [attempt(0), attempt(1), attempt(2)];
    final discovery =
        UnifiedPlaybackLanguageService.fromDetectedLanguages(
      attempts: attempts,
      detectedByProvider: {
        providers[0].codeName: {'en'},
        providers[1].codeName: {'eng', 'hi', 'bn'},
      },
      unknownProviderCodes: {providers[2].codeName},
    );

    expect(
      discovery.options.map((option) => option.code),
      containsAll(['en', 'hi', 'bn', 'und']),
    );
    expect(
      discovery.providerCodesFor('en'),
      [providers[0].codeName, providers[1].codeName],
    );
    expect(
      discovery.providerCodesFor('und'),
      [providers[2].codeName],
    );
    expect(
      discovery.options.where((option) => option.code == 'en').single.label,
      'english',
    );
    expect(
      discovery.options.where((option) => option.code == 'bn').single.label,
      'bengali',
    );
  });

  test('filters provider stream URLs by the selected audio language',
      () async {
    final provider = providers[0];
    final sourceAttempt = ProviderAttempt(
      index: 0,
      provider: provider,
      result: ProviderLoadResult(
        success: true,
        videoLinks: [
          RegularVideoLinks(
            url: 'https://example.com/english.m3u8',
            isM3U8: true,
            audioLanguage: 'en',
          ),
          RegularVideoLinks(
            url: 'https://example.com/hindi.m3u8',
            isM3U8: true,
            audioLanguage: 'hi',
          ),
        ],
      ),
    );

    final discovery =
        await UnifiedPlaybackLanguageService.discover([sourceAttempt]);
    final filtered =
        UnifiedPlaybackLanguageService.filterAttemptsForLanguage(
      attempts: [sourceAttempt],
      discovery: discovery,
      languageCode: 'en',
    );

    expect(discovery.providerCodesFor('en'), [provider.codeName]);
    expect(
      filtered.single.result.videoLinks!.map((link) => link.url),
      ['https://example.com/english.m3u8'],
    );
  });

  test('offers original unverified audio when no language is detectable', () {
    final discovery =
        UnifiedPlaybackLanguageService.fromDetectedLanguages(
      attempts: [attempt(0)],
      detectedByProvider: const {},
      unknownProviderCodes: {providers[0].codeName},
    );

    expect(discovery.options.single.code, 'und');
    expect(discovery.providerCodesFor('und'), [providers[0].codeName]);
  });

  test('progressive extensions override incorrect HLS and DASH flags', () {
    expect(
      UnifiedPlaybackLanguageService.manifestFormatForLink(
        RegularVideoLinks(
          url: 'https://example.com/movie.mp4?token=abc',
          isM3U8: true,
        ),
      ),
      isNull,
    );
    expect(
      UnifiedPlaybackLanguageService.manifestFormatForLink(
        RegularVideoLinks(
          url: 'https://example.com/movie.webm',
          isDash: true,
        ),
      ),
      isNull,
    );
    expect(
      UnifiedPlaybackLanguageService.manifestFormatForLink(
        RegularVideoLinks(url: 'https://example.com/master.m3u8?token=abc'),
      ),
      'hls',
    );
    expect(
      UnifiedPlaybackLanguageService.manifestFormatForLink(
        RegularVideoLinks(url: 'https://example.com/manifest.mpd'),
      ),
      'dash',
    );
  });

  test('keeps unverified progressive links separate from verified links', () async {
    final provider = providers[0];
    final sourceAttempt = ProviderAttempt(
      index: 0,
      provider: provider,
      result: ProviderLoadResult(
        success: true,
        videoLinks: [
          RegularVideoLinks(
            url: 'https://example.com/verified-english.m3u8',
            isM3U8: true,
            audioLanguage: 'en',
          ),
          RegularVideoLinks(
            url: 'https://example.com/original-audio.mp4',
            isM3U8: false,
            audioLanguage: null,
          ),
        ],
      ),
    );

    final discovery =
        await UnifiedPlaybackLanguageService.discover([sourceAttempt]);

    expect(
      discovery.options.map((option) => option.code),
      containsAll(['en', 'und']),
    );
    expect(discovery.providerCodesFor('und'), [provider.codeName]);

    final filtered =
        UnifiedPlaybackLanguageService.filterAttemptsForLanguage(
      attempts: [sourceAttempt],
      discovery: discovery,
      languageCode: 'und',
    );
    expect(
      filtered.single.result.videoLinks!.map((link) => link.url),
      ['https://example.com/original-audio.mp4'],
    );
  });

  test('selected language requires an explicitly eligible provider', () {
    expect(
      UnifiedPlaybackLanguageService.allowsProviderForSelectedLanguage(
        selectedLanguageCode: 'hi',
        eligibleProviderCodes: const [],
        providerCode: providers[1].codeName,
      ),
      isFalse,
    );
    expect(
      UnifiedPlaybackLanguageService.allowsProviderForSelectedLanguage(
        selectedLanguageCode: 'hi',
        eligibleProviderCodes: [providers[1].codeName],
        providerCode: providers[1].codeName,
      ),
      isTrue,
    );
    expect(
      UnifiedPlaybackLanguageService.allowsProviderForSelectedLanguage(
        selectedLanguageCode: null,
        eligibleProviderCodes: const [],
        providerCode: providers[1].codeName,
      ),
      isTrue,
    );
  });

  test('does not expose a failed provider as a language candidate', () {
    final failed = ProviderAttempt(
      index: 1,
      provider: providers[1],
      result: const ProviderLoadResult(errorMessage: 'Offline'),
    );
    final discovery =
        UnifiedPlaybackLanguageService.fromDetectedLanguages(
      attempts: [attempt(0), failed],
      detectedByProvider: {providers[0].codeName: {'en'}},
    );

    expect(discovery.providerCodesFor('en'), [providers[0].codeName]);
    expect(discovery.providerCodesFor('und'), isEmpty);
  });
}
