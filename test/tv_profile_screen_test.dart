import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/mobile/widgets/verified_badge.dart';
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/screens/tv_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/session_harness.dart';
import 'support/tv_localization.dart';

/// Signs in a user the backend reports as verified, or not.
Future<SessionHarness> _signIn({required bool verified}) async {
  final harness = await SessionHarness.create();
  AuthRuntime.configure(harness.session);
  final body = authFixture();
  (body['user'] as Map)['isAccountVerified'] = verified;
  harness.adapter.enqueueJson(body);
  await harness.session.signIn(
    const LoginRequest(email: 'beamlak@example.com', password: 'secret123'),
  );
  return harness;
}

Future<void> _pumpProfile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TvProfileScreen(
        metrics: TvShellMetrics.fromConstraints(
          const BoxConstraints.tightFor(width: 960, height: 540),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  initializeTvTranslations();

  testWidgets('a verified account shows the tick after its name',
      (tester) async {
    final harness = await tester.runAsync(() => _signIn(verified: true));
    addTearDown(() => tester.runAsync(harness!.dispose));

    await _pumpProfile(tester);

    expect(find.text('Beamlak Aschalew'), findsOneWidget);
    expect(find.byType(VerifiedBadge), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(VerifiedBadge)).dx,
      greaterThan(tester.getTopRight(find.text('Beamlak Aschalew')).dx),
    );
  });

  testWidgets('an unverified account shows no tick', (tester) async {
    final harness = await tester.runAsync(() => _signIn(verified: false));
    addTearDown(() => tester.runAsync(harness!.dispose));

    await _pumpProfile(tester);

    expect(find.text('Beamlak Aschalew'), findsOneWidget);
    expect(find.byType(VerifiedBadge), findsNothing);
  });
}
