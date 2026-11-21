import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_constants.dart';
import '../../provider/settings_provider.dart';
import '../../services/adsterra_playback_ads_service.dart';
import '../../services/app_session_state_store.dart';
import '../../singleton/sharedpreferences_singleton.dart';
import '../../design/app_tokens.dart';
import '../design/experience_theme_extension.dart';
import '../../mobile/app/mobile_tabs.dart';
import '../screens/experience_discover_screen.dart';
import '../screens/experience_home_screen.dart';
import '../../mobile/screens/my_flixquest_screen.dart';
import '../screens/experience_new_and_hot_screen.dart';
import '../../mobile/screens/search_screen.dart';
import '../../mobile/widgets/telegram_channel_prompt.dart';
import 'experience_navigation.dart';

/// The new handheld application frame.
///
/// This shell owns navigation, restoration, tab lifetime and responsive
/// composition. Existing feature pages are temporarily mounted through
/// [_ExperienceDestinationBody] so their data, playback and deep-link contracts
/// remain intact while each destination receives its own new page composition.
class ExperienceMobileShell extends StatefulWidget {
  const ExperienceMobileShell({
    this.tabBuilders,
    this.preferences,
    super.key,
  });

  final Map<MobileTab, WidgetBuilder>? tabBuilders;
  final SharedPreferences? preferences;

  @override
  State<ExperienceMobileShell> createState() => _ExperienceMobileShellState();
}

class _ExperienceMobileShellState extends State<ExperienceMobileShell>
    with RestorationMixin, SingleTickerProviderStateMixin {
  late final AppSessionStateStore _session;
  late final MobileTabController _tabs;
  late final RestorableString _restoredTab;
  late final AnimationController _transition;
  final Map<MobileTab, Widget> _destinations = <MobileTab, Widget>{};
  final GlobalKey _destinationStackKey =
      GlobalKey(debugLabel: '7xPlay experience destinations');

  @override
  String get restorationId => '7xplay_experience_home';

  @override
  void initState() {
    super.initState();
    _session = AppSessionStateStore(widget.preferences ?? sharedPrefsSingleton);
    final defaultHome = context.read<SettingsProvider>().defaultHome;
    final initial = MobileTab.fromId(_session.handheldDestination) ??
        MobileTab.forDefault(defaultHome);
    _restoredTab = RestorableString(initial.id);
    _tabs = MobileTabController(
      initial: initial,
      initialHomeFilter: homeFilterForDefault(defaultHome),
    )..addListener(_onDestinationChanged);
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
      value: 1,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsProvider>().analytics.trackNavigation(
            destination: _tabs.current.id,
            surface: 'experience',
            source: 'restored',
          );
      unawaited(
        AdsterraPlaybackAdsService.instance
            .showOwedPlayerExitOnLaunch(context),
      );
    });
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoredTab, 'selected_destination');
    final restored = MobileTab.fromId(
      AppSessionStateStore.legacyHandheldDestinations[_restoredTab.value] ??
          _restoredTab.value,
    );
    if (restored != null && restored != _tabs.current) {
      _tabs.restore(restored);
    }
  }

  void _onDestinationChanged() {
    final tab = _tabs.current;
    if (_restoredTab.value == tab.id) return;
    setState(() => _restoredTab.value = tab.id);
    _transition.forward(from: 0);
    context.read<SettingsProvider>().analytics.trackNavigation(
          destination: tab.id,
          surface: 'experience',
        );
    unawaited(_session.rememberHandheldDestination(tab.id));
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onDestinationChanged)
      ..dispose();
    _restoredTab.dispose();
    _transition.dispose();
    super.dispose();
  }

  Widget _destination(MobileTab tab) => _destinations.putIfAbsent(
        tab,
        () => KeyedSubtree(
          key: ValueKey<MobileTab>(tab),
          child: Builder(
            builder: widget.tabBuilders?[tab] ??
                (_) => _ExperienceDestinationBody(tab: tab),
          ),
        ),
      );

  MediaQueryData _besideRail(MediaQueryData media) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    EdgeInsets clear(EdgeInsets insets) =>
        rtl ? insets.copyWith(right: 0) : insets.copyWith(left: 0);
    return media.copyWith(
      size: Size(
        media.size.width - ExperienceNavigation.railWidth,
        media.size.height,
      ),
      padding: clear(media.padding),
      viewPadding: clear(media.viewPadding),
      viewInsets: clear(media.viewInsets),
    );
  }

  Widget _destinationStack(MobileTab current) => Stack(
        key: _destinationStackKey,
        fit: StackFit.expand,
        children: [
          for (final tab in MobileTab.values)
            if (tab == current || _destinations.containsKey(tab))
              Offstage(
                key: ValueKey<MobileTab>(tab),
                offstage: tab != current,
                child: TickerMode(
                  enabled: tab == current,
                  child: FadeTransition(
                    opacity: tab == current
                        ? _transition
                        : kAlwaysCompleteAnimation,
                    child: _destination(tab),
                  ),
                ),
              ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final current = _tabs.current;
    final media = MediaQuery.of(context);
    final useRail = media.size.width >= AppBreakpoints.tablet ||
        (AppBreakpoints.isTablet(context) && media.size.width >= 600);
    final palette = ExperienceThemeExtension.of(context).palette;

    return MobileTabScope(
      controller: _tabs,
      child: PopScope(
        canPop: current == MobileTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _tabs.select(MobileTab.home);
        },
        child: Scaffold(
          backgroundColor: palette.page,
          extendBody: false,
          bottomNavigationBar: useRail
              ? null
              : ExperienceNavigation(
                  current: current,
                  onSelect: _tabs.select,
                ),
          body: useRail
              ? Row(
                  children: [
                    ExperienceNavigation(
                      current: current,
                      onSelect: _tabs.select,
                      rail: true,
                    ),
                    Expanded(
                      child: MediaQuery(
                        data: _besideRail(media),
                        child: _destinationStack(current),
                      ),
                    ),
                  ],
                )
              : _destinationStack(current),
        ),
      ),
    );
  }
}

/// A compatibility adapter, not the long-term destination implementation.
class _ExperienceDestinationBody extends StatelessWidget {
  const _ExperienceDestinationBody({required this.tab});

  final MobileTab tab;

  @override
  Widget build(BuildContext context) => switch (tab) {
        MobileTab.home => const TelegramChannelPrompt(child: ExperienceHomeScreen()),
        MobileTab.newAndHot => const ExperienceNewAndHotScreen(),
        MobileTab.discover => const ExperienceDiscoverScreen(),
        MobileTab.search => const SearchScreen(),
        MobileTab.mine => const MyFlixQuestScreen(),
      };
}
