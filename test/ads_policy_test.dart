import 'package:flixquest/data/ads/ads_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AdsPolicy.setForTesting(adFree: true));

  test('production entitlement updates cannot re-enable ads', () {
    AdsPolicy.setForTesting(adFree: false);

    AdsPolicy.update(adFree: false);

    expect(AdsPolicy.adFree, isTrue);
  });
}
