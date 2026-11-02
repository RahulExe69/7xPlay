import 'package:flixquest/mobile/widgets/filter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home filter pills build and keep their selected state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FilterChips(
            chips: <FilterChipSpec>[
              FilterChipSpec(label: 'All', selected: true, onTap: () {}),
              FilterChipSpec(label: 'Movies', onTap: () {}),
              FilterChipSpec(label: 'Series', onTap: () {}),
            ],
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
