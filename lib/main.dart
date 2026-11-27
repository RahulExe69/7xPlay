import 'data/sync/sync_runtime.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'data/ads/ad_events_controller.dart';
import 'services/hosted_ads_repository.dart';
import 'presentation/config/refresh_controller.dart';
import 'services/local_account_data.dart';
import 'presentation/session/auth_runtime.dart';
import 'presentation/session/session_view_model.dart';
import 'presentation/billing/plus_controller.dart';
import 'services/plus_navigation.dart';
import 'services/auth_session_controller.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import 'core/config/app_environment.dart';
import 'core/di/injector.dart';
import 'core/network/network_runtime.dart';
import 'package:flixquest/flixquest_main.dart';
import '../models/translation.dart';
import '../provider/app_dependency_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
// import 'package:media_kit/media_kit.dart';
import 'constants/app_constants.dart';
import 'functions/function.dart';
import 'provider/bookmark_provider.dart';
import 'provider/playlist_provider.dart';
import 'provider/recently_watched_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'provider/settings_provider.dart';
import 'provider/wellness_provider.dart';
import 'services/bookmark_sync_service.dart';
import 'services/recently_watched_sync_service.dart';
import 'services/media_link_navigation_service.dart';
import 'services/device_presentation_service.dart';
import 'services/home_widget_navigation_service.dart';
import 'singleton/sharedpreferences_singleton.dart';
import 'tv/platform/device_presentation.dart';
import 'tv/platform/device_presentation_detector.dart';
import 'widgets/startup_splash.dart';

bool isTablet(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double threshold = 1000.0;
  return screenWidth > threshold;
}

String _startupStage = 'starting';

SettingsProvider settingsProvider = SettingsProvider();
RecentProvider recentProvider = RecentProvider();
BookmarkProvider bookmarkProvider = BookmarkProvider();
PlaylistProvider playlistProvider = PlaylistProvider();
AppDependencyProvider appDependencyProvider = AppDependencyProvider();
WellnessProvider wellnessProvider = WellnessProvider.instance;

void _runStartupTask(String label, Future<void> task) {
  unawaited(task.catchError((Object error) {
    debugPrint('[Startup] $label failed: $error');
  }));
}

Future<void> _hydrateStartupSetting(
  String label,
  Future<void> Function() hydrate,
) async {
  try {
    await hydrate().timeout(const Duration(seconds: 4));
  } catch (error) {
    debugPrint('[Startup] $label hydration skipped: $error');
  }
}

