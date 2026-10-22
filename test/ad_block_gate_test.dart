import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flixquest/services/ad_block_check_cache.dart';
import 'package:flixquest/widgets/ad_block_gate.dart';
import 'package:flixquest/widgets/ad_block_warmup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_adsterra_webview.dart';
import 'support/tv_localization.dart';

final real = InternetAddress('104.21.27.36');

/// Local DNS answers per host; a missing host fails like NXDOMAIN.
HostLookup lookupFrom(Map<String, List<List<InternetAddress>>> answers,
        [List<String>? calls]) =>
    (host) async {
      calls?.add(host);
      if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
      final queue = answers[host];
      if (queue == null || queue.isEmpty) {
        throw SocketException('Failed host lookup: $host');
      }
      return queue.length == 1 ? queue.single : queue.removeAt(0);
    };

void main() {
  initializeTvTranslations();

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  group('AdBlockDetector', () {
    AdBlockDetector detector(Map<String, List<List<InternetAddress>>> local,
            {Map<String, bool?> public = const {},
            List<String>? publicCalls}) =>
        AdBlockDetector(
          lookup: lookupFrom(local),
          publicLookup: (host) async {
            publicCalls?.add(host);
            return public[host];
          },
        );

    test('a sinkholed ad host is a blocker', () async {
      for (final sinkhole in [
        '0.0.0.0',
        '::',
        '127.0.0.1',
        '::1',
        '::ffff:127.0.0.1',
        '::ffff:0.0.0.0'
      ]) {
        final result = await detector({
          'ads.example': [
            [InternetAddress(sinkhole)]
          ],
        }).isBlocking({'ads.example'});
        expect(result, isTrue, reason: sinkhole);
      }
    });

    test('real answers never consult public DNS', () async {
      final publicCalls = <String>[];
      final result = await detector({
        'ads.example': [
          [real]
        ],
        'cdn.example': [
          [real, InternetAddress('0.0.0.0')]
        ],
      }, publicCalls: publicCalls)
          .isBlocking({'ads.example', 'cdn.example'});
      expect(result, isFalse);
      expect(publicCalls, isEmpty);
    });

    test('a host only public DNS can resolve is a blocker', () async {
      final result = await detector({}, public: {'ads.example': true})
          .isBlocking({'ads.example'});
      expect(result, isTrue);
    });

    test('a retired ad domain is not a blocker', () async {
      final result = await detector({}, public: {'ads.example': false})
          .isBlocking({'ads.example'});
      expect(result, isFalse);
    });

    test('no public answer, as when offline, is not a blocker', () async {
      final result = await detector({}).isBlocking({'ads.example'});
      expect(result, isFalse);
    });

    test('sinkholes for the whole network do not accuse an ad blocker',
        () async {
      final brokenNetwork = AdBlockDetector(
        lookup: (_) async => [InternetAddress('0.0.0.0')],
        publicLookup: (_) async => true,
      );
      expect(await brokenNetwork.isBlocking({'ads.example'}), isFalse);
    });

    test('unexpected probe failure cannot hide another positive check',
        () async {
      final check = detector({});
      expect(
          await check.isBlocking({}, additionalChecks: [
            () async => throw StateError('unavailable WebView'),
            () async => true,
          ]),
          isTrue);
    });

    test('a one-off local failure is retried before blaming a blocker',
        () async {
      final calls = <String>[];
      final flaky = AdBlockDetector(
        lookup: (host) async {
          if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
          calls.add(host);
          if (calls.length == 1) throw const SocketException('timeout');
          return [real];
        },
        publicLookup: (_) async => true,
      );
      expect(await flaky.isBlocking({'ads.example'}), isFalse);
      expect(calls, hasLength(2));
    });

    test('a check that runs too long allows playback', () async {
      final slow = AdBlockDetector(
        lookup: (_) => Completer<List<InternetAddress>>().future,
        timeout: const Duration(milliseconds: 10),
      );
      expect(await slow.isBlocking({'ads.example'}), isFalse);
    });

    test('a stalled host cannot hide another host being sinkholed', () async {
      final probe = AdBlockDetector(
        lookup: (host) => AdBlockDetector.dnsControlHosts.contains(host)
            ? Future.value([real])
            : host == 'stalled.example'
                ? Completer<List<InternetAddress>>().future
                : Future.value([InternetAddress('0.0.0.0')]),
        timeout: const Duration(milliseconds: 50),
      );
      expect(await probe.isBlocking({'stalled.example', 'blocked.example'}),
          isTrue);
    });

    test('a stalled public resolver cannot hide a confirmed blocked host',
        () async {
      final probe = AdBlockDetector(
        lookup: (host) async => AdBlockDetector.dnsControlHosts.contains(host)
            ? [real]
            : throw const SocketException('NXDOMAIN'),
        publicLookup: (host) => host == 'stalled.example'
            ? Completer<bool?>().future
            : Future.value(true),
        timeout: const Duration(milliseconds: 50),
      );
      expect(await probe.isBlocking({'stalled.example', 'blocked.example'}),
          isTrue);
    });

    test('no ad hosts means nothing to check', () async {
      expect(await detector({}).isBlocking({}), isFalse);
    });

    test('ad hosts come from live banners and Adsterra playback ads', () {
      final provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig())
        ..setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse('''{
          "interstitial":{"enabled":true,"script_url":"https://social.example/s"},
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://smart.example/l"}
        }''', enabled: true));
      expect(AdBlockDetector.adHosts(provider),
          {'ads.example', 'social.example', 'smart.example'});

      provider
        ..setBannerAdNetwork('none')
        ..setAdsterraPlaybackAdsConfig(
            const AdsterraPlaybackAdsConfig(enabled: false));
      expect(AdBlockDetector.adHosts(provider), isEmpty);
    });

    test('selected popup networks are checked on mobile and TV', () {
      final provider = AppDependencyProvider()
        ..setPlaybackPopunderNetwork(AdNetwork.monetag)
        ..setTvPlaybackPopunderNetwork(AdNetwork.exoclick);
      for (final network in [
        AdNetwork.monetag,
        AdNetwork.exoclick,
        AdNetwork.clickadu,
      ]) {
        provider.setPopunderAdsConfig(PopunderAdsConfig.parse('''{
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://${network.name}.example/ad"},
          "download":{"enabled":true,"mode":"script","script_url":"https://download.${network.name}.example/ad"}
        }''', network: network, enabled: true));
      }
      expect(AdBlockDetector.adHosts(provider), {
        'monetag.example',
        'download.monetag.example',
        'exoclick.example',
        'download.exoclick.example',
      });
      provider
        ..setPlaybackPopunderNetwork(null)
        ..setTvPlaybackPopunderNetwork(null);
      expect(AdBlockDetector.adHosts(provider), isEmpty);
    });

    test('banner slot overrides contribute their active domains', () {
      final provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig())
        ..setBannerAdsConfig(testClickaduConfig())
        ..setBannerAdNetworkOverrides({'movie_detail': 'clickadu'});
      expect(AdBlockDetector.adHosts(provider),
          containsAll(['ads.example', 'cl.example', 'cl2.example']));
      provider.setBannerAdNetwork('none');
      expect(AdBlockDetector.adHosts(provider), isEmpty);
    });
  });

  group('AdBlockGate', () {
    late AppDependencyProvider provider;
    late bool blocked;
    late int checks;
    late BuildContext host;

    setUp(() {
      provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig())
        ..adBlockGateEnabled = true;
      blocked = true;
      checks = 0;
    });

    AdBlockGate gate() => AdBlockGate(
          // Retry-dialog tests explicitly await detection. Production uses
          // zero foreground wait, covered by the background playback tests.
          cache: AdBlockCheckCache(
              foregroundWait: const Duration(milliseconds: 700)),
          additionalChecks: const [],
          detector: AdBlockDetector(
            lookup: (host) async {
              if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
              if (host == 'ads.example') checks++;
              return [blocked ? InternetAddress('0.0.0.0') : real];
            },
          ),
        );

    Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
          ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: MaterialApp(
              home: Builder(builder: (context) {
                host = context;
                return const SizedBox();
              }),
            ),
          ),
        );

    testWidgets('does nothing until the remote switch is on', (tester) async {
      provider.adBlockGateEnabled = false;
      await pumpHost(tester);
      expect(await gate().allowPlayback(host), isTrue);
      expect(checks, 0);
    });

    testWidgets('lets viewers without a blocker straight through',
        (tester) async {
      blocked = false;
      await pumpHost(tester);
      expect(await gate().allowPlayback(host), isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('transport or WebView evidence triggers the same gate',
        (tester) async {
      await pumpHost(tester);
      final check = AdBlockGate(
        detector: AdBlockDetector(lookup: (_) async => [real]),
        additionalChecks: [(_) async => true],
      );
      await check.warmUp(host);
      final result = check.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets(
        'playback starts immediately without losing later background evidence',
        (tester) async {
      await pumpHost(tester);
      final pending = Completer<bool>();
      final shared = AdBlockGate(
        detector: AdBlockDetector(lookup: (_) async => [real]),
        cache: AdBlockCheckCache(now: tester.binding.clock.now),
        additionalChecks: [(_) => pending.future],
      );
      final first = shared.allowPlayback(host);
      await tester.pump();
      expect(await first, isTrue);
      pending.complete(true);
      await tester.pump();
      final second = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await second, isFalse);
    });

    testWidgets('a remote toggle starts checking an already blocked device',
        (tester) async {
      provider.adBlockGateEnabled = false;
      await pumpHost(tester);
      final shared = gate();
      expect(await shared.allowPlayback(host), isTrue);
      expect(checks, 0);

      provider.adBlockGateEnabled = true;
      final result = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('DNS probe detects filtering when ad domains still resolve',
        (tester) async {
      final lookedUp = <String>[];
      final probe = AdBlockGate(
        additionalChecks: const [],
        detector: AdBlockDetector(lookup: (host) async {
          lookedUp.add(host);
          return [
            host == 'doubleclick.net' ? InternetAddress('0.0.0.0') : real
          ];
        }),
      );
      await pumpHost(tester);
      await probe.warmUp(host);
      final result = probe.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(lookedUp, containsAll(['doubleclick.net', 'ads.example']));
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('DNS probe still runs without configured ad hosts',
        (tester) async {
      provider.setBannerAdNetwork('none');
      await pumpHost(tester);
      final result = gate().allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('waits for the blocker to go, then continues', (tester) async {
      await pumpHost(tester);
      final result = gate().allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);

      // Still blocked: the dialog returns with the reminder.
      await tester.tap(find.text('I turned it off'));
      await tester.pumpAndSettle();
      expect(find.textContaining('still on'), findsOneWidget);

      blocked = false;
      await tester.tap(find.text('I turned it off'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('cancelling stops playback', (tester) async {
      await pumpHost(tester);
      final result = gate().allowPlayback(host, download: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets(
        'network invalidation does not hide a newly enabled DNS blocker',
        (tester) async {
      blocked = false;
      await pumpHost(tester);
      final shared = gate();
      expect(await shared.allowPlayback(host), isTrue);
      expect(checks, 1);

      blocked = true;
      shared.invalidate();
      final result = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(checks, 2);
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('warmup is silent and refreshes on network changes and resume',
        (tester) async {
      final network = StreamController<List<ConnectivityResult>>(sync: true);
      final shared = gate();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
            home: AdBlockWarmup(
          gate: shared,
          networkChanges: network.stream,
          child: Builder(builder: (context) {
            host = context;
            return const Scaffold();
          }),
        )),
      ));
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(find.byType(Dialog), findsNothing);
      network.add([ConnectivityResult.wifi]);
      await tester.pumpAndSettle();
      expect(checks, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(checks, 3);
      final playback = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      expect(checks, 3);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await playback, isFalse);
      await tester.pumpWidget(const SizedBox());
      unawaited(network.close());
    });
  });
}
