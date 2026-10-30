import 'dart:async';

import 'package:flixquest/video_providers/common.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flixquest/video_providers/provider_loader.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderLoadResult playableResult() => ProviderLoadResult(
      success: true,
      videoLinks: [RegularVideoLinks(url: 'https://example.com/video.m3u8')],
    );

void main() {
  final providers = List.generate(
    5,
    (index) => VideoProvider.scraper(id: '$index', name: 'Provider $index'),
  );

  test('starts playback from the first usable provider while alternates continue', () async {
    final firstResult = Completer<ProviderLoadResult>();
    final slowResult = Completer<ProviderLoadResult>();
    final session = ProviderLoader.startLoadingAllSuccessful(
      providers: providers.take(2).toList(),
      load: (provider) =>
          provider == providers.first ? firstResult.future : slowResult.future,
    );

    await Future<void>.delayed(Duration.zero);
    firstResult.complete(playableResult());
    final first = await session.firstPlayable.timeout(
      const Duration(seconds: 1),
    );
    expect(first?.provider, providers.first);

    var allCompleted = false;
    session.allSuccessful.then((_) => allCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(allCompleted, isFalse);

    slowResult.complete(playableResult());
    final combined = await session.allSuccessful;
    expect(combined?.attempts, hasLength(2));
    expect(combined?.result.videoLinks, hasLength(2));
  });

  test('first provider success never starts backup requests', () async {
    final firstResult = Completer<ProviderLoadResult>();
    final startedProviders = <String>[];
    final completedProviders = <String>[];
    final result = playableResult();

    final selectionFuture = ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) {
        startedProviders.add(provider.apiId!);
        return firstResult.future;
      },
      onResult: (_, provider, __) => completedProviders.add(provider.apiId!),
    );

    await Future<void>.delayed(Duration.zero);
    expect(startedProviders, ['0']);
    expect(completedProviders, isEmpty);

    firstResult.complete(result);
    final selection = await selectionFuture;

    expect(selection?.index, 0);
    expect(selection?.provider, providers.first);
    expect(selection?.result, same(result));
    expect(startedProviders, ['0']);
    expect(completedProviders, ['0']);
  });

  test('each fallback waits for the previous provider to fail', () async {
    final results = List.generate(5, (_) => Completer<ProviderLoadResult>());
    final startedProviders = <String>[];
    final completedIndexes = <int>[];

    final selectionFuture = ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) {
        startedProviders.add(provider.apiId!);
        return results[int.parse(provider.apiId!)].future;
      },
      onResult: (index, _, __) => completedIndexes.add(index),
    );

    await Future<void>.delayed(Duration.zero);
    expect(startedProviders, ['0']);

    for (var index = 0; index < 3; index++) {
      results[index].complete(const ProviderLoadResult(errorMessage: 'Failed'));
      await Future<void>.delayed(Duration.zero);
      expect(startedProviders, [for (var i = 0; i <= index + 1; i++) '$i']);
      expect(completedIndexes, [for (var i = 0; i <= index; i++) i]);
    }

    results[3].complete(playableResult());
    final selection = await selectionFuture;
    expect(selection?.index, 3);
    expect(selection?.provider, providers[3]);
    expect(startedProviders, ['0', '1', '2', '3']);
    expect(completedIndexes, [0, 1, 2, 3]);
  });

  test('exceptions and empty successful results fall through in order',
      () async {
    final attempts = <int>[];
    final reportedResults = <ProviderLoadResult>[];

    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) {
        final index = int.parse(provider.apiId!);
        attempts.add(index);
        switch (index) {
          case 0:
            throw StateError('Synchronous failure');
          case 1:
            return Future.error(StateError('Asynchronous failure'));
          case 2:
            return Future.value(const ProviderLoadResult(success: true));
          case 3:
            return Future.value(
              const ProviderLoadResult(success: true, videoLinks: []),
            );
          default:
            return Future.value(playableResult());
        }
      },
      onResult: (_, __, result) => reportedResults.add(result),
    );

    expect(selection?.index, 4);
    expect(attempts, [0, 1, 2, 3, 4]);
    expect(reportedResults, hasLength(5));
    expect(reportedResults[0].errorMessage, contains('Synchronous failure'));
    expect(reportedResults[1].errorMessage, contains('Asynchronous failure'));
  });

  test('returns null after every provider fails', () async {
    final attempts = <String>[];
    final completedProviders = <String>[];

    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) async {
        attempts.add(provider.codeName);
        return const ProviderLoadResult(errorMessage: 'No sources');
      },
      onResult: (_, provider, __) => completedProviders.add(provider.codeName),
    );

    expect(selection, isNull);
    expect(attempts, providers.map((provider) => provider.codeName));
    expect(completedProviders, attempts);
  });

  test('empty provider list makes no requests', () async {
    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: [],
      load: (_) => throw StateError('No provider should be loaded'),
      onResult: (_, __, ___) => fail('No result should be reported'),
    );

    expect(selection, isNull);
  });

  test(
    'loads all providers concurrently and combines distinct stream links',
    () async {
      final requests = List.generate(3, (_) => Completer<ProviderLoadResult>());
      final started = <String>[];
      final reported = <String>[];

      final combinedFuture = ProviderLoader.loadAllSuccessful(
        providers: providers.take(3).toList(),
        load: (provider) {
          final index = int.parse(provider.apiId!);
          started.add(provider.apiId!);
          return requests[index].future;
        },
        onResult: (_, provider, __) => reported.add(provider.apiId!),
      );

      await Future<void>.delayed(Duration.zero);
      expect(started, ['0', '1', '2']);

      requests[0].complete(
        ProviderLoadResult(
          success: true,
          videoLinks: [
            RegularVideoLinks(
              url: 'https://example.com/primary.m3u8',
              quality: '1080p',
              server: 'Main',
              headers: {
                'Referer': 'https://provider0.example/',
                'Origin': 'https://provider0.example',
              },
              audioLanguage: 'en',
            ),
          ],
          subtitleLinks: [
            RegularSubtitleLinks(
              url: 'https://example.com/en.vtt',
              language: 'English',
            ),
          ],
        ),
      );
      requests[1].complete(
        ProviderLoadResult(
          success: true,
          videoLinks: [
            // Same URL and equivalent headers is deduplicated even when
            // header casing and map order differ.
            RegularVideoLinks(
              url: 'https://example.com/primary.m3u8',
              quality: '1080p',
              server: 'Main',
              headers: {
                'origin': 'https://provider0.example',
                'referer': 'https://provider0.example/',
              },
            ),
            // A duplicate URL with different access headers is a distinct,
            // usable variant and must be retained.
            RegularVideoLinks(
              url: 'https://example.com/primary.m3u8',
              quality: '1080p',
              server: 'Alternative',
              headers: {'Referer': 'https://provider1.example/'},
              audioLanguage: 'hi',
            ),
            RegularVideoLinks(
              url: 'https://example.com/hindi.m3u8',
              quality: '720p',
              audioLanguage: 'bn',
            ),
          ],
          subtitleLinks: [
            RegularSubtitleLinks(
              url: 'https://example.com/hi.vtt',
              language: 'Hindi',
            ),
            RegularSubtitleLinks(
              url: 'https://example.com/en.vtt',
              language: 'English',
            ),
          ],
        ),
      );
      requests[2].complete(const ProviderLoadResult(errorMessage: 'Offline'));

      final selection = await combinedFuture;
      expect(selection?.provider, providers[0]);
      expect(
        selection!.result.videoLinks!.map((link) => link.url),
        [
          'https://example.com/primary.m3u8',
          'https://example.com/primary.m3u8',
          'https://example.com/hindi.m3u8',
        ],
      );
      expect(
        selection.result.videoLinks!.map((link) => link.quality),
        [
          '1080p · Provider 0',
          '1080p · Provider 1',
          '720p · Provider 1',
        ],
      );
      expect(
        selection.result.videoLinks!.map((link) => link.server),
        ['Main', 'Alternative', null],
      );
      expect(
        selection.result.videoLinks!.map((link) => link.headers),
        [
          {
            'Referer': 'https://provider0.example/',
            'Origin': 'https://provider0.example',
          },
          {'Referer': 'https://provider1.example/'},
          null,
        ],
      );
      expect(
        selection.result.subtitleLinks!.map((subtitle) => subtitle.language),
        ['English', 'Hindi'],
      );
      expect(
        selection.result.videoLinks!.map((link) => link.audioLanguage),
        ['en', 'hi', 'bn'],
      );
      expect(
        selection.result.videoLinks!.map((link) => link.providerCode),
        ['scraper:0', 'scraper:1', 'scraper:1'],
      );
      expect(reported.toSet(), {'0', '1', '2'});
      expect(selection.attempts.map((attempt) => attempt.provider.apiId),
          ['0', '1', '2']);
      expect(selection.attempts[0].hasPlayableSources, isTrue);
      expect(selection.attempts[2].hasPlayableSources, isFalse);
      expect(selection.attempts[2].result.errorMessage, 'Offline');
    },
  );

  test('fallback candidates preserve priority and selected-language eligibility',
      () {
    final attempts = <ProviderAttempt>[
      ProviderAttempt(
        index: 0,
        provider: providers[0],
        result: playableResult(),
      ),
      ProviderAttempt(
        index: 1,
        provider: providers[1],
        result: playableResult(),
      ),
      ProviderAttempt(
        index: 2,
        provider: providers[2],
        result: const ProviderLoadResult(errorMessage: 'Offline'),
      ),
      ProviderAttempt(
        index: 3,
        provider: providers[3],
        result: playableResult(),
      ),
    ];

    final candidates = ProviderLoader.fallbackCandidates(
      attempts: attempts,
      failedProviderCode: providers[0].codeName,
      eligibleProviderCodes: [
        providers[0].codeName,
        providers[1].codeName,
        providers[2].codeName,
      ],
      alreadyTriedProviderCodes: {providers[0].codeName},
    );

    expect(
      candidates.map((attempt) => attempt.provider.apiId),
      ['1'],
    );
  });

  test('does not wait forever for a stalled provider', () async {
    final neverCompletes = Completer<ProviderLoadResult>();
    final selection = await ProviderLoader.loadAllSuccessful(
      providers: providers.take(2).toList(),
      providerTimeout: const Duration(milliseconds: 10),
      load: (provider) => provider.apiId == '0'
          ? Future.value(playableResult())
          : neverCompletes.future,
    );

    expect(selection?.provider, providers.first);
    expect(selection?.result.videoLinks, isNotEmpty);
  });

  test('returns null when no provider yields a usable stream URL', () async {
    final selection = await ProviderLoader.loadAllSuccessful(
      providers: providers.take(2).toList(),
      load: (_) async => ProviderLoadResult(
        success: true,
        videoLinks: [RegularVideoLinks(url: '  ')],
      ),
    );
    expect(selection, isNull);
  });
}
