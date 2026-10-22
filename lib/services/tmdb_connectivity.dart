import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../functions/tmdb_request.dart';

/// Shared by both presentations and every TMDB entry point. A proxy route is
/// earned by an available network, two failed direct checks and a successful
/// TMDB response through the proxy.
class TmdbConnectivity extends ChangeNotifier {
  TmdbConnectivity({
    http.Client? client,
    Uri Function()? probeUri,
    DateTime Function()? now,
    Future<bool> Function()? hasNetwork,
    this.checkTimeout = const Duration(seconds: 4),
    this.requestTimeout = const Duration(seconds: 12),
  })  : _client = client,
        _probeUri = probeUri ??
            (() => Uri.parse(
                '$TMDB_API_BASE_URL/configuration?api_key=$TMDB_API_KEY')),
        _now = now ?? DateTime.now,
        _hasNetwork = hasNetwork ??
            (() async => (await Connectivity().checkConnectivity())
                .any((result) => result != ConnectivityResult.none));

  static TmdbConnectivity _instance = TmdbConnectivity();
  static TmdbConnectivity get instance => _instance;

  @visibleForTesting
  static set instance(TmdbConnectivity value) => _instance = value;

  /// App configuration can arrive while the initial route check is in flight.
  /// Read it at dispatch time rather than using a screen's captured URL.
  String Function()? proxyUrlSource;

  final http.Client? _client;
  final Uri Function() _probeUri;
  final DateTime Function() _now;
  final Future<bool> Function() _hasNetwork;
  bool? _networkAvailable;
  final Duration checkTimeout;
  final Duration requestTimeout;
  bool _proxyEnabled = false;
  bool _disabledForSession = false;
  bool _disposed = false;
  bool get proxyEnabled => _proxyEnabled;
  DateTime? _lastCheck;
  String? _checkedProxy;
  Uri? _checkedProbe;
  Future<void>? _checking;
  int _generation = 0;
  bool _reachable = false;
  int _checkRevision = 0;

  /// Losing the network also invalidates a check already in flight, so its
  /// earlier proxy response cannot enable a route after disconnection.
  void updateNetworkAvailability(bool available) {
    if (_disposed) return;
    _networkAvailable = available;
    _generation++;
    _lastCheck = null;
    if (!available) {
      _reachable = false;
      _setProxy(false);
    }
  }

  Future<bool> _hasUsableNetwork() async {
    if (_networkAvailable == false) return false;
    try {
      return await _hasNetwork().timeout(checkTimeout);
    } catch (_) {
      // Unknown network state must never authorize paid proxy usage.
      return false;
    }
  }

  void disableForSession() {
    _disabledForSession = true;
    _generation++;
    _setProxy(false);
  }

  void _setProxy(bool enabled) {
    if (_disposed || enabled == _proxyEnabled) return;
    _proxyEnabled = enabled;
    notifyListeners();
  }

  /// Startup, resume, reconnection and request failures share one check. Failed
  /// checks cool down for 30 seconds; healthy routes are rechecked after 5 min.
  Future<void> check(String proxyUrl, {bool networkChanged = false}) async {
    if (_disposed || _disabledForSession) return;
    proxyUrl = proxyUrlSource?.call() ?? proxyUrl;
    if (networkChanged) {
      _generation++;
      _lastCheck = null;
    }
    final pending = _checking;
    if (pending != null) {
      await pending;
      await check(proxyUrl);
      return;
    }
    final age = _lastCheck == null ? null : _now().difference(_lastCheck!);
    final lifetime =
        _reachable ? const Duration(minutes: 5) : const Duration(seconds: 30);
    if (_checkedProxy == proxyUrl &&
        _checkedProbe == _probeUri() &&
        age != null &&
        age < lifetime) {
      return;
    }

    final generation = _generation;
    final future = _check(proxyUrl, generation);
    _checking = future;
    try {
      await future;
    } finally {
      _checking = null;
    }
  }

