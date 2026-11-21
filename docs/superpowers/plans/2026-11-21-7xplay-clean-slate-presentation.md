# 7xPlay Clean-Slate Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Replace the entire shipped 7xPlay presentation layer with a genuinely new, responsive product experience while preserving existing app, account, data, provider, and playback behavior.

**Architecture:** Introduce a new experience-owned application root, navigation boundary, semantic design system, handheld/tablet shell, TV experience, and player presentation. Keep existing services, repositories, providers, persisted contracts, route/deep-link semantics, and playback engines underneath the new UI through small feature adapters. Legacy presentation code is migration input only and must be removed from the active path at the end.

**Tech Stack:** Flutter 3.41.5 stable, Dart 3.x, existing Provider/Material/Navigator stack, existing Figtree fonts and current repository services; no new dependency by default.

**Spec:** docs/superpowers/specs/2026-11-21-7xplay-clean-slate-presentation-design.md

## Global Constraints

- Preserve the existing playback engines and BetterPlayer integration, source resolution, provider aggregation/order, unified audio selection, subtitles, fallback policy, watch progress, next episode, picture-in-picture, downloads and offline playback behavior.
- Preserve existing API/backend contracts, network clients, repositories, catalogue/search semantics, auth/session semantics, local persistence formats, bookmarks/playlists/history, synchronization and guest behavior.
- Preserve analytics event identifiers and stable destination IDs, deep-link formats and dispatch semantics, notification navigation, home-widget contracts, update gates, ads lifecycle, and runtime configuration.
- Preserve existing localization content and supported locales.
- Keep Flutter as the app platform; do not add dependencies without a demonstrated need.
- Keep internal package identity and legacy external identifiers stable.
- Use the committed 7xPlay brand direction: near-black/purple-black base, warm gold/orange primary emphasis, hot pink/violet secondary emphasis; no cyan/teal as primary product accents.
- Preserve Dark, AMOLED, Light, custom/dynamic, seasonal and ambient theme modes and preferences.
- Use existing Figtree fonts; respect text scaling, contrast, reduced motion, accessibility, RTL, localization expansion, system insets, and TV focus visibility.
- Do not ship legacy screen trees as permanent content behind a new shell.
- Declare a test/build/device check passed only after it was actually run.

## Review Focus

1. **Restored navigation and stable IDs:** old persisted IDs (especially mine/new) and default-home choices must restore the expected destination without resetting user data. Pin with destination-controller and root-shell restoration tests.
2. **Live platform-mode changes:** switching handheld/TV at runtime must clear incompatible routes, restore the correct shell, and update DevicePresentationService. Pin with root presentation tests.
3. **Theme and accessibility combinations:** Dark, AMOLED, Light, custom/dynamic, seasonal/ambient, large text, RTL and reduced motion must not create unreadable controls or overflow. Pin with palette/widget tests and the CI device matrix.
4. **External navigation and overlays:** deep links, notifications, home-widget actions and details pushed above a tab must continue to land in the correct screen and preserve back behavior. Pin with navigation compatibility tests.
5. **Player behavior under UI replacement:** provider choice, audio/subtitle selection, lifecycle saves, ad gates, next episode, offline and live playback must remain functional. Pin with existing playback regression tests plus new player-surface contract tests.

---

### Task 1: Inventory and lock the presentation contracts

