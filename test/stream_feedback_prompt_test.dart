import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/screens/common/player/player_sheet_ui.dart';
import 'package:flixquest/screens/common/player/stream_feedback_prompt.dart';
import 'package:flixquest/services/stream_feedback_service.dart';
import 'package:flixquest/services/stream_feedback_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _measurement = StreamFeedbackMeasurement(
  sessionMs: 75000,
  watchedMs: 65000,
  bufferingMs: 1000,
  bufferCount: 1,
  errorCount: 0,
  startupMs: 500,
  outcome: 'exited',
  transferBaseline: null,
  transferSampleMs: 0,
);

Future<void> _app(WidgetTester tester, Widget home,
    {GlobalKey<NavigatorState>? navigatorKey, ThemeData? theme}) async {
  await tester.pumpWidget(EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'assets/translations',
    assetLoader: const _LabelsLoader(),
    startLocale: const Locale('en'),
    child: Builder(
        builder: (context) => MaterialApp(
              navigatorKey: navigatorKey,
              theme: theme,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: home,
            )),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final mode in ['light', 'dark']) {
    testWidgets('$mode survey labels retain contrast in every selection state',
        (tester) async {
      late ThemeData appTheme;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        appTheme = Styles.themeData(
          appThemeMode: mode,
          isM3Enabled: true,
          lightDynamicColor: null,
          darkDynamicColor: null,
          context: context,
          appColor: AppColor(
            cs: AppColor.colorGetter(Colors.orange, mode == 'dark'),
            index: AppColor.defaultIndex,
          ),
        );
        return const SizedBox();
      })));
      await _app(
          tester,
          Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => showDialog<StreamFeedbackAnswer>(
                        context: context,
                        builder: (_) =>
                            const PlayerTheme(child: StreamFeedbackPrompt())),
                    child: const Text('Open'),
                  ))),
          theme: appTheme);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      void expectReadable(String label, {double minimum = 4.5}) {
        final richTextFinder = find.descendant(
            of: find.text(label), matching: find.byType(RichText));
        final richText = tester.widget<RichText>(richTextFinder);
        final material = tester.widget<Material>(find
            .ancestor(of: richTextFinder, matching: find.byType(Material))
            .first);
        final context = tester.element(richTextFinder);
        final panel = Theme.of(context).scaffoldBackgroundColor;
        // Chips paint their fill through Ink rather than Material.color.
        final inkFinder =
            find.ancestor(of: richTextFinder, matching: find.byType(Ink));
        final ink = inkFinder.evaluate().isEmpty
            ? null
            : tester.widget<Ink>(inkFinder.first);
        final decoration = ink?.decoration;
        final fill =
            decoration is ShapeDecoration ? decoration.color : material.color;
        final background = Color.alphaBlend(fill ?? Colors.transparent, panel);
        final foreground =
            Color.alphaBlend(richText.text.style!.color!, background);
        final luminances = [
          foreground.computeLuminance(),
          background.computeLuminance()
        ]..sort();
        expect((luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(minimum),
            reason: '$mode: $label must be readable against its rendered fill');
      }

      for (final label in ['Good', 'Okay', 'Bad', 'Skip']) {
        expectReadable(label);
      }
      expectReadable('Submit', minimum: 3);
      final firstChip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('feedback_rating_good')));
      final focusBorder = WidgetStateProperty.resolveAs<BorderSide?>(
          firstChip.side, {WidgetState.focused});
      expect(focusBorder!.width, 2);
      await tester.tap(find.byKey(const ValueKey('feedback_rating_bad')));
      await tester.pumpAndSettle();
      for (final label in [
        'Good',
        'Okay',
        'Bad',
        'Buffering',
        'Did not play',
        'Video quality',
        'Audio',
        'Subtitles',
        'Wrong content',
        'Other',
        'Skip',
        'Submit'
      ]) {
        expectReadable(label);
      }
      await tester
          .tap(find.byKey(const ValueKey('feedback_issue_did_not_play')));
      await tester.pumpAndSettle();
      expectReadable('Did not play');
      expectReadable('Buffering');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'remote Select chooses a rating; changing to Good clears the issue',
      (tester) async {
    StreamFeedbackAnswer? answer;
    await _app(
        tester,
        Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    answer = await showDialog<StreamFeedbackAnswer>(
                        context: context,
                        builder: (_) => const StreamFeedbackPrompt());
                  },
                  child: const Text('Open'),
                ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('feedback_submit')))
            .onPressed,
        isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('feedback_rating_good')))
            .selected,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('feedback_rating_bad')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('feedback_issue_wrong_content')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback_rating_good')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback_submit')));
    await tester.pumpAndSettle();
    expect(answer?.rating, 'good');
    expect(answer?.issue, 'none');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'phone survey scrolls, submits a useful issue and has no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StreamFeedbackAnswer? answer;
    await _app(
        tester,
        Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    answer = await showDialog<StreamFeedbackAnswer>(
                        context: context,
                        builder: (_) => const StreamFeedbackPrompt());
                  },
                  child: const Text('Open'),
                ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback_rating_bad')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('feedback_issue_did_not_play')));
    await tester.tap(find.byKey(const ValueKey('feedback_issue_did_not_play')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('feedback_submit')));
    await tester.tap(find.byKey(const ValueKey('feedback_submit')));
    await tester.pumpAndSettle();
    expect(answer?.rating, 'bad');
    expect(answer?.issue, 'did_not_play');
    expect(tester.takeException(), isNull);
  });

  for (final dismissWithBack in [false, true]) {
    testWidgets(
        'exit completes before ad and prompt; ${dismissWithBack ? 'Back' : 'Skip'} records dismissal and cooldown',
        (tester) async {
      final ad = Completer<void>();
      final events = <String>[];
      var restored = false;
      final service = StreamFeedbackService(
          debugAlwaysReport: false,
          draw: (_) => 0,
          writeEvent: (name, params) async {
            events.add(name);
          });
      await _app(
          tester,
          _ExitHarness(
              service: service,
              beforePrompt: (_) => ad.future,
              onReturned: () => restored = true));
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      expect(find.byType(StreamFeedbackPrompt), findsNothing);
      expect(restored, isFalse);
      ad.complete();
      await tester.pumpAndSettle();
      expect(find.byType(StreamFeedbackPrompt), findsOneWidget);
      expect(events, ['stream_feedback_shown']);
      if (dismissWithBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(const ValueKey('feedback_skip')));
      }
      await tester.pumpAndSettle();
      expect(events, ['stream_feedback_shown', 'stream_feedback_dismissed']);
      expect(restored, isTrue);
      expect(await service.reserve(_measurement), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('default debug build respects cooldown on repeated player exits',
      (tester) async {
    final events = <String>[];
    final service = StreamFeedbackService(
      draw: (_) => 0,
      writeEvent: (name, _) async {
        events.add(name);
      },
    );
    await _app(tester, _ExitHarness(service: service));
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    expect(find.byType(StreamFeedbackPrompt), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feedback_skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    expect(find.byType(StreamFeedbackPrompt), findsNothing);
    expect(events, ['stream_feedback_shown', 'stream_feedback_dismissed']);
    expect(
        (await SharedPreferences.getInstance())
            .getInt(StreamFeedbackService.cooldownKey),
        isNotNull);
  });

  testWidgets(
      'submitting after exit sends the frozen content context and answer',
      (tester) async {
    final events = <String>[];
    final payloads = <Map<String, Object>>[];
    final service = StreamFeedbackService(
        debugAlwaysReport: false,
        draw: (_) => 0,
        writeEvent: (name, params) async {
          events.add(name);
          payloads.add(params);
        });
    await _app(tester, _ExitHarness(service: service));
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback_rating_bad')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback_issue_buffering')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback_submit')));
    await tester.pumpAndSettle();
    expect(events, ['stream_feedback_shown', 'stream_feedback_submitted']);
    expect(payloads.last, {
      'media_type': 'movie',
      'tmdb_id': '123',
      'rating': 'bad',
      'issue': 'buffering'
    });
    expect(payloads.first.containsKey('rating'), isFalse);
  });

  testWidgets('navigating elsewhere cancels a pending prompt without cooldown',
      (tester) async {
    final ad = Completer<void>();
    final events = <String>[];
    final navigatorKey = GlobalKey<NavigatorState>();
    final service = StreamFeedbackService(
        debugAlwaysReport: false,
        draw: (_) => 0,
        writeEvent: (name, params) async {
          events.add(name);
        });
    await _app(
        tester, _ExitHarness(service: service, beforePrompt: (_) => ad.future),
        navigatorKey: navigatorKey);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    unawaited(navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Another screen')),
    )));
    await tester.pumpAndSettle();
    ad.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StreamFeedbackPrompt), findsNothing);
    expect(events, isEmpty);
    expect(await service.reserve(_measurement), isTrue);
    service.release();
  });
}

class _ExitHarness extends StatelessWidget {
  const _ExitHarness(
      {required this.service, this.beforePrompt, this.onReturned});
  final StreamFeedbackService service;
  final Future<void> Function(BuildContext)? beforePrompt;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) => Scaffold(
          body: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (context) => Scaffold(
              body: TextButton(
            onPressed: () {
              scheduleStreamFeedbackAfterExit(
                context,
                measurement: _measurement,
                parameters:
                    Future.value({'media_type': 'movie', 'tmdb_id': '123'}),
                beforePrompt: beforePrompt,
                onReturned: onReturned,
                service: service,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Exit'),
          )),
        )),
        child: const Text('Play'),
      ));
}

class _LabelsLoader extends AssetLoader {
  const _LabelsLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}
