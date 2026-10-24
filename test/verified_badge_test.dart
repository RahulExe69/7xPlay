import 'package:flixquest/mobile/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tv_localization.dart';

void main() {
  initializeTvTranslations();

  testWidgets('the verified tick is labelled and takes the app colour',
      (tester) async {
    const accent = Color(0xFFF57C00);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: accent)
              .copyWith(primary: accent)),
      home: const Scaffold(
        body: Row(children: [Text('Beamlak'), VerifiedBadge()]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Verified account'), findsOneWidget);
    final seal = tester.widget<Icon>(find.byType(Icon));
    expect(seal.color, accent);
    expect(tester.getSize(find.byType(VerifiedBadge)), const Size(18, 18));
  });
}
