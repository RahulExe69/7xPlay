import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/data/models/billing.dart';
import 'package:flixquest/data/repositories/billing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_dio.dart';

/// The shapes Laravel's BillingController and WalletController return.
Map<String, dynamic> walletBody({
  bool adFree = true,
  int spendable = 800,
  List<Map<String, dynamic>> pending = const [],
}) =>
    {
      'success': true,
      'entitlements': {
        'ad_free': adFree,
        'starts_at': '2026-10-24T06:39:17.000000Z',
        'expires_at': '2026-11-24T06:39:17.000000Z',
        'revision': 3,
      },
      'server_time': '2026-10-24T07:00:00.000000Z',
      'refresh_after_seconds': 300,
      'wallet': {
        'id': '9f1c2d3e-0000-4000-8000-000000000001',
        'currency': 'USD',
        'balance_cents': spendable,
        'spendable_cents': spendable,
        'status': 'active',
        'frozen': false,
        'revision': 2,
        'periods_fundable': spendable ~/ 200,
      },
      'subscription': {
        'mode': 'wallet',
        'auto_renew': true,
        'next_charge_cents': 200,
        'next_charge_at': '2026-11-24T06:39:17.000000Z',
        'lapsed_at': null,
        'cancelled_at': null,
        'amount_cents': 200,
        'interval_days': 31,
        'terms_version': '2026-10-24',
        'current_terms_version': '2026-10-24',
        'terms_outdated': false,
        'discount': null,
        'last_error_code': null,
      },
      'pending_topups': pending,
    };

Map<String, dynamic> topupJson({String status = 'pending'}) => {
      'id': '0b7c8f8e-1111-4000-8000-000000000002',
      'status': status,
      'amount_cents': 1000,
      'credited_cents': status == 'settled' ? 1000 : 0,
      'currency': 'USD',
      'activate_plus': true,
      'next_action': status == 'pending' ? 'open_checkout' : 'none',
      'checkout_url':
          status == 'pending' ? 'https://nowpayments.io/payment/?iid=1' : null,
      'pay_currency': null,
      'error_code': null,
      'created_at': '2026-10-24T07:00:00.000000Z',
      'credited_at': null,
    };

