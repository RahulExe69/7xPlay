import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/landing_screen.dart';
import 'package:flixquest/translations/codegen_loader.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _supportedLocales = <Locale>[
  Locale('en'),
  Locale('es'),
  Locale('ar'),
  Locale('hi'),
];

Future<void> _pumpLanding(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: _supportedLocales,
      startLocale: locale,
      fallbackLocale: const Locale('en'),
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      saveLocale: false,
      child: Builder(
        builder: (context) => ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
          child: MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const LandingScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('uses the dedicated 7xPlay wordmark and brand access card',
      (tester) async {
    await _pumpLanding(tester);

    expect(find.byKey(const ValueKey('landing-brand-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-brand-mark')), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-access-card')), findsOneWidget);
    expect(find.text(tr('continue_anonymously')), findsOneWidget);

    final wordmark = tester.widget<Image>(
      find.byKey(const ValueKey('landing-brand-mark')),
    );
    expect(wordmark.image, isA<AssetImage>());
    expect(
      (wordmark.image as AssetImage).assetName,
      'assets/images/7xplay_wordmark.png',
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/grid_final.jpg',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the entry composition within phone and wide layouts',
      (tester) async {
    for (final size in const <Size>[
      Size(320, 640),
      Size(390, 844),
      Size(1280, 800),
    ]) {
      await _pumpLanding(tester, size: size);
      expect(find.byKey(const ValueKey('landing-brand-mark')), findsOneWidget);
      expect(find.byKey(const ValueKey('landing-access-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keeps the entry layout in Arabic right-to-left mode',
      (tester) async {
    await _pumpLanding(tester, locale: const Locale('ar'));
    final screen = find.byType(LandingScreen);
    expect(screen, findsOneWidget);
    expect(
      Directionality.of(tester.element(screen)),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
