import 'package:flixquest/design/app_brand.dart';
import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('ExperiencePalette.fromTheme', () {
    test('keeps 7xPlay brand actions while preserving a personal theme accent',
        () {
      const page = Color(0xFFFFFCF7);
      const personalAccent = Color(0xFF5D18B5);
      final base = ThemeData.light();
      final theme = base.copyWith(
        scaffoldBackgroundColor: page,
        colorScheme: base.colorScheme.copyWith(primary: personalAccent),
      );

      final palette = ExperiencePalette.fromTheme(theme);

      expect(palette.dark, isFalse);
      expect(palette.page, page);
      expect(palette.primaryAction, AppBrand.amber);
      expect(palette.onPrimaryAction, AppBrand.onAmber);
      expect(palette.secondaryAccent, AppBrand.hotPink);
      expect(palette.userAccent, personalAccent);
      expect(
        _contrastRatio(palette.foreground, palette.page),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(palette.onPrimaryAction, palette.primaryAction),
        greaterThanOrEqualTo(4.5),
      );
      expect(palette.surface, isNot(palette.page));
    });

    test('adapts foreground and focus roles to a dark cinematic theme', () {
      final theme = ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppBrand.background,
      );

      final palette = ExperiencePalette.fromTheme(theme);

      expect(palette.dark, isTrue);
      expect(palette.page, AppBrand.background);
      expect(
        _contrastRatio(palette.foreground, palette.page),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(palette.onFocus, palette.focusFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(palette.scrim(0.7).alpha, 179);
    });

    testWidgets('exposes an injected palette to UI descendants', (tester) async {
      final theme = ThemeData.dark();
      final palette = ExperiencePalette.fromTheme(theme);
      ExperiencePalette? resolved;
      final themed = theme.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          ExperienceThemeExtension(palette: palette),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: themed,
          home: Builder(
            builder: (context) {
              resolved = ExperienceThemeExtension.of(context).palette;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, same(palette));
    });

    test('interpolates semantic colors when a theme transitions', () {
      final darkTheme = ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      );
      final lightTheme = ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
      );
      final start = ExperienceThemeExtension(
        palette: ExperiencePalette.fromTheme(darkTheme),
      );
      final end = ExperienceThemeExtension(
        palette: ExperiencePalette.fromTheme(lightTheme),
      );

      final middle = start.lerp(end, 0.5);

      expect(middle.palette.page.computeLuminance(), greaterThan(0));
      expect(middle.palette.page.computeLuminance(), lessThan(1));
    });

    test('adjusts a low-contrast user accent without changing brand actions',
        () {
      final base = ThemeData.light();
      final theme = base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFFFFFF66),
        ),
      );

      final palette = ExperiencePalette.fromTheme(theme);

      expect(
        _contrastRatio(palette.userAccent, palette.page),
        greaterThanOrEqualTo(4.5),
      );
      expect(palette.primaryAction, AppBrand.amber);
      expect(palette.onPrimaryAction, AppBrand.onAmber);
    });
  });
}
