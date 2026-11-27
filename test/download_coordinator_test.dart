import 'dart:async';

import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/services/download_coordinator.dart';
import 'package:flixquest/services/unified_playback_language_service.dart';
import 'package:flixquest/video_providers/common.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flixquest/video_providers/provider_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final alpha = VideoProvider.scraper(id: 'alpha', name: 'Provider Alpha');
  final beta = VideoProvider.scraper(id: 'beta', name: 'Provider Beta');

  ProviderAttempt attempt(
    int index,
    VideoProvider provider,
    List<RegularVideoLinks> links,
  ) =>
      ProviderAttempt(
        index: index,
        provider: provider,
        result: ProviderLoadResult(success: true, videoLinks: links),
      );

  test('groups same-quality providers and ranks known size smallest first', () {
    final alphaLink = RegularVideoLinks(
      url: 'https://alpha.example/movie.m3u8',
      quality: '1080p',
      isM3U8: true,
      audioLanguage: 'hi',
      sizeToken: 'alpha-size',
    );
    final betaLink = RegularVideoLinks(
      url: 'https://beta.example/movie.mpd',
      quality: '1080p',
      isDash: true,
      audioLanguage: 'hi',
      sizeToken: 'beta-size',
    );
    final lowerQuality = RegularVideoLinks(
      url: 'https://alpha.example/720.m3u8',
      quality: '720p',
      isM3U8: true,
      audioLanguage: 'hi',
    );
    final attempts = [
      attempt(0, alpha, [alphaLink, lowerQuality]),
      attempt(1, beta, [betaLink]),
    ];
    final discovery = UnifiedPlaybackLanguageService.fromDetectedLanguages(
      attempts: attempts,
      detectedByProvider: {
        alpha.codeName: {'hi'},
        beta.codeName: {'hi'},
      },
    );
    final candidates = DownloadCoordinator.candidatesForLanguage(
      attempts: attempts,
      discovery: discovery,
      languageCode: 'hi',
      scraperApiUrl: 'https://scraper.example',
      estimatedSizes: {
        UnifiedPlaybackLanguageService.sourceIdentityForLink(alphaLink):
            900 * 1024 * 1024,
        UnifiedPlaybackLanguageService.sourceIdentityForLink(betaLink):
            700 * 1024 * 1024,
      },
    );

    final formats = DownloadCoordinator.buildFormats(candidates);
    expect(formats.map((format) => format.label), ['1080p', '720p']);
    expect(formats.first.sourceCount, 2);
    expect(formats.first.smallestSizeBytes, 700 * 1024 * 1024);
    expect(formats.first.deliveryDescription, 'DASH · HLS');
    expect(formats.first.candidates.first.provider.codeName, beta.codeName);
  });

  test('keeps provider renewal paths while grouping duplicate URLs into one format', () {
    final shared = RegularVideoLinks(
      url: 'https://cdn.example/movie.m3u8?token=same',
      quality: '1080p',
      isM3U8: true,
      audioLanguage: 'hi',
      headers: const {'Referer': 'https://cdn.example/'},
    );
    final attempts = [
      attempt(0, alpha, [shared]),
      attempt(
        1,
        beta,
        [
          RegularVideoLinks(
            url: shared.url,
            quality: '1080p',
            isM3U8: true,
            audioLanguage: 'hi',
            headers: const {'referer': 'https://cdn.example/'},
          ),
        ],
      ),
    ];
    final discovery = UnifiedPlaybackLanguageService.fromDetectedLanguages(
      attempts: attempts,
      detectedByProvider: {
        alpha.codeName: {'hi'},
        beta.codeName: {'hi'},
      },
    );
    final candidates = DownloadCoordinator.candidatesForLanguage(
      attempts: attempts,
      discovery: discovery,
      languageCode: 'hi',
      scraperApiUrl: 'https://scraper.example',
    );
    expect(candidates, hasLength(2));
    final formats = DownloadCoordinator.buildFormats(candidates);
    expect(formats, hasLength(1));
    expect(formats.single.sourceCount, 2);
  });

  test('only keeps a candidate whose inspected manifest contains the chosen language',
      () async {
    const hindi = OfflineAudioTrack(
      name: 'Hindi',
      selection: {
        'groupId': 'audio-hi',
        'formatId': 'hi',
        'language': 'hi',
      },
    );
    const english = OfflineAudioTrack(
      name: 'English',
      selection: {
        'groupId': 'audio-en',
        'formatId': 'en',
        'language': 'en',
      },
    );
    final hiLink = RegularVideoLinks(
      url: 'https://alpha.example/hi.m3u8',
      quality: '1080p',
      isM3U8: true,
      audioLanguage: 'hi',
    );
    final enLink = RegularVideoLinks(
      url: 'https://beta.example/en.m3u8',
      quality: '1080p',
      isM3U8: true,
      audioLanguage: 'en',
    );
    final attempts = [
      attempt(0, alpha, [hiLink]),
      attempt(1, beta, [enLink]),
    ];
    final discovery = UnifiedPlaybackLanguageService.fromDetectedLanguages(
      attempts: attempts,
      detectedByProvider: {
        alpha.codeName: {'hi'},
        beta.codeName: {'hi'},
      },
    );
    final candidates = DownloadCoordinator.candidatesForLanguage(
      attempts: attempts,
      discovery: discovery,
      languageCode: 'hi',
      scraperApiUrl: 'https://scraper.example',
    );
    final inspected = await DownloadCoordinator.inspectAudioTracks(
      candidates: candidates,
      languageCode: 'hi',
      inspect: (candidate) async =>
          candidate.provider.codeName == alpha.codeName ? [hindi] : [english],
    );

    expect(inspected, hasLength(1));
    expect(inspected.single.provider.codeName, alpha.codeName);
    expect(inspected.single.audioTrack?.selection, hindi.selection);
  });

  test('reuses audio track identities discovered with the selected manifest', () async {
    final hiLink = RegularVideoLinks(
      url: 'https://alpha.example/cached-hi.m3u8',
      quality: '1080p',
      isM3U8: true,
      audioLanguage: 'hi',
    );
    final attempts = [attempt(0, alpha, [hiLink])];
    final discovery = UnifiedPlaybackLanguageService.fromDetectedLanguages(
      attempts: attempts,
      detectedByProvider: {
        alpha.codeName: {'hi'},
      },
    );
    const hindi = OfflineAudioTrack(
      name: 'Hindi',
      selection: {
        'groupId': 'cached-audio-hi',
        'formatId': 'cached-hi',
        'language': 'hi',
      },
    );
    final identity =
        UnifiedPlaybackLanguageService.sourceIdentityForLink(hiLink);
    var inspected = false;

    final candidates = DownloadCoordinator.candidatesForLanguage(
      attempts: attempts,
      discovery: discovery,
      languageCode: 'hi',
      scraperApiUrl: 'https://scraper.example',
    );
    final selected = await DownloadCoordinator.inspectAudioTracks(
      candidates: candidates,
      languageCode: 'hi',
      cachedTracks: {identity: [hindi]},
      inspect: (_) async {
        inspected = true;
        return const [];
      },
    );

    expect(inspected, isFalse);
    expect(selected.single.audioTrack?.selection, hindi.selection);
  });

  test('provider discovery is bounded and preserves configured provider order',
      () async {
    final providers = List.generate(
      7,
      (index) => VideoProvider.scraper(id: 'p$index', name: 'Provider $index'),
    );
    var active = 0;
    var maximumActive = 0;
    final attempts = await DownloadCoordinator.loadProviders(
      providers: providers,
      concurrency: 2,
      timeout: const Duration(seconds: 1),
      load: (provider) async {
        active++;
        if (active > maximumActive) maximumActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        return ProviderLoadResult(
          success: true,
          videoLinks: [
            RegularVideoLinks(
              url: 'https://example.test/${provider.apiId}.m3u8',
              quality: '720p',
              isM3U8: true,
            ),
          ],
        );
      },
    );

    expect(maximumActive, 2);
    expect(
      attempts.map((item) => item.provider.codeName),
      providers.map((item) => item.codeName),
    );
  });

  test('timed out provider does not block the remaining catalogue', () async {
    final attempts = await DownloadCoordinator.loadProviders(
      providers: [alpha, beta],
      concurrency: 2,
      timeout: const Duration(milliseconds: 5),
      load: (provider) async {
        if (provider.codeName == alpha.codeName) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return ProviderLoadResult(
          success: true,
          videoLinks: [
            RegularVideoLinks(
              url: 'https://example.test/${provider.apiId}.m3u8',
              quality: '720p',
              isM3U8: true,
            ),
          ],
        );
      },
    );

    expect(attempts, hasLength(2));
    expect(attempts.first.hasPlayableSources, isFalse);
    expect(attempts.last.hasPlayableSources, isTrue);
  });
}
