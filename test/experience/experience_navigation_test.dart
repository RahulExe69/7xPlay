import 'package:flixquest/design/app_brand.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/app/experience_navigation.dart';
import 'package:flixquest/mobile/app/mobile_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  final theme = ThemeData.dark();
  return MaterialApp(
    theme: theme.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        ExperienceThemeExtension(
          palette: ExperiencePalette.fromTheme(theme),
        ),
      ],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ExperienceNavigation', () {
    testWidgets('shows all five stable destinations on a phone',
        (tester) async {
      await tester.pumpWidget(
        _app(
          ExperienceNavigation(
            current: MobileTab.home,
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.video_library_rounded), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('selecting a destination preserves the stable tab enum',
        (tester) async {
      MobileTab? selected;
      await tester.pumpWidget(
        _app(
          ExperienceNavigation(
            current: MobileTab.home,
            onSelect: (tab) => selected = tab,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.explore_rounded));
      expect(selected, MobileTab.discover);
    });

    testWidgets('uses the vertical destination rail on wide layouts',
        (tester) async {
      await tester.pumpWidget(
        _app(
          ExperienceNavigation(
            current: MobileTab.search,
            onSelect: (_) {},
            rail: true,
          ),
        ),
      );

      expect(find.text('7x'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('My space'), findsOneWidget);
    });

    testWidgets('marks only the active destination as selected',
        (tester) async {
      await tester.pumpWidget(
        _app(
          ExperienceNavigation(
            current: MobileTab.discover,
            onSelect: (_) {},
          ),
        ),
      );

      final selected = tester.getSemantics(
        find.ancestor(
          of: find.byIcon(Icons.explore_rounded),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    });
  });
}
