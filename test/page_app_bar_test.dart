import 'package:flixquest/mobile/widgets/page_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generic page app bars do not add decorative brand stripes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          appBar: const PageAppBar(title: 'Discover'),
          body: const SizedBox(),
        ),
      ),
    );

    expect(find.text('Discover'), findsOneWidget);
    expect(find.byType(BrandAccentRule), findsNothing);
  });
}
