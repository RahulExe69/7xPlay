import 'package:flixquest/experience/design/experience_palette.dart';
import 'package:flixquest/experience/design/experience_theme_extension.dart';
import 'package:flixquest/experience/widgets/experience_action.dart';
import 'package:flixquest/experience/widgets/experience_artwork.dart';
import 'package:flixquest/experience/widgets/experience_state_panel.dart';
import 'package:flixquest/experience/widgets/experience_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Size size = const Size(390, 844)}) {
  final theme = ThemeData.dark();
  final palette = ExperiencePalette.fromTheme(theme);
  return MaterialApp(
    theme: theme.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        ExperienceThemeExtension(palette: palette),
      ],
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: size.width - 32, child: child),
      ),
    ),
  );
}

void main() {
  group('ExperienceSurface', () {
    testWidgets('renders its content and invokes the tap action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          ExperienceSurface(
            onTap: () => taps++,
            child: const Text('A new 7xPlay surface'),
          ),
        ),
      );

      expect(find.text('A new 7xPlay surface'), findsOneWidget);
      await tester.tap(find.text('A new 7xPlay surface'));
      expect(taps, 1);
    });

    testWidgets('exposes a labelled non-interactive semantic container',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const ExperienceSurface(
            semanticLabel: 'Featured collection',
            child: Text('Collection'),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(ExperienceSurface));
      expect(semantics.label, 'Featured collection');
      expect(semantics.hasFlag(SemanticsFlag.isButton), isFalse);
    });
  });

  group('ExperienceAction', () {
    testWidgets('fires the primary action and exposes its label', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(
          ExperienceAction(
            label: 'Start watching',
            onPressed: () => calls++,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Start watching'), findsOneWidget);
      await tester.tap(find.text('Start watching'));
      expect(calls, 1);
    });

    testWidgets('shows progress and blocks taps while loading', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(
          ExperienceAction(
            label: 'Continue',
            isLoading: true,
            onPressed: () => calls++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(ElevatedButton));
      expect(calls, 0);
    });

    testWidgets('disabled actions cannot invoke their callback', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(ExperienceAction(label: 'Unavailable', onPressed: null)),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(calls, 0);
    });
  });

  group('ExperienceArtwork', () {
    testWidgets('renders a branded fallback when artwork is not supplied',
        (tester) async {
      await tester.pumpWidget(
        _app(const ExperienceArtwork(semanticLabel: 'Film poster')),
      );

      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('Film poster'), findsOneWidget);
    });

    testWidgets('renders the error fallback when image loading fails',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const ExperienceArtwork(
            semanticLabel: 'Unavailable poster',
            imageProvider: NetworkImage('https://example.invalid/poster.jpg'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('keeps its requested aspect ratio in a narrow viewport',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const ExperienceArtwork(aspectRatio: 16 / 9),
          size: const Size(320, 700),
        ),
      );

      final size = tester.getSize(find.byType(ExperienceArtwork));
      expect(size.width, 288);
      expect(size.height, closeTo(162, 0.01));
    });
  });

  group('ExperienceStatePanel', () {
    testWidgets('shows a progress state without an error action',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const ExperienceStatePanel(
            kind: ExperienceStateKind.loading,
            title: 'Finding something good',
          ),
        ),
      );

      expect(find.text('Finding something good'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('offers a retry action for recoverable error states',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _app(
          ExperienceStatePanel(
            kind: ExperienceStateKind.error,
            title: 'Could not load titles',
            description: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => retries++,
          ),
        ),
      );

      expect(find.text('Could not load titles'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('has distinct offline and empty-state semantics',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const ExperienceStatePanel(
            kind: ExperienceStateKind.offline,
            title: 'You are offline',
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      await tester.pumpWidget(
        _app(
          const ExperienceStatePanel(
            kind: ExperienceStateKind.empty,
            title: 'Nothing saved yet',
          ),
        ),
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });
  });
}
