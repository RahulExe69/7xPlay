import 'package:flixquest/services/provider_audio_language_cache.dart';
import 'package:flixquest/video_providers/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('caches language metadata without persisting signed stream URLs', () async {
    SharedPreferences.setMockInitialValues({});

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
    expect(
      await ProviderAudioLanguageCache.read(
        providerCode: 'scraper:another',
        link: renewed,
      ),
      isNull,
    );
    expect(
      await ProviderAudioLanguageCache.read(
        providerCode: 'scraper:karamara',
        link: RegularVideoLinks(
          url: 'https://cdn.example.test/other.m3u8?token=second-secret',
          quality: '1080p',
          server: 'server-a',
          isM3U8: true,
        ),
      ),
      isNull,
    );

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(
      '7xplay.provider_audio_languages.v1',
    )!;
    expect(stored, isNot(contains('cdn.example.test')));
    expect(stored, isNot(contains('first-secret')));
    expect(stored, isNot(contains('second-secret')));
    expect(stored, contains('en'));
    expect(stored, contains('hi'));
  });
}
