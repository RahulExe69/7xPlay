import 'package:dio/dio.dart';
import 'package:flixquest/data/ads/ads_policy.dart';
import 'package:flixquest/data/models/billing.dart';
import 'package:flixquest/data/repositories/billing_repository.dart';
import 'package:flixquest/mobile/screens/plus_payment_screen.dart';
import 'package:flixquest/mobile/screens/plus_screen.dart';
import 'package:flixquest/mobile/screens/wallet_screen.dart';
import 'package:flixquest/mobile/widgets/plus_card.dart';
import 'package:flixquest/presentation/billing/plus_controller.dart';
import 'package:flixquest/tv/screens/tv_plus_screen.dart';
import 'package:flixquest/widgets/plus/plus_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/fakes.dart';
import 'support/tv_localization.dart';

final _now = DateTime.utc(2026, 10, 24, 7);

PlusAccount _member() => PlusAccount(
      entitlements: PlusEntitlement(
        adFree: true,
        startsAt: _now.subtract(const Duration(days: 8)),
        expiresAt: _now.add(const Duration(days: 23)),
      ),
      serverTime: _now,
      wallet: const WalletBalance(
          id: 'wallet-1',
          balanceCents: 800,
          spendableCents: 800,
          periodsFundable: 4),
      renewal: PlusRenewal(
        mode: 'wallet',
        autoRenew: true,
        nextChargeCents: 200,
        nextChargeAt: _now.add(const Duration(days: 23)),
        currentTermsVersion: '2026-10-24',
      ),
    );

PlusAccount _free({int spendable = 0}) => PlusAccount(
      serverTime: _now,
      wallet: WalletBalance(
          id: 'wallet-1',
          balanceCents: spendable,
          spendableCents: spendable,
          periodsFundable: spendable ~/ 200),
    );

const _pending = WalletTopup(
  id: 'topup-1',
  status: 'pending',
  amountCents: 1000,
  activatePlus: true,
  nextAction: 'open_checkout',
  checkoutUrl: 'https://nowpayments.io/payment/?iid=123',
);

class _Billing extends BillingRepository {
  _Billing(this.account) : super(Dio());

  PlusAccount account;

  @override
  Future<PlusCatalog> plans() async => const PlusCatalog(
        purchasesEnabled: true,
        plans: [
          PlusPlan(
              code: 'plus_monthly',
              amountCents: 200,
              intervalDays: 31,
              termsVersion: '2026-10-24'),
        ],
      );

  @override
  Future<PlusAccount> wallet() async => account;

  @override
  Future<PlusAccount> entitlements() async => account;

  @override
  Future<WalletHistoryPage> transactions({String? cursor}) async =>
      WalletHistoryPage([
        WalletTransaction(
          id: '2',
          type: 'plus_period',
          amountCents: -200,
          balanceAfterCents: 800,
          periodStartsAt: _now,
          periodEndsAt: _now.add(const Duration(days: 31)),
          createdAt: _now,
        ),
        WalletTransaction(
            id: '1',
            type: 'topup',
            amountCents: 1000,
            balanceAfterCents: 1000,
            createdAt: _now),
      ], null);

  @override
  Future<WalletTopup> topup(String id) async => _pending;

  @override
  Future<WalletTopup> reconcileTopup(String id) async => _pending;

  @override
  Future<(PlusAccount, CouponRedemption)> redeemCoupon(String code) async =>
      (_member(), const CouponRedemption(type: 'free_plus', freeDays: 14));
}

void main() {
  initializeTvTranslations();

  late ValueNotifier<String?> owner;
  late PlusController plus;

  Future<PlusController> controllerFor(PlusAccount? account) async {
    owner = ValueNotifier<String?>(account == null ? null : 'user:1');
    final controller = PlusController(
      repository: _Billing(account ?? _free()),
      store: FakeKvStore(),
      owner: owner,
      now: () => _now,
      pollInterval: const Duration(hours: 1),
    );
    await controller.start();
    await controller.refresh(full: true);
    await controller.refreshCatalog();
    return controller;
  }

  /// Unmounts the screens, then stops the controller's timers, so the test
  /// ends with none pending.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    plus.dispose();
    AdsPolicy.update(adFree: false);
  }

  Future<void> pump(WidgetTester tester, Widget child,
      {Size size = const Size(390, 844), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<PlusController>.value(
      value: plus,
      child: MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: child,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1500));
  }

  for (final (name, account) in <(String, PlusAccount? Function())>[
    ('a member', _member),
    ('a viewer with a balance', () => _free(spendable: 600)),
    ('a viewer without Plus', _free),
    ('a guest', () => null),
  ]) {
    for (final (label, size, scale) in <(String, Size, double)>[
      ('phone', const Size(390, 844), 1.0),
      ('small phone with large text', const Size(320, 640), 1.3),
    ]) {
      testWidgets('the Plus page lays out for $name on a $label',
          (tester) async {
        plus = await tester.runAsync(() => controllerFor(account()))
            as PlusController;
        await pump(tester, const Scaffold(body: PlusScreen()),
            size: size, textScale: scale);

        expect(tester.takeException(), isNull);
        expect(find.text('FlixQuest Plus'), findsWidgets);
        await done(tester);
      });
    }
  }

  testWidgets('a member sees days left and the renewal date', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_member())) as PlusController;
    await pump(tester, const PlusScreen());

    expect(find.text('23'), findsOneWidget);
    expect(find.text("You're ad-free"), findsOneWidget);
    expect(find.textContaining('Next renewal: \$2.00'), findsOneWidget);
    await done(tester);
  });

  testWidgets('My FlixQuest shows the member card and the invitation',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_member())) as PlusController;
    await pump(
        tester,
        const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: PlusCard())));
    expect(tester.takeException(), isNull);
    expect(find.text("You're ad-free"), findsOneWidget);

    await done(tester);
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    await pump(
        tester,
        const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: PlusCard())),
        size: const Size(320, 640),
        textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Watch without ads'), findsOneWidget);
    await done(tester);
  });

  testWidgets('the wallet lists periods and top-ups', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_member())) as PlusController;
    await pump(tester, const WalletScreen());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Plus period'), findsOneWidget);
    expect(find.text('+\$10.00'), findsOneWidget);
    expect(find.text('−\$2.00'), findsOneWidget);
    await done(tester);
  });

  testWidgets('the payment screen waits for Laravel, not the browser',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    plus.followTopup(_pending);
    await pump(tester, const PlusPaymentScreen(),
        size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);

    await pump(tester, const PlusPaymentScreen());
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Send the exact amount'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Open payment page'), 200);
    expect(find.text('Open payment page'), findsOneWidget);
    expect(find.text('Check payment'), findsOneWidget);
    await done(tester);
  });

  testWidgets('Android TV shows a QR code of the checkout', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    plus.followTopup(_pending);
    for (final size in const [Size(1920, 1080), Size(960, 540)]) {
      await pump(tester, const TvPlusScreen(), size: size);
      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    }
    plus.dismissTopup();
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Add funds'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await done(tester);
  });

  testWidgets('Plus that starts in the app is celebrated once', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    await pump(
        tester,
        const Stack(children: [
          Scaffold(body: SizedBox()),
          PlusCelebration(),
        ]));
    expect(find.text('Welcome to Plus'), findsNothing);

    await tester.runAsync(() => plus.redeemCoupon('WELCOME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Welcome to Plus'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Welcome to Plus'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Welcome to Plus'), findsNothing);
    await done(tester);
  });
}
