import 'package:flixquest/design/seven_x_ai_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the 7x AI 7 mark uses dark ink on light and white on dark',
      (tester) async {
    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: theme,
            child: Center(child: SevenXAiMark(height: 64)),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(SevenXAiMark),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = customPaint.painter! as SevenXAiMarkPainter;
      expect(
        painter.color,
        theme.brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF141516),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
