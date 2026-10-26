import 'package:flixquest/tv/widgets/tv_form_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

class _Typed {
  String text = '';
  int actions = 0;
  int exits = 0;
}

Future<_Typed> _pumpKeyboard(WidgetTester tester) async {
  final typed = _Typed();
  final keyboard = GlobalKey<TvFormKeyboardState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: TvFormKeyboard(
            key: keyboard,
            onType: (text) => typed.text += text,
            onDelete: () => typed.text = typed.text.isEmpty
                ? ''
                : typed.text.substring(0, typed.text.length - 1),
            onClear: () => typed.text = '',
            onAction: () => typed.actions++,
            actionLabel: 'Next',
            onExitLeft: () {
              typed.exits++;
              return true;
            },
          ),
        ),
      ),
    ),
  );
  keyboard.currentState!.requestFocus();
  await tester.pumpAndSettle();
  return typed;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('tv-form-key-$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Shift capitalises one letter, then lets go', (tester) async {
    final typed = await _pumpKeyboard(tester);
    await _tap(tester, TvFormKeyboard.shift);
    expect(find.text('Q'), findsOneWidget);
    await _tap(tester, 'q');
    await _tap(tester, 'q');
    expect(typed.text, 'Qq');
  });

  testWidgets('?123 swaps in symbols and keeps focus on the swap key', (
    tester,
  ) async {
    final typed = await _pumpKeyboard(tester);
    for (var row = 0; row < 3; row++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focused, 'TV form keyboard symbols');
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('ABC'), findsOneWidget);
    expect(_focused, 'TV form keyboard symbols');
    await _tap(tester, '!');
    await _tap(tester, TvFormKeyboard.dotCom);
    expect(typed.text, '!.com');
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('?123'), findsOneWidget);
  });

  testWidgets('the D-pad walks rows by column and hands Left off the edge', (
    tester,
  ) async {
    final typed = await _pumpKeyboard(tester);
    expect(_focused, 'TV form keyboard q');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV form keyboard 1');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV form keyboard 1');
    for (var row = 0; row < 5; row++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focused, 'TV form keyboard clear');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'TV form keyboard action');
    await _press(tester, LogicalKeyboardKey.select);
    expect(typed.actions, 1);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(typed.exits, 1);
  });

  testWidgets('a hardware keyboard types any character straight in', (
    tester,
  ) async {
    final typed = await _pumpKeyboard(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'A');
    await tester.sendKeyEvent(
      LogicalKeyboardKey.at,
      character: '@',
      physicalKey: PhysicalKeyboardKey.digit2,
    );
    expect(typed.text, 'A@');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(typed.text, 'A');
  });

  testWidgets('Right off the last column is handed to onExitRight', (
    tester,
  ) async {
    var exits = 0;
    final keyboard = GlobalKey<TvFormKeyboardState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: TvFormKeyboard(
              key: keyboard,
              onType: (_) {},
              onDelete: () {},
              onClear: () {},
              onAction: () {},
              actionLabel: 'Next',
              onExitRight: () {
                exits++;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    keyboard.currentState!.requestFocus();
    await tester.pumpAndSettle();
    // The keys stay left-to-right under RTL: q is the leftmost letter.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tv-form-key-q'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('tv-form-key-p'))).dx,
      ),
    );
    for (var column = 0; column < TvFormKeyboard.columns; column++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(_focused, 'TV form keyboard p');
    expect(exits, 1);
  });

  test('widthFor fits the keyboard into a height', () {
    const height = 260.0;
    final width = TvFormKeyboard.widthFor(height);
    expect(TvFormKeyboard.heightFor(width), closeTo(height, 0.001));
  });
}