Future<DevicePresentation> appInitialize({
  DevicePresentationDetector? devicePresentationDetector,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform UI tweaks are useful, but do not hold the first frame.
  _runStartupTask(
    'edge-to-edge system UI',
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
  );
  _runStartupTask(
    'orientation policy',
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
  );

  _startupStage = 'device profile detection';
  final devicePresentation = await resolveDevicePresentation(
    detector: devicePresentationDetector,
  ).timeout(
    const Duration(seconds: 3),
    onTimeout: () {
      debugPrint('[Startup] Device detection timed out; using handheld mode.');
      return DevicePresentation.handheld;
    },
  );

  // Establish the legacy Android trust anchor without blocking the first frame.
  _runStartupTask('root certificate setup', () async {
    try {
      final root = await rootBundle
          .load('assets/ca/isrg-root-x1.pem')
          .timeout(const Duration(seconds: 2));
      SecurityContext.defaultContext
          .setTrustedCertificatesBytes(root.buffer.asUint8List());
    } catch (_) {
      // The platform may already trust the certificate.
    }
  }());

  _startupStage = 'bundled environment configuration';

  await dotenv.load(fileName: 'config.env').timeout(const Duration(seconds: 4));

  _startupStage = 'localization initialization';
  await EasyLocalization.ensureInitialized()
      .timeout(const Duration(seconds: 4));

  // Package metadata is diagnostic only and must not hold app launch.
  _runStartupTask('package metadata lookup', () async {
    try {
      currentAppVersion = (await PackageInfo.fromPlatform()
              .timeout(const Duration(seconds: 5)))
          .version;
    } catch (error) {
      debugPrint('[Startup] Package info unavailable: $error');
    }
  }());

  _startupStage = 'shared preferences initialization';
  sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance()
      .timeout(const Duration(seconds: 6));

  _startupStage = 'essential preference hydration';
  await Future.wait<void>([
    _hydrateStartupSetting('app mode', settingsProvider.getCurrentAppMode),
    _hydrateStartupSetting('theme mode', settingsProvider.getCurrentThemeMode),
    _hydrateStartupSetting('app language', settingsProvider.getAppLanguage),
  ]);
  DevicePresentationService.instance.isTelevision =
      settingsProvider.appMode.resolve(devicePresentation) ==
          DevicePresentation.television;

  // Non-critical services initialize alongside the first screen.
  _runStartupTask('video cache cleanup', clearVideoPlaybackCache());
  _runStartupTask(
    'download manager initialization',
    FlutterDownloader.initialize(debug: true, ignoreSsl: true),
  );
  _runStartupTask('analytics initialization', settingsProvider.initMixpanel());

  // Hydrate non-critical player and catalogue preferences after the app is mounted.
  // These reads are independent and no longer hold the startup gate closed.
  _runStartupTask('secondary preference hydration', () async {
    await Future.wait<void>([
      _hydrateStartupSetting(
          'Material 3 preference', settingsProvider.getCurrentMaterial3Mode),
      _hydrateStartupSetting('adult mode', settingsProvider.getCurrentAdultMode),
      _hydrateStartupSetting(
          'default screen', settingsProvider.getCurrentDefaultScreen),
      _hydrateStartupSetting(
          'image quality', settingsProvider.getCurrentImageQuality),
      _hydrateStartupSetting(
          'watch country', settingsProvider.getCurrentWatchCountry),
      _hydrateStartupSetting('seek duration', settingsProvider.getSeekDuration),
      _hydrateStartupSetting('hold speeds', settingsProvider.getHoldSpeeds),
      _hydrateStartupSetting(
          'maximum buffer', settingsProvider.getMaxBufferDuration),
      _hydrateStartupSetting(
          'video resolution', settingsProvider.getVideoResolution),
      _hydrateStartupSetting(
          'subtitle language', settingsProvider.getSubtitleLanguage),
      _hydrateStartupSetting('subtitle mode', settingsProvider.getSubtitleMode),
      _hydrateStartupSetting('view mode', settingsProvider.getViewMode),
      _hydrateStartupSetting('subtitle size', settingsProvider.getSubtitleSize),
      _hydrateStartupSetting('subtitle foreground',
          settingsProvider.getForegroundSubtitleColor),
      _hydrateStartupSetting('subtitle background',
          settingsProvider.getBackgroundSubtitleColor),
      _hydrateStartupSetting('app color', settingsProvider.getAppColorIndex),
      _hydrateStartupSetting(
          'custom app color', settingsProvider.getCustomAppColor),
      _hydrateStartupSetting(
          'stream provider order', settingsProvider.getStreamProviderOrder),
      _hydrateStartupSetting(
          'player time style', settingsProvider.getPlayerTimeStyle),
      _hydrateStartupSetting('proxy mode', settingsProvider.getUseProxyMode),
      _hydrateStartupSetting(
          'subtitle style', settingsProvider.getSubtitleStyle),
      _hydrateStartupSetting('next episode preference',
          settingsProvider.getEnableNextEpisodeButton),
      _hydrateStartupSetting(
          'intro database settings', settingsProvider.getIntroDbSettings),
      _hydrateStartupSetting(
          'player ambient glow', settingsProvider.getPlayerAmbientGlowEnabled),
      _hydrateStartupSetting(
          'auto picture-in-picture', settingsProvider.getAutoPipOnLeave),
      _hydrateStartupSetting(
          'streaming do-not-disturb', settingsProvider.getStreamingDnd),
      _hydrateStartupSetting(
          'automatic source loading', settingsProvider.getAutoLoadSources),
    ]);
    settingsProvider.completeHydration();
  }());

  // Legacy app-specific preferences are loaded after the first frame.
  return devicePresentation;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupGate());
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  Widget? _application;
  Object? _startupError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadApplication());
  }

  Future<void> _loadApplication() async {
    try {
      final prepared = await _prepareApplication().timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'Startup initialization exceeded 45 seconds during $_startupStage.',
        ),
      );
      if (!mounted) return;
      setState(() {
        _application = prepared.application;
        _startupError = null;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _runStartupTask(
            'post-first-frame initialization',
            prepared.afterFirstFrame(),
          );
        }
      });
    } catch (error, stackTrace) {
      final diagnostic = '$_startupStage · ${error.runtimeType}';
      debugPrint('[Startup] $diagnostic: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _startupError = diagnostic;
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _startupError = null;
      _loading = true;
    });
    _startupStage = 'retrying startup';
    unawaited(_loadApplication());
  }

  @override
  Widget build(BuildContext context) {
    return _application ??
        StartupSplash(
          hasError: !_loading && _startupError != null,
          errorMessage: _startupError is String ? _startupError as String : null,
          onRetry: !_loading && _startupError != null ? _retry : null,
        );
  }
}

class _PreparedApplication {
  const _PreparedApplication({
    required this.application,
    required this.afterFirstFrame,
  });

  final Widget application;
  final Future<void> Function() afterFirstFrame;
}

