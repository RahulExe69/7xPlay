import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ad_block_network_probe.dart';

/// Exercises the same system WebView used by ads. It loads only local bait
/// elements and HEAD probes, never publisher tags or advertiser destinations.
class AdBlockWebViewProbe {
  static const _baseUrl = 'https://appassets.androidplatform.net/fq-probe/';
  static const channel = 'FqFilterProbe';
  static const timeout = Duration(milliseconds: 4500);

  static Future<bool> isBlocking(BuildContext context,
      {Future<bool> Function(Uri)? nativeReachable}) async {
    if (kIsWeb ||
        !const {TargetPlatform.android, TargetPlatform.iOS}
            .contains(defaultTargetPlatform)) {
      return false;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;
    WebViewController? controller;
    OverlayEntry? entry;
    final done = Completer<bool>();
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final blockedHosts = <String>{};
    final network = AdBlockNetworkProbe();
    Future<void> accept(String message) async {
      if (done.isCompleted || message.length > 4096) return;
      try {
        final report = jsonDecode(message);
        if (report is! Map || report['token'] != token) return;
        if (report['controls'] != true) {
          done.complete(false);
          return;
        }
        var blocked = report['cosmetic'] == true || blockedHosts.isNotEmpty;
        if (!blocked && report['failed'] is List) {
          final failed = (report['failed'] as List).whereType<String>().toSet();
          final urls = AdBlockNetworkProbe.defaultAdUrls
              .where((url) => failed.contains(url.host))
              .toList();
          // Two independent WebView-only failures, with those same resources
          // reachable through native HTTPS, rule out a provider outage.
          if (urls.map((url) => url.host).toSet().length >= 2) {
            blocked = (await Future.wait(
                    urls.map(nativeReachable ?? network.isReachable)))
                .every((reachable) => reachable);
          }
        }
        if (!done.isCompleted) done.complete(blocked);
      } catch (_) {
        // Malformed/incomplete reports are inconclusive.
      }
    }

    final timer = Timer(timeout, () {
      if (!done.isCompleted) done.complete(false);
    });
    Future<void> prepare() async {
      try {
        final webView = WebViewController();
        controller = webView;
        await webView.setJavaScriptMode(JavaScriptMode.unrestricted);
        await webView.addJavaScriptChannel(channel,
            onMessageReceived: (message) => unawaited(accept(message.message)));
        await webView.setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url == 'about:blank' || request.url == _baseUrl
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent,
          onWebResourceError: (error) {
            final host = Uri.tryParse(error.url ?? '')?.host;
            if (AdBlockNetworkProbe.defaultAdUrls
                    .any((url) => url.host == host) &&
                error.description.contains('ERR_BLOCKED_BY_CLIENT')) {
              blockedHosts.add(host!);
            }
          },
        ));
        if (done.isCompleted || !context.mounted) return;
        entry = OverlayEntry(
          builder: (_) => Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                    opacity: 0, child: WebViewWidget(controller: webView)),
              ),
            ),
          ),
        );
        overlay.insert(entry!);
        await webView.loadHtmlString(document(token), baseUrl: _baseUrl);
      } catch (_) {
        if (!done.isCompleted) done.complete(false);
      }
    }

    unawaited(prepare());
    try {
      final blocked = await done.future;
      if (blocked) debugPrint('[AdBlockDetector] WebView filtering confirmed');
      return blocked;
    } finally {
      timer.cancel();
      entry?.remove();
      entry?.dispose();
      try {
        await controller
            ?.loadRequest(Uri.parse('about:blank'))
            .timeout(const Duration(milliseconds: 200));
      } catch (_) {}
    }
  }

  @visibleForTesting
  static String document(String token) => '''<!doctype html><html><body>
<div id="fq-control" style="width:20px;height:20px">content</div>
<div id="ad_banner" class="adsbox ad-banner" style="width:20px;height:20px">ad</div>
<div id="fq-ad-bait" class="advertisement pub_300x250" style="width:20px;height:20px">ad</div>
<script>
const probeToken = ${jsonEncode(token)};
const adUrls = ${jsonEncode(AdBlockNetworkProbe.defaultAdUrls.map((url) => url.toString()).toList())};
const controlUrls = ${jsonEncode(AdBlockNetworkProbe.defaultControlUrls.map((url) => url.toString()).toList())};
$script
</script></body></html>''';

  @visibleForTesting
  static const script = r'''
(async function () {
  async function reachable(url) {
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 900);
    try {
      await fetch(url, {method: 'HEAD', mode: 'no-cors', credentials: 'omit',
        cache: 'no-store', signal: abort.signal});
      return true;
    } catch (_) { return false; }
    finally { clearTimeout(timer); }
  }
  function visible(id) {
    const element = document.getElementById(id);
    if (!element) return false;
    const style = getComputedStyle(element);
    return style.display !== 'none' && style.visibility !== 'hidden' &&
      Number(style.opacity) !== 0 && element.offsetHeight > 0 && element.offsetWidth > 0;
  }
  const controls = Promise.all(controlUrls.map(reachable));
  const failed = await Promise.all(adUrls.map(async (url) => {
    if (await reachable(url) || await reachable(url)) return null;
    return new URL(url).hostname;
  }));
  await new Promise(resolve => setTimeout(resolve, 350));
  const report = {token: probeToken, controls: (await controls).every(Boolean),
    cosmetic: visible('fq-control') && !visible('ad_banner') && !visible('fq-ad-bait'),
    failed: failed.filter(Boolean)};
  FqFilterProbe.postMessage(JSON.stringify(report));
})().catch(() => {});
''';
}
