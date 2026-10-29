import 'services/in_app_messaging_service.dart';
import 'data/sync/sync_runtime.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'data/ads/ad_events_controller.dart';
import 'services/hosted_ads_repository.dart';
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

bool isTablet(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double threshold = 1000.0;
  return screenWidth > threshold;
}

SettingsProvider settingsProvider = SettingsProvider();
RecentProvider recentProvider = RecentProvider();
BookmarkProvider bookmarkProvider = BookmarkProvider();
PlaylistProvider playlistProvider = PlaylistProvider();
AppDependencyProvider appDependencyProvider = AppDependencyProvider();
WellnessProvider wellnessProvider = WellnessProvider.instance;

Future<DevicePresentation> appInitialize({
  DevicePresentationDetector? devicePresentationDetector,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Let Flutter paint behind Android's transparent gesture-navigation area.
  // Individual surfaces remain responsible for applying SafeArea padding to
  // interactive content.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final devicePresentation = await resolveDevicePresentation(
    detector: devicePresentationDetector,
  );

  // Initialize MediaKit for video playback with multiple codec support
  // MediaKit.ensureInitialized();

  // Reset orientation to all orientations on app start
  // This is CRITICAL for handling ungraceful app termination (force-close, system kill)
  // When the app is killed while streaming in landscape mode, this ensures
  // orientation is reset on next app launch since dispose() never gets called
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Android 7.0 predates ISRG Root X1, which anchors the API's certificate.
  try {
    final root = await rootBundle.load('assets/ca/isrg-root-x1.pem');
    SecurityContext.defaultContext
        .setTrustedCertificatesBytes(root.buffer.asUint8List());
  } catch (_) {/* The platform already trusts it. */}
  await dotenv.load(fileName: '.env');
  await EasyLocalization.ensureInitialized();
  // Seed the shared version with the installed build so any synchronous reader
  // matches the binary instead of a hardcoded string that drifts.
  currentAppVersion = (await PackageInfo.fromPlatform()).version;
  sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  await settingsProvider.getCurrentAppMode();
  DevicePresentationService.instance.isTelevision =
      settingsProvider.appMode.resolve(devicePresentation) ==
          DevicePresentation.television;
  await clearVideoPlaybackCache();
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  await settingsProvider.getCurrentThemeMode();
  await settingsProvider.getCurrentMaterial3Mode();
  await settingsProvider.initMixpanel();
  await settingsProvider.getCurrentAdultMode();
  await settingsProvider.getCurrentDefaultScreen();
  await settingsProvider.getCurrentImageQuality();
  await settingsProvider.getCurrentWatchCountry();
  await settingsProvider.getSeekDuration();
  await settingsProvider.getHoldSpeeds();
  await settingsProvider.getMaxBufferDuration();
  await settingsProvider.getVideoResolution();
  await settingsProvider.getSubtitleLanguage();
  await settingsProvider.getSubtitleMode();
  await settingsProvider.getViewMode();
  await settingsProvider.getSubtitleSize();
  await settingsProvider.getForegroundSubtitleColor();
  await settingsProvider.getBackgroundSubtitleColor();
  await settingsProvider.getAppLanguage();
  await settingsProvider.getAppColorIndex();
  await settingsProvider.getCustomAppColor();
  await settingsProvider.getStreamProviderOrder();
  await settingsProvider.getPlayerTimeStyle();
  await settingsProvider.getUseProxyMode();
  await settingsProvider.getSubtitleStyle();
  await settingsProvider.getEnableNextEpisodeButton();
  await settingsProvider.getIntroDbSettings();
  await settingsProvider.getPlayerAmbientGlowEnabled();
  await settingsProvider.getAutoPipOnLeave();
  await settingsProvider.getStreamingDnd();
  await settingsProvider.getAutoLoadSources();
  settingsProvider.completeHydration();
  await recentProvider.fetchMovies();
  await recentProvider.fetchEpisodes();
  await bookmarkProvider.fetchBookmarks();
  await wellnessProvider.initialize();
  await appDependencyProvider.getFlixQuestLogo();
  await appDependencyProvider.getOccasionalTheme(preserveSelection: true);
  await appDependencyProvider.getAmbientMode();
  await appDependencyProvider.getFQUrl();
  await appDependencyProvider.getTmdbProxy();
  await appDependencyProvider.getUpdateConfiguration();

  return devicePresentation;
}

void main() async {
  final devicePresentation = await appInitialize();
  final environment = AppEnvironment.fromRuntime();
  final httpOverrides = MyHttpOverrides(
      verifiedHosts: {Uri.parse(environment.laravelApiUrl).host});
  HttpOverrides.global = httpOverrides;
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
  if (SyncRuntime.enabled) {
    await BookmarkSyncService.instance.init();
    await RecentlyWatchedSyncService.instance.init();
    wellnessProvider.syncService.bind();
    injector.session.ownerId.addListener(() {
      bookmarkProvider.resetForOwner();
      playlistProvider.resetForOwner();
      recentProvider.resetForOwner();
      unawaited(bookmarkProvider.fetchBookmarks());
      unawaited(playlistProvider.load());
      unawaited(recentProvider.fetchMovies());
      unawaited(recentProvider.fetchEpisodes());
    });
  }
  await injector.session.restore();
  AuthSessionController.instance.initialize();
  await injector.plus.start();
  installPlusOffer();
  await wellnessProvider.bindLaravelOwner(injector.session.ownerId);
  if (SyncRuntime.enabled) {
    await bookmarkProvider.fetchBookmarks();
    await recentProvider.fetchMovies();
    await recentProvider.fetchEpisodes();
    unawaited(injector.syncCoordinator.syncAll());
  }
  await playlistProvider.load();
    // Push notifications (FCM/OneSignal) are intentionally disabled for now.
  NotificationController? notifications;
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
  await MediaLinkNavigationService.initialize();
  runApp(MultiProvider(
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
              notifications: notifications,
            ),
          ))));
}
