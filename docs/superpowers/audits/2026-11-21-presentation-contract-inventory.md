# 7xPlay Presentation Contract Inventory

**Date:** 2026-11-21  
**Branch:** feat/clean-slate-presentation  
**Base:** main at f330df2cbf1bd9a299fbea2c1e54fa265640b6f9  
**Purpose:** Initial source-grounded inventory for the clean-slate presentation migration. This records verified source ownership and protected behavior; the implementation pass must complete the repository-wide caller/route search before deleting or moving any legacy file.

## 1. Runtime and composition chain

### Startup

- lib/main.dart owns app initialization and startup sequencing.
- appInitialize() resolves DevicePresentation, sets edge-to-edge/orientation behavior, loads .env and localization, hydrates settings, initializes SharedPreferences/downloader, loads recent/bookmark/wellness state, and hydrates app dependencies.
- main() builds the dependency injector and network overrides, configures ads/auth/sync/plus and owner-bound state, restores the session, loads playlist state, and ultimately constructs the FlixQuest runtime widget.
- The bootstrap is not a presentation-only concern. Keep its ordering and initialization semantics unchanged while introducing the new experience.

### Runtime MaterialApp host

- lib/flixquest_main.dart contains FlixQuest and owns the provider graph around settings, recent, bookmarks, playlists, app dependencies, offline downloads and wellness.
- It constructs ThemeData from settings, selected app colours, dynamic colours and occasional/ambient themes.
- It owns the MaterialApp navigator key, restorationScopeId, localization delegates/locales, system navigation bar styling, update gate selection, Plus overlays, occasional-effect overlay and Ads warmup.
- FlixQuest also coordinates app lifecycle callbacks, notification/deep-link readiness, sync flushes, network/TMDB refresh, home-widget refresh, ads, Plus and notification services.
- Decision: this runtime host may be renamed/extracted later, but its responsibilities must not be deleted or duplicated as part of the UI reset.

### Authentication and platform selection

- lib/screens/user/user_state.dart calls presentationShellFor().
- presentationShellFor() currently selects:
  - handheld + authenticated: FlixQuestHomePage -> MobileShell
  - handheld + signed out: LandingScreen
  - TV + authenticated: TvHomeShell
  - TV + signed out: TvLandingScreen
- SessionGate owns the authenticated-state boundary. Keep it and route its authenticated state into the new ExperienceRoot.

## 2. Handheld navigation contracts

### Current shell and destinations

- lib/mobile/app/mobile_shell.dart owns the authenticated handheld shell, lazy tab body creation, state retention, tab restoration, system Back behavior, tablet rail selection, analytics tracking, and destination persistence.
- lib/mobile/app/mobile_tabs.dart defines the current stable destinations and IDs:
  - Home: home
  - New & Hot: new
  - Discover: discover
  - Search: search
  - My Library / current UI label: mine
- The destination named mine is the persisted and analytics identifier; the new user-facing Library label must not change that ID.
- DefaultHome maps Home/Home Movies/Home Series to Home, Search to Search, and Mine to the mine destination. Home additionally receives a default content filter.
- Reselect behavior: scroll current destination to top; if already at top, notify the current page to reset its local filter/query.
- The shell remembers the selected destination through AppSessionStateStore.handheldDestination and supports Flutter restoration.
- The shell tracks navigation through SettingsProvider.analytics with stable destination ID and surface values.
- Existing tests: test/mobile_shell_test.dart, test/default_home_test.dart, test/app_session_state_store_test.dart, test/app_presentation_test.dart.

### Existing mobile page and widget families

- Primary pages: lib/mobile/screens/home_screen.dart, new_and_hot_screen.dart, discover_screen.dart, search_screen.dart, my_flixquest_screen.dart.
- Details and content: title_details_screen.dart, season_screen.dart, episode_screen.dart, person_screen.dart, credits_screen.dart, collection_screen.dart.
- Library and lists: playlists_screen.dart, playlist_screen.dart, shared_playlist_screen.dart, playlist_import_screen.dart, plus my_list.dart / collections.dart / playlists.dart helpers.
- Plus/support: plus_screen.dart, plus_payment_screen.dart, wallet_screen.dart, flix_ai_screen.dart.
- Reused visual/widget families include hero_card.dart, media_rows.dart, poster_grid.dart, details_header.dart, details_parts.dart, episode_row.dart, episodes_section.dart, filter_chips.dart, category_section.dart, settings_kit.dart, page_kit.dart, skeletons.dart, plus sheets/cards, and prompts.
- These widgets are presentation migration inputs only. Their data logic or callbacks may still need to be retained through feature adapters.

