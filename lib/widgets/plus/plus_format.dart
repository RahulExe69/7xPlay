import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/error/failure.dart';
import '../../data/repositories/billing_repository.dart';

/// "$8.00": Plus is priced and credited in US dollars in every language.
String formatUsd(int cents) {
  final sign = cents < 0 ? '−' : '';
  final value = cents.abs();
  return '$sign\$${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
}

/// "$2" for whole dollars, "$2.50" otherwise: for prices in running text.
String formatPrice(int cents) =>
    cents % 100 == 0 ? '\$${cents ~/ 100}' : formatUsd(cents);

final Set<String> _readyLocales = <String>{};

/// Loads date names for [context]'s language; dates read in English until
/// they arrive.
Future<void> prepareDates(BuildContext context) async {
  final locale = Localizations.localeOf(context).toString();
  if (_readyLocales.contains(locale)) return;
  try {
    await initializeDateFormatting(locale);
    _readyLocales.add(locale);
  } catch (_) {/* English dates remain. */}
}

/// "Nov 24, 2026" in the viewer's language and time zone.
String formatDay(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toString();
  final local = time.toLocal();
  try {
    if (_readyLocales.contains(locale)) {
      return DateFormat.yMMMd(locale).format(local);
    }
  } catch (_) {/* Falls through to English. */}
  return DateFormat.yMMMd('en_US').format(local);
}

/// Whole days left until [end], never below zero.
int daysLeft(DateTime now, DateTime end) {
  final seconds = end.difference(now).inSeconds;
  if (seconds <= 0) return 0;
  return (seconds / 86400).ceil();
}

/// What a billing error means for the viewer, in their language.
String billingMessage(BillingError error) {
  if (error.offline) return tr('plus_error_offline');
  final key = switch (error.code) {
    'wallet_insufficient_balance' => 'plus_error_insufficient_balance',
    'wallet_frozen' => 'plus_error_wallet_frozen',
    'billing_mode_conflict' => 'plus_error_mode_conflict',
    'terms_outdated' => 'plus_error_terms_outdated',
    'billing_unavailable' => 'plus_error_unavailable',
    'checkout_pending' => 'plus_error_checkout_pending',
    'idempotency_conflict' => 'plus_error_try_again',
    'provider_invalid_response' => 'plus_error_unavailable',
    'coupon_invalid' => 'plus_error_coupon_invalid',
    'coupon_exhausted' => 'plus_error_coupon_exhausted',
    'coupon_already_used' => 'plus_error_coupon_used',
    'discount_already_active' => 'plus_error_discount_active',
    'period_overlap' => 'plus_error_period_overlap',
    'sign_in_required' => 'plus_sign_in_required',
    'session_changed' => 'plus_error_try_again',
    _ => null,
  };
  if (key != null) return tr(key);
  if (error.failure is RateLimitedFailure) {
    return tr('plus_error_rate_limited');
  }
  return tr('plus_error_generic');
}

/// Only NOWPayments' own HTTPS pages open as a checkout, whatever a
/// response says.
bool isTrustedCheckout(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      const {'nowpayments.io', 'sandbox.nowpayments.io'}
          .contains(uri.host.toLowerCase());
}
