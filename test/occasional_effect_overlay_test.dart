import 'dart:ui' as ui;

import 'package:flixquest/models/occasional_theme.dart';
import 'package:flixquest/widgets/occasional_effect_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Adey flowers use seven petals', () {
    expect(OccasionalEffectOverlay.adeyFlowerPetalCount, 7);
  });

  final theme = OccasionalTheme.fromJson(<String, dynamic>{
    'id': 'christmas',
    'enabled': true,
    'effect': <String, dynamic>{
      'enabled': true,
      'type': 'snow',
    },
  });

  testWidgets('renders a non-interactive vector effect when enabled',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: OccasionalEffectOverlay(theme: theme, enabled: true),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('occasional-effect-canvas')), findsOneWidget);
    expect(find.byType(IgnorePointer), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('does not render when reduced motion is requested',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: OccasionalEffectOverlay(theme: theme, enabled: true),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('occasional-effect-canvas')), findsNothing);
  });

  testWidgets('TV rendering uses overrides and updates with remote values',
      (tester) async {
    final canvasKey = GlobalKey();
    Future<List<int>> render(Map<String, dynamic> effect,
        {required bool television}) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: canvasKey,
              child: OccasionalEffectOverlay(
                television: television,
                enabled: true,
                theme: OccasionalTheme.fromJson(<String, dynamic>{
                  'id': 'new_year',
                  'enabled': true,
                  'effect': <String, dynamic>{
                    'enabled': true,
                    'type': 'confetti',
                    ...effect,
                  },
                }),
              ),
            ),
          ),
        ),
      );
      final boundary =
          canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final data =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          return data!.buffer.asUint8List().toList();
        } finally {
          image.dispose();
        }
      }))!;
    }

    final config = <String, dynamic>{
      'density': 32,
      'speed': 1.2,
      'opacity': .8,
      'tv_density': 10,
      'tv_speed': .5,
      'tv_opacity': .4,
    };
    final tv = await render(config, television: true);
    final expectedTv = await render(<String, dynamic>{
      'density': 10,
      'speed': .5,
      'opacity': .4,
    }, television: false);
    expect(tv, expectedTv);
    final mobile = await render(config, television: false);
    expect(mobile, isNot(tv));
    final updatedTv = await render(<String, dynamic>{
      ...config,
      'tv_density': 20,
    }, television: true);
    expect(updatedTv, isNot(tv));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live visibility suppression clears the effect canvas',
      (tester) async {
    final visibility = ValueNotifier<bool>(true);
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: OccasionalEffectOverlay(
              theme: theme,
              enabled: true,
              visibilityListenable: visibility,
              visibilityResolver: () => visibility.value,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('occasional-effect-canvas')), findsOneWidget);
    visibility.value = false;
    await tester.pump();
    expect(find.byKey(const Key('occasional-effect-canvas')), findsNothing);
  });

  testWidgets('renders leaves with Easter treats and Ethiopian Adey flowers',
      (tester) async {
    for (final id in <String>['easter', 'ethiopian_new_year']) {
      final occasionalTheme = OccasionalTheme.fromJson(<String, dynamic>{
        'id': id,
        'enabled': true,
        'effect': <String, dynamic>{'enabled': true},
      });
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.expand(
              child: OccasionalEffectOverlay(
                theme: occasionalTheme,
                enabled: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('occasional-effect-canvas')), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('animation clock stays continuous across controller repeats',
      (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 12),
    );
    final clock = ContinuousEffectClock(controller);

    controller.value = .98;
    expect(clock.value, closeTo(.98, .0001));
    controller.value = .02;
    expect(clock.value, closeTo(1.02, .0001));
    controller.value = .5;
    expect(clock.value, closeTo(1.5, .0001));

    clock.dispose();
    controller.dispose();
  });
}