## 3. Shared app routes and system/support surfaces

- Common screens in lib/screens/common include landing_screen.dart, settings.dart, language_choose.dart, sublanguage_choose.dart, live_tv_screen.dart, live_player.dart, player.dart, offline_player_screen.dart, downloads_screen.dart, bookmark_screen.dart, sync_screen.dart, about.dart, update_screen.dart, provider_choose.dart, manual_source_picker.dart, server_status_screen.dart, hero_photoview.dart, photoview.dart, image_viewer_chrome.dart, download selection sheets and deep_link_loader.dart.
- Auth/account screens live in lib/screens/user: login_screen.dart, signup_screen.dart, forgot_password.dart, edit_profile.dart, email_change.dart, password_change.dart and delete_account.dart.
- Wellness surfaces live in lib/screens/wellness and its widgets folder.
- Existing deep-link and external-entry behavior is spread across services/deep_link_dispatcher.dart, media_link_navigation_service.dart, home_widget_navigation_service.dart, notification handlers, and the common deep-link loader. A caller-by-caller search is required before changing destination construction.
- Preserve stable external paths, media identifiers, notification targets, home-widget actions, and root navigator semantics.

## 4. Android TV contracts

- lib/tv/app/tv_home_shell.dart is the authenticated TV root. It owns a distinct destination list and layout, session/restoration state, focus memory, title-logo cache, and navigation into TV screens.
- Current TV destinations include home, search, movies, series, live, library, wellness, profile and settings. Live can be hidden by remote configuration.
- lib/tv/focus contains TvFocusMemory, TvFocusable, TvScreenFocusController and key mapping. Reuse or wrap these contracts rather than creating a competing focus state machine.
- lib/tv/navigation contains TvBackDispatcher and TvBackKeyGuard. These own remote Back behavior and app-level guarding.
- lib/tv/app contains tv_home_shell.dart, tv_shell_layout.dart and tv_design.dart.
- Current TV screens include landing, auth, home, catalog, search, library, details, collection, live, playlist import, playlist name, shared playlist, Plus, profile, redeem-code, settings and wellness.
- Current TV-specific UI includes navigation rail, search/form keyboards, focusable media cards, list/grid/wall/spotlight layouts, focus-aware dialogs and skeletons.
- Existing regression coverage includes test/tv_back_dispatcher_test.dart, tv_back_key_guard_test.dart, tv_remote_navigation_test.dart, tv_shell_layout_test.dart, tv_search_screen_test.dart, tv_media_details_test.dart, tv_collection_screen_test.dart, tv_library_screen_test.dart, tv_profile_screen_test.dart, tv_settings_screen_test.dart, tv_wellness_screen_test.dart, tv_form_keyboard_test.dart, tv_search_keyboard_test.dart and tv_provider_order_dialog_test.dart.

## 5. Playback boundaries

### Movie/series

- lib/screens/common/player.dart defines PlayerOne and is a large stateful widget that combines playback presentation with extensive playback/service integration.
- The file coordinates BetterPlayer, movie/TV stream metadata, provider ordering/loading, source and header state, audio-language policy, subtitles, episode selection, next-episode policy, completion detection, feedback, pre-roll ads, playback saving, wake lock, offline/download behavior and stream diagnostics.
- UI extraction must be surgical: define a presentation snapshot plus callbacks from the existing owner; do not move stream resolution, provider selection, audio policy, subtitle policy, progress persistence or playback lifecycle into the new view layer.

### Live and offline

- lib/screens/common/live_player.dart is the Live TV playback entry.
- lib/screens/common/offline_player_screen.dart is the offline playback entry.
- Movie/series, live and offline players require separate visual variants where behavior differs, but must preserve their current engine and state ownership.

