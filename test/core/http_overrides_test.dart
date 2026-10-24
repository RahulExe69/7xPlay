import 'package:flixquest/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the FlixQuest API is always verified while media hosts are not', () {
    final overrides = MyHttpOverrides(verifiedHosts: {'Backend.Flix.Quest'});
    expect(overrides.acceptsBadCertificate('backend.flix.quest'), isFalse);
    expect(overrides.acceptsBadCertificate('BACKEND.flix.quest'), isFalse);
    expect(overrides.acceptsBadCertificate('cdn.stream-host.example'), isTrue);
    expect(overrides.acceptsBadCertificate('evil.backend.flix.quest.example'),
        isTrue);
  });
}
