import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Deployment configuration. Base URLs always end in `/api/v1/` for Dio.
class AppEnvironment {
  const AppEnvironment._(
      this.laravelApiUrl, this.debugLogging, this.oneSignalAppId);

  factory AppEnvironment.fromRuntime() => AppEnvironment.resolve(
        defineUrl: const String.fromEnvironment('LARAVEL_API_URL'),
        defineOneSignalAppId: const String.fromEnvironment('ONESIGNAL_APP_ID'),
        env: dotenv.isInitialized ? dotenv.env : const {},
        isDebug: kDebugMode,
      );

  factory AppEnvironment.resolve({
    String defineUrl = '',
    String defineOneSignalAppId = '',
    Map<String, String> env = const {},
    bool isDebug = false,
  }) {
    final configured = defineUrl.trim().isNotEmpty
        ? defineUrl.trim()
        : (env['LARAVEL_API_URL'] ?? '').trim();
    if (configured.isEmpty && !isDebug) {
      throw StateError(
          'LARAVEL_API_URL must be configured for release builds.');
    }
    final raw = configured.isEmpty ? 'http://10.0.2.2:8000' : configured;
    return AppEnvironment._(
      normalizeLaravelApiUrl(raw),
      isDebug,
      defineOneSignalAppId.trim().isNotEmpty
          ? defineOneSignalAppId.trim()
          : (env['ONESIGNAL_APP_ID'] ?? '').trim(),
    );
  }

  /// Shared validation for bundled and remotely supplied backend URLs.
  static String normalizeLaravelApiUrl(String value) {
    final raw = value.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(raw, 'LARAVEL_API_URL', 'Invalid API base URL');
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (!path.endsWith('/api/v1')) {
      path = '$path/api/v1';
    }
    return uri.replace(path: '$path/').toString();
  }

  final String laravelApiUrl;
  final bool debugLogging;

  /// Public OneSignal App ID; empty keeps push on the plain FCM client.
  final String oneSignalAppId;
  Duration get connectTimeout => const Duration(seconds: 10);
  Duration get receiveTimeout => const Duration(seconds: 20);
}