### Player support files

- lib/screens/common/player/ contains focused playback helpers for background save, completion detection, data management, episode selection, subtitles, recommendations, next-episode policy, pre-roll ads, feedback, player sheets, subtitle timing and watch-page behavior.
- Preserve these files and their tests unless the new UI proves a helper is presentation-only and safely replaceable.
- Existing tests include unified_playback_compile_test.dart, unified_playback_language_service_test.dart, preferred_audio_language_policy_test.dart, download_audio_selection_test.dart, player_route_handoff_test.dart, player_background_save_test.dart, player_completion_detector_test.dart, player_sheet_ui_test.dart, player_feedback_ui_test.dart, player_subtitle_configuration_test.dart, live_playback_policy_test.dart, offline_download_test.dart and provider/audio policy tests.

## 6. Brand and theme constraints

- docs/7xplay_visual_direction.md names the committed product icon and wordmark as the source of truth: near-black/purple-black base, gold/yellow/orange-red play/7 mark, hot pink/violet X.
- Cyan/teal are explicitly not 7xPlay primary colours. Gold/orange are the primary action family; pink/violet are restrained secondary accents.
- lib/design/app_palette.dart currently derives semantic roles from ThemeData, while lib/design/app_tokens.dart owns spacing, radii, breakpoints and Figtree type styles.
- Preserve user theme modes and current theme preference hydration: Dark, AMOLED, Light, custom/dynamic, seasonal and ambient all remain supported. The new experience needs semantic roles that adapt to these modes rather than hard-coded dark-only components.
- Use assets/images/7xplay_wordmark.png for in-app brand placement; do not stretch the square launcher icon into a wordmark.

## 7. Build and automated validation

- The repository currently has one Android workflow: .github/workflows/build-android.yml.
- It uses Ubuntu 24.04 and Flutter 3.41.5 stable.
- It checks out the app and the local sibling BetterPlayer dependency from BeamlakAschalew/flixquest-betterplayer at ref claude/relaxed-dirac-tw37rj.
- It requires the TMDB_API_KEY GitHub Actions secret to create .env before dependency resolution.
- It caches Pub packages and runs named provider, AI, landing, shell, library, palette, Home, catalogue/search, detail, settings, wellness, TV and playback regression suites; inspect the remainder of the workflow when finalizing the exact CI matrix.
- The workflow is configured for pushes to main, pull requests targeting main, and manual dispatch. A feature-branch pull request is the available route to get an Android runner to execute validation.
- This session does not have a mounted repository checkout, Flutter/Dart SDK, or network access for a local clone. Do not report local Flutter commands, APK builds, installs or device tests as run. Use the GitHub Actions runner for future code verification and inspect its logs/artifacts before making claims.

## 8. Known migration risks and required next investigations

1. PlayerOne currently combines UI and playback state ownership. Extract its UI state/callback boundary without creating a second playback state machine.
2. The global FlixQuest widget owns runtime lifecycle, provider scope, MaterialApp and global overlays. Preserve that host's behavior while replacing the route-level product experience.
3. Direct Navigator pushes and helper services may bypass a central route registry. Search all route constructors, pushNamed usages, route names, notification targets and deep-link dispatch paths before deleting a legacy screen.
4. TV focus restoration spans more than a visual navigation rail. Preserve focus memory, directional key handling, back dispatch and TV keyboard flows.
5. Current tests reference legacy widget classes. Replace only presentation assertions; retain regression tests for data, provider and playback behavior.
6. Some screens share widgets across mobile and TV. Check references before removing common UI to avoid breaking platform-specific flows.

## 9. Completion criteria for this inventory

This initial inventory is grounded in the current main-branch source and test tree. Before implementation removes or relocates any legacy file, complete a repository-wide reference/caller search and update this document with:
- every active route/intent and its new destination,
- every legacy widget's final disposition,
- every stateful/business dependency retained behind a feature adapter,
- every temporary bridge and its removal task,
- all tests that assert behavior rather than old widget type names.

No product code has been changed as part of this inventory.
