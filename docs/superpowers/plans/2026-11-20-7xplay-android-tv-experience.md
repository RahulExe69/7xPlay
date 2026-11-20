# 7xPlay Android TV Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans) to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Redesign the entire Android TV experience as a cinematic, remote-first 7xPlay product while preserving TV navigation, focus, content, account and playback contracts.

**Architecture:** Evolve TV-specific design tokens and components, then redesign the TV shell, navigation, browse/content/library/account/support destinations and dialogs using TV-first composition. Keep D-pad and focus behaviour as a first-class architecture; player control UI itself is implemented in the dedicated player plan.

**Tech Stack:** Flutter 3.35.7, Dart, Material 3, existing TV design/focus/navigation classes, Provider, Flutter widget/unit tests.

**Spec:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Global Constraints
- Scope includes every Android TV screen and supporting TV surface under lib/tv/**.
- Preserve D-pad/remote key mappings, focus traversal, focus restoration, back dispatch, keyboard input, overscan/safe areas and existing TV route semantics.
- Keep TV-specific layouts and focus targets; do not transplant touch-first mobile bottom navigation, sheets or gestures onto TV.
- Preserve catalogue data, title identifiers, provider selection, playback route hand-off, account/session, settings values, persistence, analytics, ads, billing and sync contracts.
- The dedicated player plan owns TV player controls in lib/tv/player/tv_player_screen.dart; this plan audits the route hand-off and player entry/exit, but does not duplicate player UI work.
- Preserve Dark, AMOLED, Light, custom/dynamic, seasonal and ambient theme behaviour as supported by the TV app; keep all supported translations and Arabic RTL.
- New user-facing strings belong in runtime translation JSON files assets/translations/en.json, es.json, ar.json, and hi.json.
- Keep changes in TV-specific files where possible. A change to shared tokens/widgets must be verified against handheld callers.
- Do not change the playback engine, stream resolution, provider aggregation, unified audio selector or subtitle timing policy.
- Use .fvm/flutter_sdk/bin/dart format, .fvm/flutter_sdk/bin/flutter test, and .fvm/flutter_sdk/bin/flutter analyze.
- Keep PR #24 draft; no merge or release APK workflow is authorised by this plan.

## Review Focus
1. Remote focus is lost or trapped after navigation, dialogs, loading or route return: focus restores to a useful, visible control.
2. Compact/overscan layouts: no nav item, button, title, state panel or dialog action is clipped beyond the TV safe area.
3. Async content refresh: loading/empty/error transitions do not discard focus or hide already loaded content.
4. Long titles, descriptions, locale strings and Arabic RTL: typography remains readable at viewing distance and layout direction is correct.
5. Account/profile/payment forms and on-screen keyboards: remote-only completion, validation and dismissal remain possible.

---

## Task 1: Audit TV architecture and define the visual system

**Files**
- Review: lib/tv/app/tv_design.dart, lib/design/app_brand.dart, lib/design/app_palette.dart, lib/design/app_tokens.dart.
- Review: all current lib/tv/widgets/*.dart and lib/tv/screens/*.dart.
- Test: test/tv_palette_test.dart, test/tv_loading_skeletons_test.dart, test/app_palette_test.dart.
- Create: docs/superpowers/audits/2026-11-20-android-tv-component-map.md.

**Interfaces**
- Consumes current TV palette/design tokens, brand roles and TV-specific widget APIs.
- Produces a map of existing TV components and call sites, identifying retain/revise/replace decisions without coupling TV layouts to mobile.

- [ ] Inventory every file under lib/tv/app, navigation, focus, screens, widgets, and player; map each widget to a screen and relevant tests.
- [ ] Map TvDesign, TvPageHeader, TvNavigationRail, TvSpotlight, TvContentGrid, TvContentRow, TvPosterWall, TvStatePanel, TvBrowseSkeleton, TvDialog, TvPillButton and form/keyboard widgets.
- [ ] Add palette/contrast assertions for approved 7xPlay warm brand roles on the TV canvas and confirm shared token changes do not regress phone/tablet themes.
- [ ] Define TV visual rules for viewing distance, content density, spotlight/backdrop use, row/grid rhythm, focus rings, selected/disabled states, safe-area spacing and motion.
- [ ] Record all files that own presentation versus focus, navigation, data/controller or platform behavior in the TV component map.
- [ ] Run focused TV palette/skeleton tests and commit the audit before screen re-composition.

**Task gate:** The TV system has its own component responsibilities and design rules; no focus/navigation contracts change in this task.

## Task 2: Redesign TV shell, navigation rail and focus/back transitions

**Files**
- Modify: lib/tv/app/tv_home_shell.dart, tv_shell_layout.dart, lib/tv/widgets/tv_navigation_rail.dart.
- Review: lib/tv/navigation/tv_back_dispatcher.dart, tv_back_key_guard.dart, lib/tv/focus/tv_focus_memory.dart, tv_focusable.dart, tv_keymap.dart, tv_screen_focus_controller.dart.
- Test: test/tv_shell_layout_test.dart, tv_navigation_rail_test.dart, tv_remote_navigation_test.dart, tv_back_dispatcher_test.dart, tv_back_key_guard_test.dart.

**Interfaces**
- Consumes current TV route model, selected destination, focus memory/controller, keymap and back dispatcher.
- Produces a redesigned shell and rail with identical route/focus semantics and visually coherent 7xPlay identity.

- [ ] Add tests for destination order/selection, D-pad movement, tab/page transition, focus restore after route pop, Back dispatch and repeated Back handling.
- [ ] Run the existing shell, rail, remote and Back tests before UI changes.
- [ ] Recompose the TV shell/rail around the new wordmark, brand palette, clear selected-state hierarchy and focus ring; keep the TV navigation model and all destinations.
- [ ] Preserve focus memory keys, key mappings, back-dispatch order, focus-node ownership and TV-specific safe areas.
- [ ] Add tests for focus visibility at common TV resolutions and overscan insets; verify no navigation destination is hidden by constrained height.
- [ ] Run the full shell/focus suite and format touched files.

**Task gate:** All destinations and back/remote behaviours remain usable without pointer input.

## Task 3: Redesign TV Home, catalogue, search, live browsing and sport selection

**Files**
- Modify: lib/tv/screens/tv_home_screen.dart, tv_catalog_screen.dart, tv_search_screen.dart, tv_live_screen.dart.
- Review/modify: lib/tv/widgets/tv_browse_view.dart, tv_spotlight.dart, tv_content_row.dart, tv_content_grid.dart, tv_search_keyboard.dart, tv_sport_picker.dart, tv_browse_skeleton.dart, tv_loading_skeletons.dart.
- Test: test/tv_browse_view_test.dart, tv_search_screen_test.dart, tv_search_keyboard_test.dart, tv_search_history_controller_test.dart, tv_sport_picker_test.dart, tv_loading_skeletons_test.dart; create test/tv_home_composition_test.dart, test/tv_catalog_composition_test.dart and test/tv_live_screen_test.dart.

**Interfaces**
- Consumes current TV catalogue/search/live data sources, search history, sports preferences and existing open-details/open-player callbacks.
- Produces distinctive TV browse pages with content-led focusable rows/grids and stable loading/empty/error compositions.

- [ ] Add Home tests for featured/continue-watching ordering, row isolation, missing artwork and focus after asynchronous row refresh.
- [ ] Add catalogue/search/live tests for selected segment/filter, query/history, results, empty state, retry and focus restoration.
- [ ] Run existing TV browse/search/keyboard/history/sport/skeleton tests.
- [ ] Redesign TV Home spotlight and content rows with a clear hero/continue-watching/editorial hierarchy; do not invent content or change catalogue ranking.
- [ ] Redesign catalogue and search for TV reading distance, remote-first filters and keyboard submission; preserve query/history keys and search requests.
- [ ] Redesign Live TV browse for channel identity, programme context, schedule, groups and sports selection. Preserve channel IDs, provider/service callbacks, schedule time handling and route to the dedicated player.
- [ ] Keep focus in a useful position when a section refreshes or fails; preserve loaded rows and isolate optional failures.
- [ ] Run all relevant TV browse/search/live tests.

**Task gate:** Home, catalogue, search and Live TV browsing are materially redesigned and fully operable by remote.

## Task 4: Redesign TV title details, collections and artwork/grid components

**Files**
- Modify: lib/tv/screens/tv_media_details_screen.dart, tv_collection_screen.dart.
- Review/modify: lib/tv/widgets/tv_media_card.dart, tv_poster_wall.dart, tv_top_ten_rank.dart, tv_content_grid.dart, tv_content_row.dart, tv_page_header.dart.
- Test: test/tv_media_details_test.dart, tv_collection_screen_test.dart, tv_poster_wall_test.dart, tv_title_logos_test.dart; create test/tv_media_details_composition_test.dart.

**Interfaces**
- Consumes existing TV MediaItem/detail models, catalogue paging, artwork/title-logo helpers and current Play/Resume/download/list/share callbacks.
- Produces artwork-led, remote-first title and collection layouts without changing route or content semantics.

- [ ] Add tests for movie versus series, missing artwork/logo, Play/Resume gating, action visibility, collection paging and focus preservation.
- [ ] Run existing TV details/collection/poster-wall/logo tests.
- [ ] Recompose title identity, synopsis, metadata, primary action, secondary actions, season/episode entry and related content to suit TV viewing distance.
- [ ] Recompose collections and poster walls with stable paging, predictable focus movement and useful empty/retry states.
- [ ] Preserve title IDs, feature flags, ad positions, playback callbacks and focus restoration.
- [ ] Run all TV detail/catalogue regression tests.

**Task gate:** Details and collection pages have distinct layouts with complete remote-accessible action coverage.

## Task 5: Redesign TV library, profile, auth, settings, playlists, Plus and wellness

**Files**
- Modify: lib/tv/screens/tv_library_screen.dart, tv_profile_screen.dart, tv_auth_screen.dart, tv_settings_screen.dart, tv_plus_screen.dart, tv_wellness_screen.dart, tv_playlist_import_screen.dart, tv_playlist_name_screen.dart, tv_shared_playlist_screen.dart, tv_redeem_code_screen.dart, tv_landing_screen.dart.
- Review/modify as needed: lib/tv/widgets/tv_playlist_picker.dart, tv_device_limit_picker.dart, tv_shortcut_tile.dart, tv_plus_reminder.dart.
- Test: test/tv_library_screen_test.dart, tv_profile_screen_test.dart, tv_settings_screen_test.dart, tv_wellness_screen_test.dart, tv_telegram_channel_prompt_test.dart, tv_localization_test.dart; create test/tv_account_composition_test.dart, test/tv_playlist_flows_test.dart and test/tv_plus_screen_test.dart.

**Interfaces**
- Consumes existing TV session/account state, settings values, library/download/playlist data, Plus controller and wellness metrics.
- Produces clear TV-first personal/account screens with unchanged account, billing, playlist, settings and metric behaviour.

- [ ] Add tests for guest/signed-in state, offline/local data availability, profile action reachability, settings value persistence, playlist import/rename/share, Plus state and wellness empty/error/data.
- [ ] Run the existing library/profile/settings/wellness/localization tests.
- [ ] Redesign library/profile/auth/settings/account screens for remote-first scanning and clear state hierarchy; retain all existing routes and actions.
- [ ] Redesign playlist, shared playlist, import, name and redeem flows with focusable form controls and clear validation/error/cancel behaviour.
- [ ] Redesign Plus and Wellness without fabricating prices, entitlements, wallet data or metric values.
- [ ] Keep account/session, billing, sync, playlist, persistence and data-source contracts unchanged.
- [ ] Run all TV library/account/playlist/Plus/wellness tests.

**Task gate:** TV personal/account/support flows remain functionally identical and usable with remote-only input.

## Task 6: Redesign TV dialogs, controls, keyboard, loading and global support states

**Files**
- Review/modify: lib/tv/widgets/tv_dialog.dart, tv_state_panel.dart, tv_form_keyboard.dart, tv_search_keyboard.dart, tv_list_row.dart, tv_pill_button.dart, tv_update_gate.dart, tv_update_widgets.dart, tv_telegram_channel_prompt.dart, tv_continue_watching_menu.dart, tv_provider_order_dialog.dart.
- Test: test/tv_form_keyboard_test.dart, tv_provider_order_dialog_test.dart, tv_update_test.dart, tv_telegram_channel_prompt_test.dart, tv_remote_navigation_test.dart, tv_loading_skeletons_test.dart; create test/tv_dialog_accessibility_test.dart.

**Interfaces**
- Consumes current TV widget APIs and all existing callback, focus and dismissal contracts.
- Produces a coherent set of TV dialogs, menus, skeletons, error/empty/update states and remote-first inputs.

- [ ] Inventory every dialog/menu and its caller, required action, destructive confirmation and focus-return target.
- [ ] Add tests for default focus, directional traversal, confirm/cancel, Back dismissal, semantic labels, compact height and focus restoration to the invoking element.
- [ ] Recompose dialogs, menus, form/search keyboards, update states and loading/empty/error surfaces with consistent 7xPlay visual hierarchy.
- [ ] Keep all controls operable by D-pad/remote; pointer support may remain supplementary.
- [ ] Run owning screen tests and translation validation; format/analyze touched files.

**Task gate:** No TV dialog or transient surface strands focus, hides its exit action or exposes an unusable touch-only interaction.

## Task 7: Full Android TV validation and integration

**Files**
- Test: all TV tests referenced above plus test/tv_back_dispatcher_test.dart, tv_back_key_guard_test.dart, tv_remote_navigation_test.dart, tv_shell_layout_test.dart, tv_palette_test.dart, tv_update_test.dart.
- Review: docs/superpowers/audits/2026-11-20-android-tv-component-map.md.

- [ ] Run the complete TV test group and translation catalog.
- [ ] Run Flutter analysis; distinguish pre-existing failures from regressions.
- [ ] Visually inspect TV Home, catalogue, details, collection, library, settings, auth, playlist, Plus, Wellness, Live TV and dialogs on TV aspect ratios/resolutions and overscan-safe bounds.
- [ ] Walk through every route using only D-pad/remote: enter, navigate, select, scroll, open modal, cancel, Back, return, resume focus.
- [ ] Confirm mobile/tablet tests remain green after any shared token/widget changes.
- [ ] Verify player routes still hand off to the dedicated player workstream and return focus to the originating screen.
- [ ] Record screenshots and pass/fail evidence in the component map; update checkboxes only from observed results.

**Workstream completion gate**
- [ ] Every existing lib/tv/** destination and supporting UI has a deliberate 7xPlay composition.
- [ ] Remote navigation, focus, keyboard, back, safe-area and account/content contracts pass.
- [ ] No mobile-only layout has been forced onto TV; player UI is covered by the dedicated player plan.
- [ ] TV and shared regression tests plus visual remote walkthrough are complete.
