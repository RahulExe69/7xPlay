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

  test('new backend hosts become verified for already-created HTTP clients',
      () {
    final overrides = MyHttpOverrides(verifiedHosts: {'bundled.example'});
    final client = overrides.createHttpClient(null);
    addTearDown(() => client.close(force: true));
    expect(overrides.acceptsBadCertificate('remote.example'), isTrue);
    overrides.verifiedHosts.add('remote.example');
    // The callback reads the current host set rather than capturing a snapshot.
    expect(overrides.acceptsBadCertificate('remote.example'), isFalse);
    expect(overrides.acceptsBadCertificate('bundled.example'), isFalse);
  });
}
