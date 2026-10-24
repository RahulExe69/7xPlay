import 'package:flixquest/mobile/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tv_localization.dart';

void main() {
  initializeTvTranslations();

  testWidgets('the verified tick is labelled and keeps its own blue',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: const Scaffold(
        body: Row(children: [Text('Beamlak'), VerifiedBadge()]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Verified account'), findsOneWidget);
    final seal = tester.widget<Icon>(find.byType(Icon));
    expect(seal.color, VerifiedBadge.blue);
    expect(tester.getSize(find.byType(VerifiedBadge)), const Size(18, 18));
  });
}
