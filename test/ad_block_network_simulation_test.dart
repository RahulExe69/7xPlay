import 'dart:io';

import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flixquest/services/ad_block_network_probe.dart';
import 'package:flutter_test/flutter_test.dart';

// Run against the local Postman simulation; no real ad server is contacted.
void main() {
  final base = Platform.environment['FQ_AD_BLOCK_SIMULATION_URL'];
  final skip = base == null
      ? 'Start ad-block-probes.sim.yaml and set FQ_AD_BLOCK_SIMULATION_URL'
      : false;
  Uri endpoint(String path, {bool alternate = false}) {
    final uri = Uri.parse('$base/$path');
    return alternate ? uri.replace(host: 'localhost') : uri;
  }

  AdBlockNetworkProbe probe(String path, {bool offlineControls = false}) =>
      AdBlockNetworkProbe(
        adUrls: [endpoint(path), endpoint(path, alternate: true)],
        controlUrls: [
          endpoint(offlineControls ? 'hang' : 'healthy'),
          endpoint('healthy', alternate: true)
        ],
        requestTimeout: const Duration(milliseconds: 150),
      );

  test('real HTTP HEAD success allows playback', () async {
    expect(await probe('healthy').isBlocking(), isFalse);
  }, skip: skip);
  test('provider errors and missing resources are not blockers', () async {
    expect(await probe('error').isBlocking(), isFalse);
    expect(await probe('missing').isBlocking(), isFalse);
  }, skip: skip);
  test('redirects and timeouts are inconclusive', () async {
    expect(await probe('redirect').isBlocking(), isFalse);
    expect(await probe('hang').isBlocking(), isFalse);
  }, skip: skip);
  test('TLS handshake failures are inconclusive', () async {
    final check = AdBlockNetworkProbe(
      adUrls: [
        endpoint('healthy').replace(scheme: 'https'),
        endpoint('healthy', alternate: true).replace(scheme: 'https')
      ],
      controlUrls: [endpoint('healthy'), endpoint('healthy', alternate: true)],
    );
    expect(await check.isBlocking(), isFalse);
  }, skip: skip);
  test('repeated connection refusals with healthy controls detect filtering',
      () async {
    // Reserve then release a port so real sockets get ECONNREFUSED.
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final check = AdBlockNetworkProbe(
      adUrls: [
        Uri.parse('http://127.0.0.1:$port/ad'),
        Uri.parse('http://localhost:$port/ad')
      ],
      controlUrls: [endpoint('healthy'), endpoint('healthy', alternate: true)],
    );
    expect(await check.isBlocking(), isTrue);
    final offline = AdBlockNetworkProbe(
      adUrls: check.adUrls,
      controlUrls: [endpoint('hang'), endpoint('healthy', alternate: true)],
      requestTimeout: const Duration(milliseconds: 100),
    );
    expect(await offline.isBlocking(), isFalse);
  }, skip: skip);

  AdBlockDetector dnsDetector({bool brokenDnsResponse = false}) =>
      AdBlockDetector(
        publicResolvers: [
          endpoint(brokenDnsResponse ? 'hang' : 'dns').toString()
        ],
        lookup: (host) async {
          if (AdBlockDetector.dnsControlHosts.contains(host)) {
            return [InternetAddress('1.1.1.1')];
          }
          throw const SocketException('NXDOMAIN');
        },
      );
  test('real DNS JSON accepts IPv6-only public records', () async {
    expect(await dnsDetector().isBlocking({'ipv6.example'}), isTrue);
  }, skip: skip);
  test('retired domains, malformed DNS and stalled resolvers allow playback',
      () async {
    expect(await dnsDetector().isBlocking({'retired.example'}), isFalse);
    expect(await dnsDetector().isBlocking({'unreadable.example'}), isFalse);
    expect(
        await dnsDetector(brokenDnsResponse: true).isBlocking({'ipv6.example'}),
        isFalse);
  }, skip: skip);
}