void main() {
  late Dio dio;
  late FakeDioAdapter adapter;
  late BillingRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    repository = BillingRepository(dio);
  });
  tearDown(() => dio.close());

  test('reads the account with access, renewal and balance kept apart',
      () async {
    adapter.enqueueJson(walletBody(pending: [topupJson()]));

    final account = await repository.wallet();

    expect(adapter.requests.single.path, 'wallet');
    expect(adapter.requests.single.extra['cachePolicy'], CachePolicy.noStore);
    expect(adapter.requests.single.extra['authRequired'], isTrue);
    expect(account.entitlements.adFree, isTrue);
    expect(
        account.entitlements.expiresAt, DateTime.utc(2026, 11, 24, 6, 39, 17));
    expect(account.wallet!.spendableCents, 800);
    expect(account.wallet!.periodsFundable, 4);
    expect(account.renewal!.autoRenew, isTrue);
    expect(account.renewal!.nextChargeCents, 200);
    expect(account.pendingTopups.single.isOpen, isTrue);
    expect(account.serverTime, DateTime.utc(2026, 10, 24, 7));
  });

  test('an older server without renewal or wallet fields still parses',
      () async {
    adapter.enqueueJson({
      'success': true,
      'entitlements': {'ad_free': false},
    });

    final account = await repository.entitlements();

    expect(account.entitlements.adFree, isFalse);
    expect(account.entitlements.expiresAt, isNull);
    expect(account.renewal, isNull);
    expect(account.wallet, isNull);
    expect(account.refreshAfterSeconds, 300);
  });

  test('the public catalog needs no sign-in', () async {
    adapter.enqueueJson({
      'success': true,
      'purchases_enabled': true,
      'plans': [
        {
          'code': 'plus_monthly',
          'name': 'FlixQuest Plus',
          'feature': 'ad_free',
          'amount_cents': 200,
          'currency': 'USD',
          'interval_days': 31,
          'terms_version': '2026-10-24',
          'funding_modes': ['wallet'],
        }
      ],
      'wallet': {
        'topup_min_cents': 200,
        'topup_max_cents': 50000,
        'suggested_topups_cents': [500, 1000, 2000],
      },
    });

    final catalog = await repository.plans();

    expect(adapter.requests.single.extra['authRequired'], isFalse);
    expect(catalog.purchasesEnabled, isTrue);
    expect(catalog.plan!.intervalDays, 31);
    expect(catalog.wallet.suggestedCents, [500, 1000, 2000]);
  });

  test('a top-up sends only the amount, the key and an explicit consent',
      () async {
    adapter
        .enqueueJson({'success': true, 'topup': topupJson()}, statusCode: 201);

    final topup = await repository.createTopup(
      amountCents: 1000,
      idempotencyKey: 'key-1',
      activatePlus: true,
      termsVersion: '2026-10-24',
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, 'wallet/topups');
    expect(jsonDecode(jsonEncode(request.data)), {
      'amount_cents': 1000,
      'idempotency_key': 'key-1',
      'activate_plus': true,
      'terms_version': '2026-10-24',
    });
    expect(topup.nextAction, 'open_checkout');
    expect(topup.checkoutUrl, startsWith('https://nowpayments.io/'));
  });

  test('a plain top-up does not ask to start Plus', () async {
    adapter.enqueueJson({'success': true, 'topup': topupJson()});

    await repository.createTopup(amountCents: 500, idempotencyKey: 'key-2');

    expect(adapter.requests.single.data,
        {'amount_cents': 500, 'idempotency_key': 'key-2'});
  });

  test('billing failures keep their stable code', () async {
    adapter.enqueueJson({
      'success': false,
      'message': 'Your FlixQuest balance does not cover the next Plus period.',
      'code': 'wallet_insufficient_balance',
    }, statusCode: 409);

    await expectLater(
      repository.enableWalletRenewal('2026-10-24'),
      throwsA(isA<BillingError>()
          .having((e) => e.code, 'code', 'wallet_insufficient_balance')
          .having((e) => e.failure, 'failure', isA<ConflictFailure>())),
    );
    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.data,
        {'auto_renew': true, 'terms_version': '2026-10-24'});
  });

  test('an unreachable server reads as offline, not as a billing answer',
      () async {
    adapter.enqueueError();

    await expectLater(
      repository.wallet(),
      throwsA(isA<BillingError>().having((e) => e.offline, 'offline', isTrue)),
    );
  });

  test('a malformed answer is an error, never a grant', () async {
    adapter.enqueueJson({'success': true, 'topup': 'nope'});

    await expectLater(repository.topup('x'), throwsA(isA<BillingError>()));
  });

  test('coupon redemption returns the account and what the code did', () async {
    adapter.enqueueJson({
      ...walletBody(),
      'redemption': {
        'type': 'free_plus',
        'free_days': 14,
        'percent_off': null,
        'amount_off_cents': null,
        'discount_periods': null,
        'summary': '14 days of Plus',
      },
    });

    final (account, redemption) = await repository.redeemCoupon('  WELCOME ');

    expect(adapter.requests.single.data, {'code': 'WELCOME'});
    expect(account.entitlements.adFree, isTrue);
    expect(redemption.freeDays, 14);
  });

  test('history pages carry the period a debit paid for', () async {
    adapter.enqueueJson({
      'success': true,
      'transactions': [
        {
          'id': 12,
          'type': 'plus_period',
          'amount_cents': -200,
          'balance_after_cents': 800,
          'reference': 4,
          'period': {
            'starts_at': '2026-10-24T06:39:17.000000Z',
            'ends_at': '2026-11-24T06:39:17.000000Z',
          },
          'created_at': '2026-10-24T06:39:17.000000Z',
        },
        {
          'id': 11,
          'type': 'topup',
          'amount_cents': 1000,
          'balance_after_cents': 1000,
          'reference': '0b7c8f8e-1111-4000-8000-000000000002',
          'created_at': '2026-10-24T06:30:00.000000Z',
        },
      ],
      'next_cursor': 'abc',
    });

    final page = await repository.transactions();

    expect(page.nextCursor, 'abc');
    expect(page.transactions.first.reference, '4');
    expect(page.transactions.first.periodEndsAt,
        DateTime.utc(2026, 11, 24, 6, 39, 17));
    expect(page.transactions.last.periodStartsAt, isNull);
  });

  test('idempotency keys are version 4 UUIDs', () {
    final key = newIdempotencyKey(Random(1));
    expect(
      key,
      matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
    expect(newIdempotencyKey(), isNot(newIdempotencyKey()));
  });

  test('suggested amounts outside the allowed range are never offered', () {
    // Production on 24 Oct 2026: $5 minimum, suggestions from $2.
    const limits = TopupLimits(
        minCents: 500,
        maxCents: 20000,
        suggestedCents: [200, 400, 600, 800, 1000, 1000, 50000]);
    expect(limits.offeredCents, [600, 800, 1000]);
    expect(const TopupLimits(minCents: 500, suggestedCents: [200]).offeredCents,
        [500]);
  });
}
