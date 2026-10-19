import 'package:flixquest/services/playback_ad_browser_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _BrowserLauncher extends UrlLauncherPlatform {
  final launches = <({String url, LaunchOptions options})>[];

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url: url, options: options));
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.beamlak.flixquest/playback_ad_browser');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _BrowserLauncher fallback;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final original = UrlLauncherPlatform.instance;
    fallback = _BrowserLauncher();
    UrlLauncherPlatform.instance = fallback;
    addTearDown(() {
      UrlLauncherPlatform.instance = original;
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
  });

  test('Chrome receives the complete current URL', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final url = Uri.parse('https://offer.example/path?a=1&b=2#section');
    expect(await openPlaybackBrowser(url), isTrue);
    expect(calls.single.method, 'openChrome');
    expect(calls.single.arguments, url.toString());
    expect(fallback.launches, isEmpty);
  });

  for (final unavailable in [
    'not installed',
    'platform error',
    'missing bridge'
  ]) {
    test('external browser fallback when Chrome has $unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (unavailable == 'platform error') {
          throw PlatformException(code: 'unavailable');
        }
        return unavailable == 'missing bridge' ? null : false;
      });
      final url = Uri.parse('https://offer.example/path?campaign=1');
      expect(await openPlaybackBrowser(url), isTrue);
      expect(fallback.launches.single.url, url.toString());
      expect(fallback.launches.single.options.mode,
          PreferredLaunchMode.externalApplication);
    });
  }

  test('local and non-web URLs never launch an application', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      fail('Non-web URLs must not reach the native launcher');
    });
    for (final raw in [
      'about:blank',
      'javascript:alert(1)',
      'file:///tmp/ad.html',
      'intent://offer',
      'https:/missing-host',
    ]) {
      expect(await openPlaybackBrowser(Uri.parse(raw)), isFalse);
    }
    expect(fallback.launches, isEmpty);
  });
}
