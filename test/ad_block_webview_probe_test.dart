import 'dart:convert';
import 'dart:io';

import 'package:flixquest/services/ad_block_webview_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/fake_adsterra_webview.dart';

void main() {
  late FakeAdsterraWebViewPlatform platform;
  late BuildContext host;
  setUp(() {
    platform = FakeAdsterraWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        }),
      ));

  void report(
      {required bool controls,
      bool cosmetic = false,
      List<String> failed = const [],
      String? token}) {
    final controller = platform.controllers.single;
    final match = RegExp(r'const probeToken = (.*);')
        .firstMatch(controller.htmlLoads.single)!;
    controller.send(jsonEncode({
      'token': token ?? jsonDecode(match.group(1)!),
      'controls': controls,
      'cosmetic': cosmetic,
      'failed': failed
    }));
  }

  testWidgets(
      'cosmetic filtering with healthy controls triggers and releases the view',
      (tester) async {
    await pumpHost(tester);
    final result = AdBlockWebViewProbe.isBlocking(host);
    await tester.pumpAndSettle();
    expect(find.byType(WebViewWidget), findsOneWidget);
    report(controls: true, cosmetic: true);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(WebViewWidget), findsNothing);
    expect(platform.controllers.single.requests.last, Uri.parse('about:blank'));
  });

  testWidgets('offline controls and a clean report allow playback',
      (tester) async {
    await pumpHost(tester);
    final offline = AdBlockWebViewProbe.isBlocking(host);
    await tester.pumpAndSettle();
    report(controls: false, cosmetic: true);
    await tester.pumpAndSettle();
    expect(await offline, isFalse);
    platform.controllers.clear();
    final clean = AdBlockWebViewProbe.isBlocking(host);
    await tester.pumpAndSettle();
    report(controls: true);
    await tester.pumpAndSettle();
    expect(await clean, isFalse);
  });

  testWidgets('a stale report is ignored and timeout releases the overlay',
      (tester) async {
    await pumpHost(tester);
    final result = AdBlockWebViewProbe.isBlocking(host);
    await tester.pumpAndSettle();
    report(controls: true, cosmetic: true, token: 'another-check');
    await tester.pump(AdBlockWebViewProbe.timeout);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(find.byType(WebViewWidget), findsNothing);
  });

  testWidgets('WebView failures require independent native confirmation',
      (tester) async {
    await pumpHost(tester);
    for (final nativeWorks in [false, true]) {
      platform.controllers.clear();
      final result = AdBlockWebViewProbe.isBlocking(host,
          nativeReachable: (_) async => nativeWorks);
      await tester.pumpAndSettle();
      report(
          controls: true,
          failed: ['pagead2.googlesyndication.com', 'ads.pubmatic.com']);
      await tester.pumpAndSettle();
      expect(await result, nativeWorks);
    }
  });

  testWidgets('only explicit blocker errors on ad hosts count as evidence',
      (tester) async {
    await pumpHost(tester);
    for (final description in [
      'net::ERR_FAILED',
      'net::ERR_BLOCKED_BY_CLIENT'
    ]) {
      platform.controllers.clear();
      final result = AdBlockWebViewProbe.isBlocking(host);
      await tester.pumpAndSettle();
      platform
          .controllers.single.delegate!.onWebResourceError!(WebResourceError(
        errorCode: -1,
        description: description,
        isForMainFrame: false,
        url: 'https://ads.pubmatic.com/robots.txt',
      ));
      report(controls: true);
      await tester.pumpAndSettle();
      expect(await result, description.contains('ERR_BLOCKED_BY_CLIENT'));
    }
  });

  testWidgets('an unavailable WebView allows playback', (tester) async {
    platform.setupError = StateError('WebView unavailable');
    await pumpHost(tester);
    final result = AdBlockWebViewProbe.isBlocking(host);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(find.byType(WebViewWidget), findsNothing);
  });

  test(
      'the production JavaScript probes run and distinguish cosmetic filtering',
      () async {
    // Run the actual embedded script, not a copy of the detection algorithm.
    for (final mode in ['clean', 'cosmetic', 'offline', 'blocked']) {
      final runner = '''
const probeToken='test'; const adUrls=['https://ads-a.example/robots.txt','https://ads-b.example/robots.txt'];
const controlUrls=['https://control-a.example/','https://control-b.example/'];
const mode=${jsonEncode(mode)};
global.document={getElementById:(id)=> mode==='cosmetic' && id!=='fq-control' ? null : {offsetHeight:20,offsetWidth:20}};
global.getComputedStyle=()=>({display:'block',visibility:'visible',opacity:'1'});
global.fetch=async(url,options)=>{if(options.method!=='HEAD')throw Error('unexpected method');
  if(mode==='offline'||(mode==='blocked'&&url.includes('ads-')))throw Error('filtered'); return {};};
global.FqFilterProbe={postMessage:(message)=>process.stdout.write(message)};
${AdBlockWebViewProbe.script}
''';
      final process = await Process.run('node', ['-e', runner]);
      expect(process.exitCode, 0, reason: process.stderr.toString());
      final data = jsonDecode(process.stdout as String) as Map;
      expect(data['cosmetic'], mode == 'cosmetic');
      expect(data['controls'], mode != 'offline');
      expect(data['failed'],
          mode == 'blocked' || mode == 'offline' ? hasLength(2) : isEmpty);
    }
  });
}
