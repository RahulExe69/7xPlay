import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/screens/user/password_change.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/mobile/widgets/account_form.dart';
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/presentation/session/session_gate.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/landing_screen.dart';
import 'package:flixquest/screens/user/login_screen.dart';
import 'package:flixquest/screens/user/signup_screen.dart';
import 'package:flixquest/screens/user/forgot_password.dart';
import 'package:flixquest/services/auth_session_controller.dart';
import 'package:flixquest/services/in_app_messaging_service.dart';
import 'package:flixquest/translations/codegen_loader.g.dart';
import 'package:flixquest/tv/screens/tv_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../support/session_harness.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'FigtreeBold': 'Figtree-ExtraBold.ttf',
      'FigtreeSB': 'Figtree-Bold.ttf',
      'Figtree': 'Figtree-Medium.ttf'
    }.entries) {
      await (FontLoader(font.key)
            ..addFont(rootBundle.load('assets/fonts/Figtree/${font.value}')))
          .load();
    }
  });
  late SessionHarness h;
  Future<void> prepare() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=http://scraper.test\n');
    h = await SessionHarness.create();
    await EasyLocalization.ensureInitialized();
    AuthRuntime.configure(h.session);
    AuthSessionController.instance.initialize();
    await h.session.restore();
  }

  void authTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await prepare();
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await h.dispose();
      }
    });
  }

  Future<void> pumpPage(WidgetTester tester, Widget page,
      {bool gate = false, Size size = const Size(1000, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: EasyLocalization(
            supportedLocales: const [Locale('en')],
            path: 'assets/translations',
            assetLoader: const CodegenLoader(),
            saveLocale: false,
            child: Builder(
                builder: (context) => MaterialApp(
                      navigatorKey: InAppMessagingService.navigatorKey,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      home: gate
                          ? SessionGate(
                              session: h.session,
                              builder: (context, canBrowse) => canBrowse
                                  ? const Scaffold(body: Text('account home'))
                                  : page)
                          : page,
                    )))));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byType(AccountSubmitButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> loginFields(WidgetTester tester) async {
    await tester.enterText(
        find.byKey(const ValueKey('email')), 'beamlak@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('Password')), ' secret123 ');
  }

  authTest(
      'phone login succeeds, retains password whitespace and shows the account shell',
      (tester) async {
    h.adapter.enqueueJson(authFixture());
    await pumpPage(tester, const LoginScreen(), gate: true);
    await loginFields(tester);
    await submit(tester);
    expect(find.text('account home'), findsOneWidget);
    expect(h.tokens.value, '7|sanitized-test-token');
    expect((h.adapter.requests.single.data as Map)['password'], ' secret123 ');
    expect(tester.takeException(), null);
  });
  authTest('phone login 401 shows a credential error and keeps the form usable',
      (tester) async {
    h.adapter.enqueueJson({'success': false, 'message': 'Invalid credentials'},
        statusCode: 401);
    await pumpPage(tester, const LoginScreen());
    await loginFields(tester);
    await submit(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(h.session.user, null);
    expect(find.byType(AccountSubmitButton), findsOneWidget);
    expect(tester.takeException(), null);
  });
  authTest('signup checks username availability before posting registration',
      (tester) async {
    h.adapter.enqueueJson({'success': true, 'available': false});
    await pumpPage(tester, const SignupScreen());
    for (final entry in {
      'name': 'Test User',
      'email': 'test@example.com',
      'username': 'taken_name',
      'Password': 'secret123',
      'VerifyPassword': 'secret123'
    }.entries) {
      final field = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await submit(tester);
    expect(h.adapter.requests.single.uri.path, '/api/v1/users/check-username');
    expect(find.byType(Dialog), findsOneWidget);
    expect(h.tokens.value, null);
    expect(tester.takeException(), null);
  });
  authTest('forgot password posts the email and shows the reset-email notice',
      (tester) async {
    h.adapter.enqueueJson({'success': true, 'message': 'Reset sent'});
    await pumpPage(tester, const ForgotPasswordScreen());
    await tester.enterText(
        find.byKey(const ValueKey('email')), 'TEST@example.com');
    await submit(tester);
    expect(h.adapter.requests.single.uri.path, '/api/v1/auth/forgot-password');
    expect(h.adapter.requests.single.data, {'email': 'test@example.com'});
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), null);
  });
  authTest('session expiry removes account routes and shows the landing gate',
      (tester) async {
    h.adapter.enqueueJson(authFixture());
    await pumpPage(tester, const LoginScreen(), gate: true);
    await loginFields(tester);
    await submit(tester);
    InAppMessagingService.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('account overlay'))));
    await tester.pumpAndSettle();
    h.adapter.enqueueJson({'success': false}, statusCode: 401);
    final expiry = h.session.repository.profile();
    var completed = false;
    expiry.whenComplete(() => completed = true);
    for (var frame = 0; frame < 30 && !completed; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(completed, true);
    await expiry;
    await tester.pumpAndSettle();
    expect(find.text('account overlay'), findsNothing);
    expect(find.text('account home'), findsNothing);
    expect(find.byType(LaravelLoginScreen), findsOneWidget);
    expect(h.tokens.value, null);
  });
  authTest('switching accounts dismisses an already-open private message',
      (tester) async {
    h.adapter.enqueueJson(authFixture());
    await pumpPage(tester, const LoginScreen(), gate: true);
    await loginFields(tester);
    await submit(tester);
    final navigator = InAppMessagingService.navigatorKey.currentState!;
    ScaffoldMessenger.of(navigator.context).showMaterialBanner(MaterialBanner(
      content: const Text('private account banner'),
      actions: [TextButton(onPressed: () {}, child: const Text('Close'))],
    ));
    showDialog<void>(
        context: navigator.context,
        builder: (_) =>
            const AlertDialog(content: Text('private account message')));
    await tester.pumpAndSettle();
    expect(find.text('private account message'), findsOneWidget);
    h.adapter.enqueueJson(authFixture(id: 8, token: 'new-account-token'));
    final signIn = h.session.signIn(
        const LoginRequest(email: 'other@example.com', password: 'password'));
    var completed = false;
    signIn.whenComplete(() => completed = true);
    for (var frame = 0; frame < 30 && !completed; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(completed, true);
    await signIn;
    await tester.pumpAndSettle();
    expect(h.session.ownerId.value, 'user:8');
    expect(find.text('private account message'), findsNothing);
    expect(find.text('private account banner'), findsNothing);
    expect(find.text('account home'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  authTest('guest can enter the app from the phone landing page offline',
      (tester) async {
    await pumpPage(tester, const LandingScreen(), gate: true);
    final guest = find.text(tr('continue_anonymously'));
    await tester.ensureVisible(guest);
    await tester.tap(guest);
    await tester.pumpAndSettle();
    expect(find.text('account home'), findsOneWidget);
    // Only the guest account request goes out; offline, it fails silently.
    expect(h.adapter.requests.map((r) => r.path), ['auth/guest']);
    expect(h.session.ownerId.value, null);
    expect(h.session.accountId.value, null);
    expect(tester.takeException(), null);
  });
  authTest(
      'successful password change expires the revoked token and routes to landing',
      (tester) async {
    h.adapter.enqueueJson(authFixture());
    await pumpPage(tester, const LoginScreen(), gate: true);
    await loginFields(tester);
    await submit(tester);
    InAppMessagingService.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const PasswordChangeScreen()));
    await tester.pumpAndSettle();
    for (final field in {
      'currentPassword': ' secret123 ',
      'newPassword': ' newsecret123 ',
      'verifyPassword': ' newsecret123 '
    }.entries) {
      await tester.enterText(find.byKey(ValueKey(field.key)), field.value);
    }
    h.adapter.enqueueJson({'success': true});
    await submit(tester);
    expect(h.tokens.value, null);
    expect(find.byType(LaravelPasswordChangeScreen), findsNothing);
    expect(find.byType(LaravelLoginScreen), findsOneWidget);
    expect(h.adapter.requests.last.data,
        {'current_password': ' secret123 ', 'password': ' newsecret123 '});
    expect(tester.takeException(), null);
  });
  Future<void> typeOnTv(WidgetTester tester, String text) async {
    for (final character in text.split('')) {
      final lower = character.toLowerCase();
      if (character != lower) {
        await tester.tap(find.byKey(const ValueKey('tv-form-key-shift')));
        await tester.pump();
      }
      await tester.tap(find.byKey(ValueKey('tv-form-key-$lower')));
      await tester.pump();
    }
  }

  Future<void> pressTvAction(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tv-form-key-action')));
    await tester.pumpAndSettle();
  }

  authTest('TV auth signs in with the on-screen keyboard, field by field',
      (tester) async {
    h.adapter.enqueueJson(authFixture());
    await pumpPage(tester, const TvAuthScreen.signIn(), gate: true);
    await typeOnTv(tester, 'Beamlak@example.com');
    expect(find.text('Beamlak@example.com'), findsOneWidget);
    await pressTvAction(tester);
    await typeOnTv(tester, 'secret123');
    expect(find.text('secret123'), findsNothing);
    await pressTvAction(tester);
    expect(h.session.user?.id, 7);
    expect(find.text('account home'), findsOneWidget);
    expect((h.adapter.requests.single.data as Map)['email'],
        'beamlak@example.com');
    expect(tester.takeException(), null);
  });
  authTest('TV sign-in and sign-up fit a 1080p TV screen', (tester) async {
    // 1920x1080 at density 2, as Android TV lays it out.
    for (final page in const <Widget>[
      TvAuthScreen.signIn(),
      TvAuthScreen.createAccount(),
    ]) {
      await pumpPage(tester, page, size: const Size(960, 540));
      expect(find.byKey(const ValueKey('tv-form-key-action')), findsOneWidget);
      expect(tester.takeException(), null);
    }
  });
  authTest('TV sign-up names what is missing instead of sending the form',
      (tester) async {
    await pumpPage(tester, const TvAuthScreen.createAccount());
    for (var field = 0; field < 4; field++) {
      await pressTvAction(tester);
    }
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Use at least 7 characters.'), findsWidgets);
    expect(h.adapter.requests, isEmpty);
    expect(tester.takeException(), null);
  });
}