  Future<void> _check(String proxyUrl, int generation) async {
    final direct = _probeUri();
    var reachable = false;
    var useProxy = false;
    if (await _hasUsableNetwork()) {
      reachable = await _probe(direct);
      if (!reachable &&
          !_disabledForSession &&
          _validProxy(proxyUrl) &&
          await _hasUsableNetwork() &&
          generation == _generation) {
        final proxyWorks = await _probe(
            tmdbRequestUri(direct.toString(), true, proxyUrl),
            requireSuccess: true);
        if (proxyWorks &&
            !_disabledForSession &&
            generation == _generation &&
            await _hasUsableNetwork()) {
          // The internet may have recovered during the first failed request.
          // Prefer direct access if that was only a transient interruption.
          reachable = await _probe(direct);
          useProxy = !reachable && await _hasUsableNetwork();
          reachable = reachable || useProxy;
        }
      }
    }
    if (_disposed || generation != _generation || _disabledForSession) return;
    _checkRevision++;
    _reachable = reachable;
    _checkedProxy = proxyUrl;
    _checkedProbe = direct;
    _lastCheck = _now();
    _setProxy(useProxy);
  }

  bool _validProxy(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<bool> _probe(Uri uri, {bool requireSuccess = false}) async {
    try {
      final response = await _send(uri, timeout: checkTimeout);
      final body = jsonDecode(response.body);
      // A TMDB error (bad key, missing record or rate limit) proves the host is
      // reachable too. An ISP's HTML block page does not.
      return body is Map<String, dynamic> &&
          ((response.statusCode == 200 && body['images'] is Map) ||
              (!requireSuccess &&
                  body['success'] == false &&
                  body['status_code'] is num));
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _send(Uri uri,
      {required Duration timeout, http.Client? client}) async {
    final sender = client ?? _client ?? http.Client();
    try {
      return await sender.get(uri).timeout(timeout);
    } finally {
      if (client == null && _client == null) sender.close();
    }
  }

  /// Automatically retry the interrupted request once after a route check.
  /// Never carry a caller's stale proxy flag across an automatic route change.
  Future<http.Response> get(String url, String proxyUrl,
      {http.Client? client, Duration? timeout}) async {
    proxyUrl = proxyUrlSource?.call() ?? proxyUrl;
    if (_proxyEnabled || _checking != null) await check(proxyUrl);
    proxyUrl = proxyUrlSource?.call() ?? proxyUrl;
    if (_lastCheck != null &&
        (_checkedProxy != proxyUrl || _checkedProbe != _probeUri())) {
      await check(proxyUrl);
    }
    final direct = Uri.parse(url);
    final proxied = _proxyEnabled;
    final checkRevision = _checkRevision;
    final request = tmdbRequestUri(url, proxied, proxyUrl);
    http.Response? response;
    Object? failure;
    StackTrace? failureStack;
    try {
      response = await _send(request,
          client: client, timeout: timeout ?? requestTimeout);
      if (!_looksBlocked(response)) return response;
    } catch (error, stack) {
      if (error is! IOException &&
          error is! TimeoutException &&
          error is! http.ClientException) {
        rethrow;
      }
      failure = error;
      failureStack = stack;
    }

    // A user switching the proxy off wins over checks already in flight.
    if (!_disabledForSession) {
      // Don't fan out fresh probes for concurrent failures or repeated offline
      // requests. A healthy route's first failure invalidates its cached check.
      if (_reachable && _checking == null && checkRevision == _checkRevision) {
        _lastCheck = null;
      }
      await check(proxyUrl);
      proxyUrl = proxyUrlSource?.call() ?? proxyUrl;
      if (_proxyEnabled != proxied || _reachable) {
        return _send(tmdbRequestUri(direct.toString(), _proxyEnabled, proxyUrl),
            client: client, timeout: timeout ?? requestTimeout);
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
    return response!;
  }

  bool _looksBlocked(http.Response response) {
    // Don't spend proxy traffic on ordinary API errors or server failures.
    if (response.statusCode == 429) return false;
    if (response.statusCode >= 500) {
      return response.body.trimLeft().startsWith('<');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> &&
          (response.statusCode < 400 ||
              (body['success'] == false && body['status_code'] is num))) {
        return false;
      }
    } on FormatException {
      // A successful HTTP connection can still be a filtering/block page.
    }
    return response.statusCode < 400 ||
        response.statusCode == 403 ||
        response.statusCode == 451;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
