import 'package:flixquest/services/provider_audio_language_cache.dart';
import 'package:flixquest/video_providers/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('reuses manifest languages when signed query tokens rotate', () async {
    final first = RegularVideoLinks(
      url: 'https://cdn.example.test/master.m3u8?token=first-secret',
      quality: '1080p',
      server: 'server-a',
      isM3U8: true,
    );
    final renewed = RegularVideoLinks(
      url: 'https://cdn.example.test/master.m3u8?token=second-secret',
      quality: '1080p',
      server: 'server-a',
      isM3U8: true,
    );

    await ProviderAudioLanguageCache.write(
      providerCode: 'scraper:karamara',
      link: first,
      languages: ['en', 'hi', 'EN', 'und'],
    );

    expect(
      await ProviderAudioLanguageCache.read(
        providerCode: 'scraper:karamara',
        link: renewed,
      ),
      {'en', 'hi'},
    );
  });

  test('keeps provider and source identities separate', () async {
    final link = RegularVideoLinks(
      url: 'https://cdn.example.test/master.m3u8?token=abc',
      quality: '720p',
      server: 'server-a',
      isM3U8: true,
    );

    await ProviderAudioLanguageCache.write(
      providerCode: 'scraper:karamara',
      link: link,
      languages: ['en'],
    );

    expect(
      await ProviderAudioLanguageCache.read(
        providerCode: 'scraper:another',
        link: link,
      ),
      isNull,
    );
    expect(
      await ProviderAudioLanguageCache.read(
        providerCode: 'scraper:karamara',
        link: RegularVideoLinks(
          url: 'https://cdn.example.test/other.m3u8?token=abc',
          quality: '720p',
          server: 'server-a',
          isM3U8: true,
        ),
      ),
      isNull,
    );
  });

  test('persists only a one-way fingerprint, never the signed URL', () async {
    final link = RegularVideoLinks(
      url: 'https://cdn.example.test/master.m3u8?token=do-not-store-this',
      quality: '1080p',
      server: 'server-a',
      isM3U8: true,
    );
    await ProviderAudioLanguageCache.write(
      providerCode: 'scraper:karamara',
      link: link,
      languages: ['en'],
    );
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(
      '7xplay.provider_audio_languages.v1',
    )!;

    expect(stored, isNot(contains('cdn.example.test')));
    expect(stored, isNot(contains('do-not-store-this')));
    expect(stored, contains('en'));
  });
}
