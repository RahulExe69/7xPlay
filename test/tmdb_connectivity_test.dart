import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/services/tmdb_connectivity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Actual HTTP dependencies, with independently controllable direct and proxy
/// responses. No request is sent to TMDB or to a paid proxy.
class _Network {
  late HttpServer server;
  bool blocked = false;
  int blockedStatus = 451;
  bool recoverAfterDirectFailure = false;
  bool proxyDown = false;
  bool offline = false;
  int directStatus = 200;
  int proxyChecks = 0;
  int directChecks = 0;
  int proxyRequests = 0;
  int directRequests = 0;
  Completer<void>? holdDirect;
  Completer<void>? holdProxy;
  Completer<void>? proxyCheckStarted;
  String get base => 'http://127.0.0.1:${server.port}';
  String get proxy => '$base/proxy';
  String get title => '$base/direct/3/movie/1';
  Uri get configuration => Uri.parse('$base/direct/3/configuration');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final proxied = request.uri.path == '/proxy';
      final destination = proxied
          ? Uri.parse(request.uri.queryParameters['destination']!)
          : request.uri;
      final check = destination.path.endsWith('/configuration');
      if (proxied) {
        check ? proxyChecks++ : proxyRequests++;
      } else {
        check ? directChecks++ : directRequests++;
      }
      if (proxied && check) {
        proxyCheckStarted?.complete();
        if (holdProxy != null) await holdProxy!.future;
      }
      if (!proxied && check && holdDirect != null) {
        await holdDirect!.future;
      }
      if (offline || (proxied && proxyDown)) {
        request.response.statusCode = 503;
        request.response.write('offline');
      } else if (!proxied && blocked) {
        request.response.statusCode = blockedStatus;
        request.response.write('<html>Blocked by ISP</html>');
        if (recoverAfterDirectFailure) blocked = false;
      } else {
        request.response.statusCode = proxied ? 200 : directStatus;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(directStatus == 200 || proxied
            ? (check ? {'images': <String, dynamic>{}} : {'id': 1})
            : {'success': false, 'status_code': 7}));
      }
      await request.response.close();
    });
  }
}

