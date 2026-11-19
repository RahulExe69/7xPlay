import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/video_providers/names.dart';

void main() {
  group('VideoProviderOrder.prioritizeKaramara', () {
    const alpha = VideoProvider(
      fullName: 'Alpha',
      codeName: 'scraper:alpha',
      type: VideoProviderType.scraperApi,
      apiId: 'alpha',
    );
    const karamaraById = VideoProvider(
      fullName: 'Aethoflix',
      alias: 'Aethoflix',
      codeName: 'scraper:karamara',
      type: VideoProviderType.scraperApi,
      apiId: 'karamara',
    );
    const karamaraByName = VideoProvider(
      fullName: 'Karamara',
      codeName: 'scraper:provider-42',
      type: VideoProviderType.scraperApi,
      apiId: 'provider-42',
    );

    test('moves Karamara to the front without changing other order', () {
      final ordered = VideoProviderOrder.prioritizeKaramara(
        const [alpha, karamaraById, karamaraByName],
      );

      expect(ordered, [karamaraById, alpha, karamaraByName]);
    });

    test('matches Karamara case-insensitively in the alias', () {
      const provider = VideoProvider(
        fullName: 'Provider',
        alias: 'KARAMARA HD',
        codeName: 'scraper:provider',
        type: VideoProviderType.scraperApi,
        apiId: 'provider',
      );

      expect(
        VideoProviderOrder.prioritizeKaramara([alpha, provider]).first,
        provider,
      );
    });

    test('keeps the configured order when Karamara is unavailable', () {
      expect(
        VideoProviderOrder.prioritizeKaramara(const [alpha]),
        [alpha],
      );
    });

    test('does not duplicate or otherwise mutate a first-position Karamara', () {
      final ordered = VideoProviderOrder.prioritizeKaramara(
        const [karamaraById, alpha],
      );

      expect(ordered, [karamaraById, alpha]);
    });
  });
}
