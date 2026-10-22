import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

typedef PlaybackBrowserLauncher = Future<bool> Function(Uri uri);

/// Prefer a full Chrome window, falling back to the device's external browser.
Future<bool> openPlaybackBrowser(Uri uri) async {
  if (!const {'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
    return false;
  }
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final opened =
          await const MethodChannel('dev.beamlak.flixquest/playback_ad_browser')
              .invokeMethod<bool>('openChrome', uri.toString());
      if (opened == true) return true;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final chrome = uri.replace(
          scheme: uri.scheme == 'https' ? 'googlechromes' : 'googlechrome');
      if (await canLaunchUrl(chrome) &&
          await launchUrl(chrome, mode: LaunchMode.externalApplication)) {
        return true;
      }
    }
  } on PlatformException {
    // Chrome is unavailable; let the device choose its external browser.
  } on MissingPluginException {
    // Hosts without the Android bridge still support a normal browser launch.
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