void main() {
  late _Network network;
  late TmdbConnectivity connectivity;
  late TmdbConnectivity original;
  late DateTime now;
  late bool hasNetwork;

  setUp(() async {
    network = _Network();
    await network.start();
    now = DateTime(2026, 10, 21);
    hasNetwork = true;
    connectivity = TmdbConnectivity(
      hasNetwork: () async => hasNetwork,
      probeUri: () => network.configuration,
      now: () => now,
      checkTimeout: const Duration(milliseconds: 150),
      requestTimeout: const Duration(milliseconds: 200),
    );
    original = TmdbConnectivity.instance;
    TmdbConnectivity.instance = connectivity;
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    connectivity.dispose();
    TmdbConnectivity.instance = original;
    await network.server.close(force: true);
  });

  test('no network never probes TMDB or the paid proxy', () async {
    hasNetwork = false;
    await connectivity.check(network.proxy);
    expect(connectivity.proxyEnabled, isFalse);
    expect(network.directChecks, 0);
    expect(network.proxyChecks, 0);
    expect(network.proxyRequests, 0);
  });

  test('Wi-Fi without internet does not authorize proxy mode', () async {
    // The interface is connected, but neither route can return TMDB data.
    network.offline = true;
    final modes = <bool>[];
    connectivity.addListener(() => modes.add(connectivity.proxyEnabled));
    await connectivity.check(network.proxy);
    expect(connectivity.proxyEnabled, isFalse);
    expect(modes, isEmpty);
    expect(network.proxyChecks, 1);
    expect(network.proxyRequests, 0);
  });

  test(
      'a temporary connection failure recovers directly without enabling proxy',
      () async {
    network.blocked = true;
    network.recoverAfterDirectFailure = true;
    final modes = <bool>[];
    connectivity.addListener(() => modes.add(connectivity.proxyEnabled));
    await connectivity.check(network.proxy);
    expect(connectivity.proxyEnabled, isFalse);
    expect(modes, isEmpty);
    expect(network.directChecks, 2);
    expect(network.proxyChecks, 1);
    expect(network.proxyRequests, 0);
  });

  test('network loss invalidates a successful proxy response in flight',
      () async {
    network.blocked = true;
    network.holdProxy = Completer<void>();
    network.proxyCheckStarted = Completer<void>();
    final modes = <bool>[];
    connectivity.addListener(() => modes.add(connectivity.proxyEnabled));
    final checking = connectivity.check(network.proxy);
    await network.proxyCheckStarted!.future;
    hasNetwork = false;
    connectivity.updateNetworkAvailability(false);
    network.holdProxy!.complete();
    await checking;
    expect(connectivity.proxyEnabled, isFalse);
    expect(modes, isEmpty);
    expect(network.proxyRequests, 0);
  });

  test('disconnect clears active proxy mode and reconnect rechecks it',
      () async {
    network.blocked = true;
    await connectivity.check(network.proxy);
    expect(connectivity.proxyEnabled, isTrue);
    hasNetwork = false;
    connectivity.updateNetworkAvailability(false);
    expect(connectivity.proxyEnabled, isFalse);
    final proxyChecks = network.proxyChecks;
    await connectivity.check(network.proxy);
    expect(network.proxyChecks, proxyChecks);
    hasNetwork = true;
    network.blocked = false;
    connectivity.updateNetworkAvailability(true);
    await connectivity.check(network.proxy);
    expect(connectivity.proxyEnabled, isFalse);
    expect(network.proxyChecks, proxyChecks);
  });

  test('healthy startup checks once without using the proxy', () async {
    await Future.wait(
        List.generate(8, (_) => connectivity.check(network.proxy)));
    expect(connectivity.proxyEnabled, isFalse);
    expect(network.directChecks, 1);
    expect(network.proxyChecks, 0);
  });

  test('blocked startup enables the proxy only after verifying it', () async {
    network.blocked = true;
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    await Future.wait(
        List.generate(8, (_) => connectivity.check(network.proxy)));
    expect(settings.enableProxy, isTrue);
    expect(sharedPrefsSingleton.getBool(SettingsPreferences.USE_PROXY), isTrue);
    expect(network.directChecks, 2);
    expect(network.proxyChecks, 1);
    final response = await connectivity.get(network.title, network.proxy);
    expect(jsonDecode(response.body)['id'], 1);
    expect(network.proxyRequests, 1);
    expect(network.directRequests, 0);
  });

  test('an interrupted request transparently retries through the proxy',
      () async {
    await connectivity.check(network.proxy);
    network.blocked = true;
    final responses = await Future.wait(List.generate(
        6, (_) => connectivity.get(network.title, network.proxy)));
    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(connectivity.proxyEnabled, isTrue);
    expect(network.directChecks, 3);
    expect(network.proxyChecks, 1);
    expect(network.proxyRequests, 6);
  });

  test('offline or a broken proxy never enables proxy mode', () async {
    network.offline = true;
    await connectivity.check(network.proxy);
    expect(connectivity.proxyEnabled, isFalse);
    await connectivity.check(network.proxy);
    expect(network.directChecks, 1);
    expect(network.proxyChecks, 1);
    network.offline = false;
    network.blocked = true;
    network.proxyDown = true;
    await connectivity.check(network.proxy, networkChanged: true);
    expect(connectivity.proxyEnabled, isFalse);
  });

  test('timeouts are bounded and do not leave pending shared checks', () async {
    network.holdDirect = Completer<void>();
    network.proxyDown = true;
    await connectivity.check(network.proxy);
    expect(connectivity.proxyEnabled, isFalse);
    expect(network.proxyChecks, 1);
    network.holdDirect!.complete();
    await connectivity.check(network.proxy, networkChanged: true);
    expect(network.directChecks, 2);
    expect(connectivity.proxyEnabled, isFalse);
  });

  for (final status in [401, 403, 404, 429, 500]) {
    test('TMDB API error $status does not enable the proxy', () async {
      network.directStatus = status;
      await connectivity.check(network.proxy);
      final response = await connectivity.get(network.title, network.proxy);
      expect(response.statusCode, status);
      expect(connectivity.proxyEnabled, isFalse);
      expect(network.proxyChecks, 0);
      expect(network.proxyRequests, 0);
    });
  }

  test('a network change restores direct mode when TMDB becomes reachable',
      () async {
    network.blocked = true;
    await connectivity.check(network.proxy);
    network.blocked = false;
    await connectivity.check(network.proxy, networkChanged: true);
    expect(connectivity.proxyEnabled, isFalse);
    expect(network.proxyChecks, 1);
    final response = await connectivity.get(network.title, network.proxy);
    expect(response.statusCode, 200);
    expect(network.directRequests, 1);
  });

  test('active proxy periodically retries direct access to reduce fees',
      () async {
    network.blocked = true;
    await connectivity.check(network.proxy);
    network.blocked = false;
    now = now.add(const Duration(minutes: 6));
    await connectivity.get(network.title, network.proxy);
    expect(connectivity.proxyEnabled, isFalse);
    expect(network.directRequests, 1);
    expect(network.proxyRequests, 0);
  });

  test('turning off wins over concurrent checks and lasts for the session',
      () async {
    network.blocked = true;
    await connectivity.check(network.proxy);
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    network.holdDirect = Completer<void>();
    final pending = connectivity.check(network.proxy, networkChanged: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    settings.disableTmdbProxy();
    network.holdDirect!.complete();
    await pending;
    await connectivity.check(network.proxy, networkChanged: true);
    final response = await connectivity.get(network.title, network.proxy);
    expect(response.statusCode, 451);
    expect(settings.enableProxy, isFalse);
    expect(network.proxyChecks, 1);
    expect(network.proxyRequests, 0);
    expect(
        sharedPrefsSingleton.getBool(SettingsPreferences.USE_PROXY), isFalse);
  });

  for (final status in [200, 403, 451]) {
    test('HTML block page with status $status triggers fallback', () async {
      network.blocked = true;
      network.blockedStatus = status;
      final response = await connectivity.get(network.title, network.proxy);
      expect(response.statusCode, 200);
      expect(connectivity.proxyEnabled, isTrue);
    });
  }

  test('a refused connection triggers a checked proxy retry', () async {
    final closedServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = closedServer.port;
    await closedServer.close(force: true);
    network.blocked = true;
    final response = await connectivity.get(
        'http://127.0.0.1:$closedPort/3/movie/1', network.proxy);
    expect(response.statusCode, 200);
    expect(connectivity.proxyEnabled, isTrue);
    expect(network.proxyRequests, 1);
  });

  test('first-launch requests use proxy config arriving during the check',
      () async {
    var configuredProxy = '';
    connectivity.proxyUrlSource = () => configuredProxy;
    network.blocked = true;
    network.holdDirect = Completer<void>();
    final startup = connectivity.check('');
    final request = connectivity.get(network.title, '');
    configuredProxy = network.proxy;
    network.holdDirect!.complete();
    await startup;
    final response = await request;
    expect(response.statusCode, 200);
    expect(connectivity.proxyEnabled, isTrue);
    expect(network.proxyChecks, 1);
    expect(network.proxyRequests, 1);
  });

  test('legacy manually enabled preferences do not enable proxy on launch',
      () async {
    await sharedPrefsSingleton.setBool(SettingsPreferences.USE_PROXY, true);
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    await settings.getUseProxyMode();
    expect(settings.enableProxy, isFalse);
    expect(
        sharedPrefsSingleton.getBool(SettingsPreferences.USE_PROXY), isFalse);
    expect(network.proxyChecks, 0);
  });
}