Future<_PreparedApplication> _prepareApplication() async {
  final devicePresentation = await appInitialize();
  _startupStage = 'environment configuration';
  final environment = AppEnvironment.fromRuntime();
  final httpOverrides = MyHttpOverrides(
      verifiedHosts: {Uri.parse(environment.laravelApiUrl).host});
  HttpOverrides.global = httpOverrides;
  _startupStage = 'local dependency initialization';
  final injector = await buildInjector(
      environment: environment,
      deleteLocalData: (owner) async {
    await LocalAccountData.delete(owner);
    await bookmarkProvider.fetchBookmarks();
    await playlistProvider.load();
    await recentProvider.fetchMovies();
    await recentProvider.fetchEpisodes();
    await wellnessProvider.reload();
  });
  HostedAdsRepository.instance.configure(injector.adsRepository);
  if (injector.migrationFlags.ads) {
    // Observe each rendered frame so brief visibility interruptions reset dwell.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  }
  final adsController = injector.migrationFlags.ads
      ? AdEventsController(injector.adsRepository)
      : null;
  // Remote configuration integrations are intentionally dormant for this build.
  ConfigLifecycle? configController;
  AuthRuntime.configure(injector.session);
  SyncRuntime.configure(injector.syncCoordinator,
      enabled: injector.migrationFlags.auth && injector.migrationFlags.sync);
  AuthSessionController.instance.initialize();
  // Push notifications (FCM/OneSignal) are intentionally disabled for now.
  NetworkRuntime.configure(
      publicDio: injector.publicDio,
      httpCache: injector.httpCache,
      tmdb: injector.tmdbRepository);
  Timer.run(() =>
      unawaited(injector.httpCache.pruneExpired().catchError((Object _) {})));
  HomeWidgetNavigationService.configure(
    source: () => (
      language: settingsProvider.appLanguage,
      useProxy: settingsProvider.enableProxy,
      proxy: appDependencyProvider.tmdbProxy,
    ),
  );
  // Register the platform handler before the app's first frame, but do not
  // block first paint while Android drains any queued deep links.
  _runStartupTask('media link bridge', MediaLinkNavigationService.initialize());
  final application = MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionViewModel>.value(value: injector.session),
      ChangeNotifierProvider<PlusController>.value(value: injector.plus),
      ChangeNotifierProvider<PlaylistProvider>.value(value: playlistProvider),
    ],
    child: Provider<AppInjector>.value(
      value: injector,
      child: EasyLocalization(
        supportedLocales: Translation.all,
        path: 'assets/translations',
        fallbackLocale: Translation.all[0],
        startLocale: Locale(settingsProvider.appLanguage),
        child: FlixQuest(
          settingsProvider: settingsProvider,
          recentProvider: recentProvider,
          bookmarkProvider: bookmarkProvider,
          appDependencyProvider: appDependencyProvider,
          devicePresentation: devicePresentation,
          configController: configController,
          adsController: adsController,
        ),
      ),
    ),
  );
  return _PreparedApplication(
    application: application,
    afterFirstFrame: () => _initializePostLaunch(injector),
  );
}

Future<void> _initializePostLaunch(AppInjector injector) async {
  await Future.wait<void>([
    _hydrateStartupSetting(
        'FlixQuest logo preference', appDependencyProvider.getFlixQuestLogo),
    _hydrateStartupSetting(
        'occasional theme preference',
        () => appDependencyProvider.getOccasionalTheme(preserveSelection: true)),
    _hydrateStartupSetting(
        'ambient mode preference', appDependencyProvider.getAmbientMode),
    _hydrateStartupSetting(
        'scraper endpoint preferences', appDependencyProvider.getFQUrl),
    _hydrateStartupSetting(
        'TMDB proxy preference', appDependencyProvider.getTmdbProxy),
    _hydrateStartupSetting(
        'cached update configuration',
        appDependencyProvider.getUpdateConfiguration),
  ]);

  try {
    await wellnessProvider.initialize();
  } catch (error) {
    debugPrint('[Startup] Wellness initialization failed: $error');
  }

  if (SyncRuntime.enabled) {
    try {
      await BookmarkSyncService.instance.init();
      await RecentlyWatchedSyncService.instance.init();
      wellnessProvider.syncService.bind();
      injector.session.ownerId.addListener(() {
        bookmarkProvider.resetForOwner();
        playlistProvider.resetForOwner();
        recentProvider.resetForOwner();
        _runStartupTask('reload bookmarks', bookmarkProvider.fetchBookmarks());
        _runStartupTask('reload playlists', playlistProvider.load());
        _runStartupTask('reload recent movies', recentProvider.fetchMovies());
        _runStartupTask('reload recent episodes', recentProvider.fetchEpisodes());
      });
    } catch (error) {
      debugPrint('[Startup] Sync service initialization failed: $error');
    }
  }

  try {
    await injector.session.restore();
    AuthSessionController.instance.initialize();
  } catch (error) {
    debugPrint('[Startup] Session restore failed: $error');
  }

  try {
    await injector.plus.start();
    installPlusOffer();
  } catch (error) {
    debugPrint('[Startup] Plus initialization failed: $error');
  }

  try {
    await wellnessProvider.bindLaravelOwner(injector.session.ownerId);
  } catch (error) {
    debugPrint('[Startup] Wellness account binding failed: $error');
  }

  try {
    await Future.wait<void>([
      recentProvider.fetchMovies(),
      recentProvider.fetchEpisodes(),
      bookmarkProvider.fetchBookmarks(),
      playlistProvider.load(),
    ]);
  } catch (error) {
    debugPrint('[Startup] Local library hydration failed: $error');
  }

  if (SyncRuntime.enabled) {
    _runStartupTask(
      'initial account sync',
      injector.syncCoordinator.syncAll(),
    );
  }
}
