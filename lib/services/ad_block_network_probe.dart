import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Checks transport filtering that leaves DNS answers intact. HEAD requests
/// never run an ad tag, follow a smartlink, or consume an impression.
class AdBlockNetworkProbe {
  AdBlockNetworkProbe({
    List<Uri>? adUrls,
    List<Uri>? controlUrls,
    http.Client Function()? clientFactory,
    this.requestTimeout = const Duration(milliseconds: 1400),
  })  : adUrls = adUrls ?? defaultAdUrls,
        controlUrls = controlUrls ?? defaultControlUrls,
        _clientFactory = clientFactory ?? http.Client.new;

  static final defaultAdUrls = [
    Uri.parse('https://pagead2.googlesyndication.com/robots.txt'),
    Uri.parse('https://ads.pubmatic.com/robots.txt'),
  ];
  static final defaultControlUrls = [
    Uri.parse('https://www.google.com/generate_204'),
    Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'),
  ];

  final List<Uri> adUrls;
  final List<Uri> controlUrls;
  final Duration requestTimeout;
  final http.Client Function() _clientFactory;

  Future<bool> isBlocking() async {
    // Require independent ad hosts; one provider being down is inconclusive.
    if (adUrls.map((url) => url.host).toSet().length < 2) return false;
    final controls = Future.wait(controlUrls.map(isReachable));
    final results = await Future.wait(adUrls.map((url) async {
      if (await _probe(url) != false) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return await _probe(url) == false;
    }));
    if (results.any((failedTwice) => !failedTwice)) return false;
    if (!(await controls).every((reachable) => reachable) ||
        controlUrls.map((url) => url.host).toSet().length < 2) {
      return false;
    }
    // A connection loss during the attempts must not reuse old healthy
    // controls as evidence of selective filtering.
    if (!(await Future.wait(controlUrls.map(isReachable)))
        .every((reachable) => reachable)) {
      return false;
    }
    debugPrint('[AdBlockDetector] repeated selective HTTPS filtering');
    return true;
  }

  /// Receiving any non-redirect HTTP response proves transport works, even
  /// for an unsupported HEAD (405), server outage (503), or missing robots.txt
  /// (404). TLS errors, timeouts and redirects are inconclusive.
  Future<bool> isReachable(Uri uri) async => await _probe(uri) == true;

  Future<bool?> _probe(Uri uri) async {
    final client = _clientFactory();
    try {
      final request = http.Request('HEAD', uri)
        ..followRedirects = false
        ..headers['cache-control'] = 'no-cache';
      final response = await client.send(request).timeout(requestTimeout);
      if (response.statusCode >= 300 && response.statusCode < 400) return null;
      return response.statusCode >= 200 && response.statusCode <= 599;
    } on SocketException {
      return false;
    } on http.ClientException catch (error) {
      final text = error.message.toLowerCase();
      return text.contains('connection reset') ||
              text.contains('connection refused') ||
              text.contains('connection closed')
          ? false
          : null;
    } catch (_) {
      return null;
    } finally {
      // Closing also aborts a request that outlives its timeout.
      client.close();
    }
  }
}