**Files:**
- Create: docs/superpowers/audits/2026-11-21-presentation-contract-inventory.md
- Inspect: lib/main.dart, lib/flixquest_main.dart, lib/screens/user/user_state.dart
- Inspect: lib/mobile/app/**, lib/mobile/screens/**, lib/mobile/widgets/**
- Inspect: lib/tv/app/**, lib/tv/navigation/**, lib/tv/focus/**, lib/tv/screens/**, lib/tv/player/**, lib/tv/widgets/**
- Inspect: lib/screens/common/**, lib/screens/movie/**, lib/screens/tv/**, lib/screens/person/**, lib/screens/user/**, lib/screens/wellness/**
- Inspect: test/** and .github/workflows/build-android.yml

**Interfaces:**
- Produces: a route/screen/overlay inventory, stable-ID map, dependency map, behavior parity checklist, and old-widget removal list. Later tasks use this inventory as the exact scope source.

- [ ] **Step 1: Build the route and surface inventory.** Record every visible page, route entry, modal, system overlay, playback handoff, TV focus owner, and all current callers. Include landing/authenticated, all five handheld destinations, every detail/support screen, TV destinations, and movie/series/live/offline player entry points.
- [ ] **Step 2: Record compatibility contracts.** Trace MobileTab IDs, AppSessionStateStore keys, DefaultHome mapping, analytics destination/surface values, deep-link dispatcher targets, notification/home-widget destinations, player route handoffs, and TV back/focus memory.
- [ ] **Step 3: Trace data ownership.** For every screen group, note existing providers, controllers, repositories, services, models and mutations. Identify business logic that is entangled with old widgets and needs an adapter rather than a rewrite.
- [ ] **Step 4: Write the inventory and removal matrix.** Each legacy screen/widget must be marked as (a) runtime/service logic to preserve, (b) temporary adapter, or (c) presentation-only code to replace/delete.
- [ ] **Step 5: Verify coverage.** Check that every file in the experience-scope sections of the spec appears in the inventory; add any missing screen before moving to the design foundation.
- [ ] **Step 6: Commit.** Commit as docs: inventory 7xPlay presentation contracts.

**Verification:** Review the inventory against the recursive lib/ and test/ trees. Expected: no user-facing route, overlay or playback entry point is unclassified. No Flutter code changes are made in this task.

### Task 2: Create the new 7xPlay semantic design foundation

**Files:**
- Create: lib/experience/design/experience_palette.dart
- Create: lib/experience/design/experience_theme_extension.dart
- Create: lib/experience/design/experience_tokens.dart
- Create: lib/experience/widgets/experience_surface.dart
- Create: lib/experience/widgets/experience_action.dart
- Create: lib/experience/widgets/experience_artwork.dart
- Create: lib/experience/widgets/experience_state_panel.dart
- Test: test/experience/experience_palette_test.dart
- Test: test/experience/experience_widgets_test.dart
- Reference: lib/design/app_palette.dart, lib/design/app_tokens.dart, docs/7xplay_visual_direction.md

**Interfaces:**
- Produces: ExperiencePalette.fromTheme(ThemeData theme), ExperienceThemeExtension, ExperienceTokens, ExperienceSurface, ExperienceAction, ExperienceArtwork, and ExperienceStatePanel. All components consume semantic roles; none hard-code page colours directly.

- [ ] **Step 1: Write palette tests.** Assert gold/orange brand action roles, pink/violet secondary roles, no cyan/teal primary role, readable semantic text/surface pairs, and correct role mapping for dark and light ThemeData.
- [ ] **Step 2: Run the palette test and confirm it fails.** Run: flutter test test/experience/experience_palette_test.dart -v. Expected: FAIL because the new experience types do not exist.
- [ ] **Step 3: Implement semantic palette and theme extension.** Add theme-derived roles for page, surface, elevated surface, foreground, supporting/muted text, border, primary/secondary brand accents, focus, selected, success, warning, error and scrim. Do not read draft brand-token JSON.
- [ ] **Step 4: Write widget tests.** Assert action variants expose accessible labels and disabled/loading states; artwork handles missing/failed images; state panels support loading/empty/error/offline/retry without clipping.
- [ ] **Step 5: Implement shared primitives.** Components must expose content/child slots and state; avoid page-specific assumptions or generic card wrappers.
- [ ] **Step 6: Verify theme/accessibility cases.** Run: flutter test test/experience/experience_palette_test.dart test/experience/experience_widgets_test.dart test/app_palette_test.dart test/ambient_theme_test.dart. Expected: PASS; also verify text scale and RTL in widget tests.
- [ ] **Step 7: Commit.** Commit as feat: add 7xPlay experience design foundation.

### Task 3: Introduce the new experience root and navigation contract

**Files:**
- Create: lib/experience/app/experience_root.dart
- Create: lib/experience/navigation/experience_destination.dart
- Create: lib/experience/navigation/experience_navigation.dart
- Create: lib/experience/handheld/experience_tab_controller.dart
- Create: lib/experience/handheld/experience_shell.dart
- Create: lib/experience/handheld/experience_navigation_bar.dart
- Create: lib/experience/handheld/experience_navigation_rail.dart
- Create: lib/experience/tv/tv_experience_shell.dart (temporary adapter to existing TV shell; replaced in Task 8)
- Modify: lib/screens/user/user_state.dart
- Modify: lib/flixquest_main.dart only where root wiring is required
- Test: test/experience/experience_root_test.dart
- Test: test/experience/experience_navigation_test.dart
- Regression: test/app_presentation_test.dart, test/mobile_shell_test.dart, test/app_session_state_store_test.dart

**Interfaces:**
- ExperienceDestination exposes id, labelKey, fromId(String?), and fromDefaultHome(DefaultHome); stable IDs map home, new, discover, search, mine.
- ExperienceRoot accepts required DevicePresentation devicePresentation and required bool isAuthenticated, and selects new landing, handheld/tablet or TV experience. Until Tasks 6 and 8 replace them, the signed-out landing and TV shell may be isolated compatibility adapters to the existing implementations.
- ExperienceTabController exposes current, select(destination), restore(destination), reselect(), scrollController(destination), and add/remove reset listeners.
- ExperienceNavigation provides typed helper methods for in-app pushes/pops while retaining Flutter Navigator and the existing root navigator key.

- [ ] **Step 1: Write destination compatibility tests.** Assert the exact existing stable IDs, legacy ID decoding, default-home mapping, and library label separation from persisted ID.
- [ ] **Step 2: Run the tests to verify they fail.** Run: flutter test test/experience/experience_navigation_test.dart -v. Expected: FAIL because ExperienceDestination and ExperienceTabController are absent.
- [ ] **Step 3: Implement destination and tab state.** Preserve lazy tab creation, scroll-to-top/reselect behavior, state retention, restoration and SharedPreferences writes without importing the old MobileShell.
- [ ] **Step 4: Write root-switching tests.** Assert handheld/TV selection, signed-out landing, authenticated entry, and runtime mode changes clear incompatible routes and update presentation service state.
- [ ] **Step 5: Implement ExperienceRoot and navigation helpers.** Keep the existing SessionGate, navigator key, update gates, top-level overlays and app lifecycle services. Do not create duplicate runtime initialization or add a routing package.
- [ ] **Step 6: Build the shell frame.** Add a distinct handheld navigation dock and tablet rail, with new visual hierarchy and focus/semantics. The five destinations can temporarily render migration placeholders only within this task; no legacy page becomes the end-state screen.
- [ ] **Step 7: Route UserState through ExperienceRoot.** Keep the old active root available only as a temporary rollback bridge and record its removal condition.
- [ ] **Step 8: Run navigation regressions.** Run: flutter test test/experience/experience_root_test.dart test/experience/experience_navigation_test.dart test/app_presentation_test.dart test/mobile_shell_test.dart test/app_session_state_store_test.dart test/home_widget_navigation_test.dart test/home_widget_deep_link_test.dart.
- [ ] **Step 9: Commit.** Commit as feat: add 7xPlay experience root and navigation.

### Task 4: Rebuild the complete handheld and tablet primary destinations

**Files:**
- Create: lib/experience/handheld/screens/home_screen.dart
- Create: lib/experience/handheld/screens/new_and_hot_screen.dart
- Create: lib/experience/handheld/screens/discover_screen.dart
- Create: lib/experience/handheld/screens/search_screen.dart
- Create: lib/experience/handheld/screens/library_screen.dart
- Create: lib/experience/handheld/widgets/spotlight_stage.dart
- Create: lib/experience/handheld/widgets/editorial_rail.dart
- Create: lib/experience/handheld/widgets/ranked_media_list.dart
- Create: lib/experience/handheld/widgets/continue_watching_strip.dart
- Create: lib/experience/handheld/widgets/library_collection_grid.dart
- Create/update: test/experience/handheld_primary_screens_test.dart
- Reference/adapt: existing catalog controllers, HomeFeedController, Search controllers, BookmarkProvider, RecentProvider, PlaylistProvider, SettingsProvider and relevant repositories.
- Replace active legacy screen imports in: lib/experience/handheld/experience_shell.dart

**Interfaces:**
- Each screen receives its existing data dependencies through constructors or feature adapters; each screen owns only presentation state. The shell owns selected destination and tab lifecycle.
- Home uses spotlight/editorial discovery and continue-watching as distinct content structures; New & Hot uses release/trending groupings; Discover uses browse/category/filter composition; Search uses query/result/history states; Library uses saved/progress/playlist/download entry points.

- [ ] **Step 1: Add failing widget tests for five distinct layouts.** Assert each screen has its own semantic page identity and composition, loading/empty/error states, and core actions. Assert no old HomeScreen, NewAndHotScreen, DiscoverScreen, SearchScreen or MyFlixQuestScreen is mounted.
- [ ] **Step 2: Run the new tests and confirm they fail.** Run: flutter test test/experience/handheld_primary_screens_test.dart -v.
- [ ] **Step 3: Implement Home and New & Hot.** Use current feed/release providers and existing localization strings; build different hero/editorial/list layouts, not a shared generic grid.
- [ ] **Step 4: Implement Discover and Search.** Preserve current query, history, filter, pagination and open-title semantics; provide keyboard, no-result, network-error and retry states.
- [ ] **Step 5: Implement Library.** Preserve bookmark/watchlist, playlist, history/continue-watching and download entry points; use the new library composition rather than renaming the old dashboard.
- [ ] **Step 6: Add adaptive layouts.** Test phone portrait, landscape, tablet and narrow split-screen widths; tablets use intentional multi-column/max-width compositions rather than stretched phone rows.
- [ ] **Step 7: Verify feature parity.** Run: flutter test test/experience/handheld_primary_screens_test.dart test/home_feed_controller_test.dart test/home_catalog_test.dart test/continue_watching_test.dart test/new_and_hot_screen_test.dart test/discover_screen_test.dart test/search_screen_test.dart test/my_flixquest_screen_test.dart test/mobile_shell_test.dart.
- [ ] **Step 8: Commit.** Commit as feat: rebuild 7xPlay handheld primary destinations.

### Task 5: Rebuild catalogue, detail, library subflows and supporting pages

**Files:**
- Create: lib/experience/handheld/screens/title_details_screen.dart
- Create: lib/experience/handheld/screens/season_screen.dart
- Create: lib/experience/handheld/screens/episode_screen.dart
- Create: lib/experience/handheld/screens/person_screen.dart
- Create: lib/experience/handheld/screens/collection_screen.dart
- Create: lib/experience/handheld/screens/playlist_screen.dart
- Create: lib/experience/handheld/screens/downloads_screen.dart
- Create: lib/experience/handheld/screens/live_tv_screen.dart
- Create: lib/experience/handheld/screens/provider_selection_screen.dart
- Create: lib/experience/handheld/screens/manual_source_screen.dart
- Create: lib/experience/handheld/screens/server_status_screen.dart
- Create: lib/experience/handheld/screens/image_viewer_screen.dart
- Create: lib/experience/handheld/screens/photo_viewer_screen.dart
- Create: lib/experience/handheld/widgets/title_action_cluster.dart
- Create: lib/experience/handheld/widgets/episode_chapter_list.dart
- Create: lib/experience/handheld/widgets/credits_gallery.dart
- Create/update: test/experience/handheld_detail_flows_test.dart
- Modify: experience-owned navigation registry and route compatibility adapters
- Regressions: test/title_details_screen_test.dart, test/season_episode_screens_test.dart, test/collection_screen_test.dart, test/mobile_playlists_screens_test.dart, test/downloads_screen_test.dart, test/live_tv_error_test.dart, test/provider_order_test.dart

**Interfaces:**
- Title, season, episode, person, collection, playlist and download screens consume existing domain models and source/repository interfaces; they do not perform network calls inside build methods.
- Navigation accepts existing media identifiers and intent arguments so deep-link, notification, and home-widget entry points can route into the new screens without changing external formats.

- [ ] **Step 1: Add route-contract tests.** Verify movie/series/season/episode/person/collection navigation and direct deep-link entry resolve to the correct new presentation screen.
- [ ] **Step 2: Run the tests and confirm they fail.** Run: flutter test test/experience/handheld_detail_flows_test.dart -v.
- [ ] **Step 3: Implement title, season and episode pages.** Create distinct editorial title details, season overview and episode-selection layouts; preserve play/resume, bookmark, watch provider, cast, trailer, recommendations and progress behaviors.
- [ ] **Step 4: Implement people and collection pages.** Use credit-focused and collection-specific compositions instead of reusing title-detail scaffolds.
- [ ] **Step 5: Implement playlist and downloads pages.** Preserve import/share, playlist mutations, download selection, offline entry and current empty/error behavior.
- [ ] **Step 6: Implement Live TV browsing, provider/source utilities and image viewing.** Preserve live category/channel behavior, provider ordering/status, manual-source handoffs, and image/photo viewer gestures, zoom and back behavior; keep playback itself in Task 7.
- [ ] **Step 7: Verify existing behavior and new UI.** Run: flutter test test/experience/handheld_detail_flows_test.dart test/title_details_screen_test.dart test/season_episode_screens_test.dart test/collection_screen_test.dart test/mobile_playlists_screens_test.dart test/downloads_screen_test.dart test/live_tv_error_test.dart test/live_channel_letters_test.dart test/provider_order_test.dart test/video_provider_order_test.dart test/details_play_test.dart test/episode_cast_test.dart.
- [ ] **Step 8: Commit.** Commit as feat: rebuild 7xPlay catalogue and library subflows.


### Task 6: Rebuild account, settings, Plus, wellness, AI and system surfaces

**Files:**
- Create: lib/experience/handheld/screens/landing_screen.dart
- Create: lib/experience/handheld/screens/sign_in_screen.dart
- Create: lib/experience/handheld/screens/sign_up_screen.dart
- Create: lib/experience/handheld/screens/recovery_screen.dart
- Create: lib/experience/handheld/screens/profile_screen.dart
- Create: lib/experience/handheld/screens/account_screens.dart
- Create: lib/experience/handheld/screens/settings_screen.dart
- Create: lib/experience/handheld/screens/plus_screen.dart
- Create: lib/experience/handheld/screens/plus_payment_screen.dart
- Create: lib/experience/handheld/screens/wallet_screen.dart
- Create: lib/experience/handheld/screens/wellness_screen.dart
- Create: lib/experience/handheld/screens/ai_screen.dart
- Create: lib/experience/handheld/screens/support_screens.dart
- Create: lib/experience/handheld/screens/system_screens.dart
- Create: lib/experience/handheld/widgets/settings_group.dart
- Create: lib/experience/handheld/widgets/account_identity_panel.dart
- Create/update: test/experience/handheld_support_flows_test.dart
- Reuse existing auth/session, settings, billing, wellness, notification and AI view models/controllers.
- Update active imports through the experience navigation registry; preserve localization identifiers.

**Interfaces:**
- Each page binds to existing presentation view models/controllers and calls their existing public actions. UI must not duplicate auth, billing, wellness, AI, or persistence business logic.
- The user-visible assistant name is 7x AI; keep existing flix_ai localization keys, FlixAiScreen/controller/repository symbols and /flix-ai route identifier unless an external compatibility-safe migration is proven necessary.

- [ ] **Step 1: Add behavior tests.** Pin guest/auth state, profile actions, theme/language selections, player preferences, Plus/payment entry, wellness metrics, 7x AI chat states, update/about/support routes.
- [ ] **Step 2: Run the tests and confirm they fail for the new screens.** Run: flutter test test/experience/handheld_support_flows_test.dart -v.
- [ ] **Step 3: Implement account and profile screens.** Preserve account transitions, guest mode, sign-in/out, device limits and local account-data behavior.
- [ ] **Step 4: Implement settings and support/system screens.** Preserve every existing setting, theme mode, language, playback preference, subtitle/audio preference, sync, update, About, feedback, support, account deletion and device/session action.
- [ ] **Step 5: Implement Plus, wellness and 7x AI.** Rebuild the screen composition while using existing controllers/repositories and payment/chat contracts.
- [ ] **Step 6: Verify support-flow regressions.** Run: flutter test test/experience/handheld_support_flows_test.dart test/presentation/auth_screens_test.dart test/plus_screens_test.dart test/wellness_dashboard_widgets_test.dart test/wellness_insights_test.dart test/flix_ai_screen_test.dart test/settings_kit_test.dart test/app_mode_settings_test.dart test/language_names_test.dart.
- [ ] **Step 7: Commit.** Commit as feat: rebuild 7xPlay account and system experiences.

### Task 7: Rebuild movie, series, Live TV and offline player presentation

**Files:**
- Create: lib/experience/player/player_presentation_state.dart (PlayerPresentationState and PlayerPresentationCallbacks)
- Create: lib/experience/player/player_surface.dart
- Create: lib/experience/player/player_controls.dart
- Create: lib/experience/player/player_context_panel.dart
- Create: lib/experience/player/player_sources_sheet.dart
- Create: lib/experience/player/player_subtitles_sheet.dart
- Create: lib/experience/player/live_player_surface.dart
- Create: lib/experience/player/offline_player_surface.dart
- Create/update: test/experience/player_presentation_test.dart
- Integrate with: lib/screens/common/player.dart, lib/screens/common/live_player.dart, lib/screens/common/offline_player_screen.dart, lib/screens/common/player/**
- Preserve all existing player services, source models and BetterPlayer controllers.

**Interfaces:**
- PlayerPresentationState is an immutable UI snapshot with playing, buffering, position, duration, seekable, live, mediaTitle, optional episodeTitle, and optional errorLabel fields.
- PlayerPresentationCallbacks exposes onPlayPause: VoidCallback, onSeek: ValueChanged<Duration>, onNextEpisode: VoidCallback, onPreviousEpisode: VoidCallback, onOpenSources: VoidCallback, onOpenAudio: VoidCallback, onOpenSubtitles: VoidCallback, onOpenSettings: VoidCallback, and onExit: VoidCallback.
- Player presentation receives this snapshot and callbacks from the existing player state/controller boundary. It does not resolve sources, choose providers, mutate audio policy, persist progress, or control BetterPlayer directly.
- Extract only the minimum stable UI-state contract needed from PlayerOne; do not invent a second playback state machine.

- [ ] **Step 1: Inventory PlayerOne state and build failing presentation contract tests.** Cover playing/buffering/error, progress/seeking, movie versus series, source/audio/subtitle sheets, TV controls, landscape/fullscreen/minimized transitions and offline/live variants.
- [ ] **Step 2: Run the tests and confirm they fail.** Run: flutter test test/experience/player_presentation_test.dart -v.
- [ ] **Step 3: Extract a presentation-only player surface contract.** Keep playback lifecycle, provider orchestration, subtitle/audio policy, ads, wake lock, progress saving and BetterPlayer wiring in current owners.
- [ ] **Step 4: Implement new movie/series controls and context.** Build a distinct immersive player chrome with clear transport, title/episode context, source and subtitle/audio access, next episode and error states.
- [ ] **Step 5: Implement live and offline presentation variants.** Keep channel switching and offline-specific metadata/actions separate from movie/series controls where their behavior differs.
- [ ] **Step 6: Regress player behavior.** Run: flutter test test/experience/player_presentation_test.dart test/unified_playback_compile_test.dart test/unified_playback_language_service_test.dart test/preferred_audio_language_policy_test.dart test/player_route_handoff_test.dart test/player_background_save_test.dart test/player_completion_detector_test.dart test/player_sheet_ui_test.dart test/live_playback_policy_test.dart test/offline_download_test.dart test/download_audio_selection_test.dart.
- [ ] **Step 7: Commit.** Commit as feat: rebuild 7xPlay playback presentation.

### Task 8: Rebuild the complete Android TV experience

**Files:**
- Create: lib/experience/tv/tv_experience_shell.dart
- Create: lib/experience/tv/tv_focus_controller.dart (thin experience adapter around existing TvFocusMemory and TvScreenFocusController; do not duplicate their state machine)
- Create: lib/experience/tv/tv_navigation_rail.dart
- Create: lib/experience/tv/screens/tv_landing_screen.dart
- Create: lib/experience/tv/screens/tv_auth_screen.dart
- Create: lib/experience/tv/screens/tv_home_screen.dart
- Create: lib/experience/tv/screens/tv_catalog_screen.dart
- Create: lib/experience/tv/screens/tv_search_screen.dart
- Create: lib/experience/tv/screens/tv_library_screen.dart
- Create: lib/experience/tv/screens/tv_detail_screen.dart
- Create: lib/experience/tv/screens/tv_collection_screen.dart
- Create: lib/experience/tv/screens/tv_shared_playlist_screen.dart
- Create: lib/experience/tv/screens/tv_playlist_import_screen.dart
- Create: lib/experience/tv/screens/tv_playlist_name_screen.dart
- Create: lib/experience/tv/screens/tv_profile_screen.dart
- Create: lib/experience/tv/screens/tv_settings_screen.dart
- Create: lib/experience/tv/screens/tv_plus_screen.dart
- Create: lib/experience/tv/screens/tv_wellness_screen.dart
- Create: lib/experience/tv/screens/tv_redeem_screen.dart
- Create: lib/experience/tv/screens/tv_live_screen.dart
- Create/update: test/experience/tv_experience_test.dart
- Reference/adapt: lib/tv/controllers/**, lib/tv/models/**, lib/tv/focus/**, lib/tv/navigation/**, lib/tv/player/** and existing repositories/controllers.

**Interfaces:**
- TvExperienceShell consumes DevicePresentation.television and existing TV controllers/services; TvFocusController owns focus memory/order and is independent from the visual rail.
- The TV shell uses large-screen-specific composition and remote-first input; it does not reuse handheld page layouts with larger spacing.

- [ ] **Step 1: Add failing TV experience tests.** Cover landing/auth, top-level navigation, focus order and restoration, back dispatch, keyboard search, media details/collections, library/playlists/import/name, profile/settings/Plus/wellness/redeem, live TV and player entry.
- [ ] **Step 2: Run the tests and confirm they fail.** Run: flutter test test/experience/tv_experience_test.dart -v.
- [ ] **Step 3: Implement TV shell and focus model.** Preserve stable destination IDs, focus return targets, directional behavior, TV back dispatcher and restoration.
- [ ] **Step 4: Implement TV browse, search, details and library.** Use remote-first large-screen layouts with different hierarchies for browse/catalogue/search/library; include collection and shared-playlist subflows and the TV import/name keyboards.
- [ ] **Step 5: Implement TV account, settings, Plus, wellness, playlists, redeem-code, live and player surfaces.** Retain the complete existing TV capability set and hook player routes into Task 7's presentation contract.
- [ ] **Step 6: Verify TV behavior.** Run: flutter test test/experience/tv_experience_test.dart test/tv_back_dispatcher_test.dart test/tv_back_key_guard_test.dart test/tv_remote_navigation_test.dart test/tv_shell_layout_test.dart test/tv_search_screen_test.dart test/tv_media_details_test.dart test/tv_library_screen_test.dart test/tv_settings_screen_test.dart test/tv_subtitle_timing_panel_test.dart.
- [ ] **Step 7: Commit.** Commit as feat: rebuild 7xPlay Android TV experience.

### Task 9: Remove legacy presentation roots and complete whole-app validation

**Files:**
- Modify: lib/screens/user/user_state.dart
- Modify: lib/flixquest_main.dart only to remove obsolete presentation-shell references after the new root is proven; keep its runtime/provider/overlay lifecycle wiring unless it is safely extracted with parity tests.
- Modify: lib/main.dart only if the runtime host is renamed or the app composition is extracted; retain the current bootstrap order and DI behavior.
- Modify/delete: legacy files identified as presentation-only in docs/superpowers/audits/2026-11-21-presentation-contract-inventory.md
- Retain: all services, controllers, repositories, providers, models, persistence and player-engine files still used by the new experience.
- Update: tests that asserted old widget classes, replacing them with experience behavior/contract assertions.
- Test: full existing test suite and all test/experience/** suites.

**Interfaces:**
- The production UserState route selects only the new ExperienceRoot. The FlixQuest runtime host may remain as a compatibility/runtime wrapper, but no production destination may import a legacy screen as its permanent body.
- Compatibility adapters remain only for external route/identifier stability and must each have an explicit removal rule or documented reason to remain.

- [ ] **Step 1: Add an architecture guard test.** Scan production experience imports and assert that the new shell does not import old mobile destination screens or old TV screen compositions.
- [ ] **Step 2: Run the guard test and confirm it fails while legacy imports remain.** Run: flutter test test/experience/legacy_presentation_guard_test.dart -v.
- [ ] **Step 3: Remove old root and page dependencies.** Delete obsolete presentation-only widgets/screens only after a repository-wide reference search proves there are no remaining callers. Do not delete services/controllers that retain behavior.
- [ ] **Step 4: Run formatting and static analysis.** Run: dart format lib/experience lib/screens/user/user_state.dart lib/flixquest_main.dart test/experience; flutter analyze. Expected: no analyzer errors and no new lint warnings.
- [ ] **Step 5: Run the full regression suite.** Run: flutter test. Expected: all existing and new tests pass.
- [ ] **Step 6: Run the Android build workflow.** Open/update the PR against main and verify the existing build-android.yml workflow passes with Flutter 3.41.5, the local BetterPlayer dependency and required TMDB_API_KEY secret. Expected: Android regression-tests and APK build jobs pass; inspect uploaded artifact before claiming an APK exists.
- [ ] **Step 7: Install and smoke-test the produced APK.** Verify first launch, guest/auth, Home/Search/Library navigation, title detail, movie/series playback, provider/audio/subtitle selection, Live TV, downloads/offline, settings/theme, Android back, TV navigation, and process restoration on available Android hardware/emulator.
- [ ] **Step 8: Commit final cleanup.** Commit as refactor: remove legacy 7xPlay presentation roots.

## Delivery sequence

1. Complete Tasks 1–3 before building feature pages: contracts, semantic design foundation, and new shell/navigation.
2. Complete Tasks 4–6 for the complete handheld/tablet experience.
3. Complete Task 7 and Task 8 as player and TV verticals against the shared presentation foundation.
4. Complete Task 9 only after every destination and overlay is migrated and the regression suite proves behavior parity.

The work is intentionally staged into independently reviewable commits. Do not merge a partial shell as the completed redesign; report each phase as partial until all nine tasks and acceptance checks are complete.


## Plan self-review

- **Spec coverage:** Tasks 1–9 cover the intent, protected runtime/player contracts, visual system, app composition, handheld primary destinations, content/details/library utilities, account/support/system flows, movie/series/live/offline player presentation, Android TV and final legacy removal/validation.
- **Interface consistency:** Task 3 produces ExperienceDestination, ExperienceTabController, ExperienceRoot and the handheld shell; Tasks 4–6 consume those contracts. Task 7 produces the player presentation snapshot/callback contract; Task 8 consumes it for TV playback surfaces. Task 9 verifies the production root and removes temporary adapters only after all consumers migrate.
- **Review Focus coverage:** restored IDs/default-home mapping is tested in Tasks 1 and 3; platform switching in Task 3 and Task 8; theme/accessibility in Task 2 and all layout tasks; deep-link/notification/home-widget handoffs in Tasks 1, 3 and 5; player behavior parity in Tasks 1 and 7–9.
- **Task sizing:** feature pages are grouped into vertical review slices so each slice can be tested independently. The implementer should still commit small coherent screen changes within each task rather than one monolithic UI commit.
- **Validation limitation:** the current authoring environment has no mounted repository checkout and no Flutter/Dart executable. The plan requires real test/build output from the repository's GitHub Actions runner before a task or APK can be marked complete. No test or build is claimed as run in this session.
- **Reviewer note:** no independent subagent tool is available; this plan was self-reviewed against the design and current source inventory. A self-review is not an independent code review of a future implementation.
