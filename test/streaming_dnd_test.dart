import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/player_settings.dart';
import 'package:flixquest/services/streaming_dnd_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.beamlak.flixquest/streaming_dnd');
  final calls = <MethodCall>[];
  late SettingsProvider settings;
  var granted = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    await EasyLocalization.ensureInitialized();
    settings = SettingsProvider();
    granted = false;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'status' => {'supported': true, 'accessGranted': granted},
        'requestAccess' => true,
        _ => null,
      };
    });
  });

  tearDown(() {
    settings.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('preference defaults off and survives a new provider', () async {
    await settings.getStreamingDnd();
    expect(settings.doNotDisturbWhileStreaming, isFalse);
    settings.doNotDisturbWhileStreaming = true;
    expect(
        sharedPrefsSingleton.getBool(SettingsPreferences.STREAMING_DND), true);
    final reloaded = SettingsProvider();
    await reloaded.getStreamingDnd();
    expect(reloaded.doNotDisturbWhileStreaming, isTrue);
    reloaded.dispose();
  });

  test('overlapping player sessions release their own IDs and follow settings',
      () async {
    final first = StreamingDndSession(settings, television: false);
    expect(calls, isEmpty);
    settings.doNotDisturbWhileStreaming = true;
    final second = StreamingDndSession(settings, television: false);
    first.dispose();
    first.dispose();
    final events = calls.where((call) => call.method == 'setSessionActive');
    expect(events.length, 3);
    final firstId = events.first.arguments['sessionId'];
    final secondId = events.elementAt(1).arguments['sessionId'];
    expect(secondId, isNot(firstId));
    expect(events.last.arguments, {'sessionId': firstId, 'active': false});
    settings.doNotDisturbWhileStreaming = false;
    expect(calls.last.arguments, {'sessionId': secondId, 'active': false});
    final count = calls.length;
    settings.playerAmbientGlowEnabled = true;
    second.dispose();
    expect(calls.length, count);
  });

  test('TV and iOS sessions never request suppression', () async {
    settings.doNotDisturbWhileStreaming = true;
    final tv = StreamingDndSession(settings, television: true);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = StreamingDndSession(settings, television: false);
    expect(await StreamingDndService.status(), isEmpty);
    expect(await StreamingDndService.requestAccess(), isFalse);
    tv.dispose();
    ios.dispose();
    expect(calls, isEmpty);
  });

  test('missing native integration safely returns unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await StreamingDndService.status(), isEmpty);
    expect(await StreamingDndService.requestAccess(), isFalse);
    settings.doNotDisturbWhileStreaming = true;
    final session = StreamingDndSession(settings, television: false);
    session.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          assetLoader: const _Translations(),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const PlayerSettings(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Do not disturb while streaming'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('enables only after access is granted and disables immediately',
      (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Do not disturb while streaming'));
    await tester.pumpAndSettle();
    expect(settings.doNotDisturbWhileStreaming, false);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(calls.any((call) => call.method == 'requestAccess'), true);
    expect(settings.doNotDisturbWhileStreaming, false);
    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(settings.doNotDisturbWhileStreaming, true);
    await tester.tap(find.text('Do not disturb while streaming'));
    await tester.pumpAndSettle();
    expect(settings.doNotDisturbWhileStreaming, false);
  });

  testWidgets('denied access leaves the preference off', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Do not disturb while streaming'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(settings.doNotDisturbWhileStreaming, false);
    expect(tester.takeException(), isNull);
  });
}
