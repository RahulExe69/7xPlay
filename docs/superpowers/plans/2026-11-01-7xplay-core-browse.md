# 7xPlay Core Browse Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver the shared mobile visual foundation and redesign Home, New & Hot, Discover, and Search without changing catalogue or playback logic.

**Architecture:** Evolve current semantic theme tokens and focused mobile widgets, then compose the four browse destinations with distinct layouts. Keep MobileShell's five-tab contract and existing state restoration intact. Reuse current catalogue controllers and data sources; add presentation-only state only where the existing screen cannot express the required layout cleanly.

**Tech Stack:** Flutter 3.35.7 (pinned by .fvmrc), Dart, Material 3, Provider, easy_localization, existing catalogue services, Flutter widget/unit tests.

**Spec:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Global Constraints
- Target Android handheld UI only; do not change lib/tv/**.
- Keep the five root tab IDs: home, new, discover, search, mine.
- Keep playback, unified audio selection, provider aggregation/fallback, subtitles, download playback, and BetterPlayer behaviour unchanged.
- Do not change API/backend contracts, catalogue ranking, analytics IDs, persistence keys, deep-link formats, or account semantics.
- Use AppBrand, AppPalette, AppSpace, AppRadii, AppBreakpoints, and AppType before adding new tokens.
- New user-facing strings must exist in assets/translations/en.json, es.json, ar.json, and hi.json.
- Preserve Dark, AMOLED, Light, custom/dynamic, seasonal, and ambient themes. Do not assume every widget is on a dark canvas.
- Use directional layout APIs and preserve Arabic RTL.
- Preserve ad placement IDs and required placements; do not place ads over primary actions or before first useful content.
- Keep offline content usable; isolate network errors to their own sections.
- Use .fvm/flutter_sdk/bin/dart format, .fvm/flutter_sdk/bin/flutter test, and .fvm/flutter_sdk/bin/flutter analyze.
- Keep PR #24 draft until the workstream passes checks and visual review. Merge/release/build decisions are separate and not authorised by this plan.

## Review Focus
1. Missing artwork or broken image URLs: retain a themed fallback and stable card dimensions.
2. Slow or failed network sections: retain loaded content and isolate loading/error states.
3. Arabic RTL and long translated labels: directional actions, grids, and text must not overflow or reverse incorrectly.
4. Large text and narrow windows: primary actions remain usable at text scale 1.3 and compact phone widths.
5. Runtime theme changes: no hard-coded dark-only text, borders, or action colours on Light/custom/seasonal/ambient surfaces.

## Scope and order
This workstream owns the shared mobile visual foundation plus Home, New & Hot, Discover, and Search. My 7xPlay is handled in the personal-library plan. Title details and catalogue result destinations are handled in the content-journey plan. Execute Tasks 1–2 first, then Tasks 3–5 in order. Every task must leave the app runnable.

---

### Task 1: Review and tighten the shared mobile visual foundation

**Files**
- Review/modify: lib/design/app_brand.dart, app_palette.dart, app_tokens.dart.
- Review/modify: lib/mobile/widgets/page_kit.dart, section_header.dart, pill_button.dart.
- Test: test/app_palette_test.dart, test/app_brand_colors_test.dart, test/pill_button_test.dart.
- Create/update: docs/superpowers/audits/2026-11-01-mobile-component-map.md.

**Interfaces**
- Consumes the approved spec and current AppBrand, AppPalette, AppSpace, AppRadii, AppBreakpoints, and AppType APIs.
- Produces a component map identifying which current primitives are retained, revised, or deliberately not reused. Do not create a generic component merely to reduce line count.

- [ ] Add/extend palette tests for Dark, AMOLED, Light, custom/dynamic primary colour, and seasonal page colour. Assert text/action role contrast and pill foreground/background pairing.
- [ ] Run .fvm/flutter_sdk/bin/flutter test test/app_palette_test.dart test/app_brand_colors_test.dart test/pill_button_test.dart and confirm new tests fail for the intended reason.
- [ ] Map BrandAccentRule, PageAppBar, SearchPill, SectionHeader, PillButton, MediaArt, PosterCard, PosterRow, TopTenRow, and ContinueRow responsibilities and call sites. Explicitly flag repeated decorative accent rules that do not add hierarchy.
- [ ] Make only changes required by test evidence and the map. Add tokens only when at least two planned screens need the same value. Keep the signature gradient rare; do not make it a default full-page divider. Split a focused widget file only where a concrete reuse/responsibility boundary exists.
- [ ] Rerun palette, brand, pill, and affected component tests; format touched files and commit the component map plus foundation.

**Task gate:** Theme/contrast tests pass; no TV theme files changed; existing shared widget APIs remain source-compatible.

### Task 2: Preserve and refine the five-destination mobile shell

**Files**
- Review/modify: lib/mobile/app/mobile_shell.dart, mobile_tabs.dart, mobile_nav_bar.dart.
- Test: test/mobile_shell_test.dart, test/tablet_screens_test.dart, test/app_session_state_store_test.dart, test/home_widget_navigation_test.dart.

**Interfaces**
- Consumes MobileTab, MobileTabController, AppSessionStateStore, and the shared design tokens.
- Produces the same tab IDs and restoration/reselect behaviour with a coherent bottom bar and tablet rail.

- [ ] Extend mobile_shell_test.dart to assert Home=home, New & Hot=new, Discover=discover, Search=search, My 7xPlay=mine. Assert tab keep-alive, Back-to-Home, and reselect-to-top-then-reset behaviour.
- [ ] Run the shell, tablet, session-store and home-widget navigation tests. Do not loosen existing assertions to accommodate visual changes.
- [ ] Refine MobileNavBar and MobileNavRail only where the approved identity or density needs it. Preserve IDs, safe-area insets, focus/semantics, keep-alive bodies, restoration, analytics IDs, tablet threshold, and root-navigator detail routes.
- [ ] Add compact-width, Arabic RTL, and text-scale 1.3 cases where absent. Keep every destination visible and every navigation target usable.
- [ ] Rerun focused tests, format touched files, and commit.

**Task gate:** All five IDs and restoration semantics remain unchanged; phone/tablet tests pass; no lib/tv/** changes.

### Task 3: Redesign Home as an editorial landing page

**Files**
- Modify: lib/mobile/screens/home_screen.dart.
- Review/modify as needed: lib/mobile/widgets/hero_card.dart, media_art.dart, media_rows.dart, poster_card.dart, category_section.dart, skeletons.dart, section_header.dart.
- Test: test/home_screen_test.dart, test/home_feed_controller_test.dart, test/home_catalog_test.dart, test/continue_watching_test.dart, test/home_widget_navigation_test.dart.

**Interfaces**
- Consumes HomeFeedController/HomeFeed, MediaItem, RecentProvider data, existing artwork helpers, playback/detail/My List callbacks, and existing ad placement APIs.
- Produces an editorial Home composition rendering current feed data while routing actions through the same callbacks.

- [ ] Extend home_screen_test.dart: featured title and Continue Watching precede editorial rows; empty Continue Watching is omitted; ads do not appear above first useful content; one failed optional row does not hide loaded sections.
- [ ] Run Home, feed-controller, home-catalog and continue-watching tests. Do not rewrite catalogue ranking to fix a presentation integration.
- [ ] Recompose the page around a distinctive editorial feature, Continue Watching, and varied content modules. Retain source/controller interfaces, session-stable hero choice, existing row limits/deduplication, and all playback/Details/My List callbacks. Do not add sample content or backend requests.
- [ ] Keep loaded content visible during refresh. Give optional rows independent loading/retry states. Preserve ad placement IDs and place ads only at approved non-obstructive positions. Match skeleton geometry to final content.
- [ ] Run focused tests; visually inspect phone, tablet, Dark, AMOLED, Light and Arabic RTL. Confirm users can resume or start a title without first scrolling. Format and commit.

**Task gate:** Home hierarchy, Continue Watching, ad constraints, section isolation, and deep-link/widget navigation tests pass.

### Task 4: Redesign New & Hot and Discover as separate discovery tools

**Files**
- Modify: lib/mobile/screens/new_and_hot_screen.dart, discover_screen.dart.
- Review/modify as needed: lib/mobile/widgets/filter_chips.dart, genre_sheet.dart, poster_grid.dart, section_header.dart.
- Test: test/new_and_hot_screen_test.dart, test/new_and_hot_test.dart, test/discover_screen_test.dart; create test/poster_grid_test.dart if absent.

**Interfaces**
- Consumes NewAndHotCatalog, HotSegment, DiscoverQuery, MediaCollection and current catalogue APIs.
- Produces an editorial release/trending page and a filter-first browse page; results still route through CollectionScreen.

- [ ] Add tests that Coming Soon is future-only and date-sorted, Top 10 is capped at ten, stale segment responses cannot overwrite the selected segment, Discover keeps independent movie/series criteria, and active criteria/counts match their request URL.
- [ ] Run New & Hot, Discover, and poster-grid tests before editing.
- [ ] Recompose New & Hot around upcoming releases, currently popular titles and ranked lists. Keep HotSegment values, source, date locale, list caps and title/play/save callbacks. Do not invent release dates, rankings or reminder functionality.
- [ ] Recompose Discover around movie/series context, active criteria, filter choices and a clear result action. Retain DiscoverQuery URL serialization, count cache, adult/language settings and current results callback.
- [ ] Run focused tests and collection tests; visually check phone/tablet, Dark/AMOLED/Light and Arabic. Format and commit.

**Task gate:** Date/filter/request behaviour is unchanged; no invented data or unsupported controls; the pages have materially distinct compositions.

### Task 5: Redesign Search while preserving query and history semantics

**Files**
- Modify: lib/mobile/screens/search_screen.dart.
- Review/modify only if needed: lib/mobile/widgets/page_kit.dart, media_art.dart, poster_grid.dart.
- Test: test/search_screen_test.dart, test/mobile_search_history_test.dart, test/tmdb_proxy_search_test.dart.

**Interfaces**
- Consumes current search source/controller, recent-search preferences, adult/language settings and MobileTabScope lifecycle.
- Produces an integrated Search layout preserving request, recent-history, filter and return-navigation semantics.

- [ ] Extend search_screen_test.dart to assert the existing debounce issues one request for a typing burst, older responses are ignored, and current results remain visible while a new request loads.
- [ ] Extend mobile_search_history_test.dart to assert storage key recent_searches remains unchanged, history is saved only on existing submit/open points, and query/scroll return state is restored.
- [ ] Run search, history and TMDB proxy tests; record pre-existing failures separately.
- [ ] Recompose Search with clear hierarchy for query, recent searches, suggestions, mixed result types, filters and the Discover hand-off. Preserve search source contracts, debounce, stale-query guard, adult/language logic and keyboard submission semantics.
- [ ] Complete empty, no-result, error and return states. Retain query text through errors; preserve last results during the next request; check Arabic and text scale 1.3.
- [ ] Run Home, New & Hot, Discover, Search, navigation and shared-grid tests together. Format touched files, run flutter analyze, record visual review outcomes and commit.

**Task gate:** Search history and race tests pass; returning from details restores query/scroll; no persistence keys or API contracts change.

### Task 6: Redesign Live TV browsing without changing live playback

**Files**
- Modify: lib/screens/common/live_tv_screen.dart.
- Test: test/live_tv_error_test.dart, test/live_channel_letters_test.dart, test/live_schedule_sports_test.dart, test/live_stream_discovery_test.dart; create test/live_tv_screen_test.dart if absent.
- Explicitly out of scope: lib/screens/common/live_player.dart and live playback controls.

**Interfaces**
- Consumes current Live TV channel, schedule and discovery models/controllers plus existing open-live-player callbacks.
- Produces a clear channel/programme browsing surface while keeping channel IDs, schedule time handling and live-player hand-off unchanged.

- [ ] Add tests for channel grouping/letters, current and upcoming schedule labels, empty results, failed schedule requests and opening the selected channel with the same ID.
- [ ] Run the existing Live TV error, channel-letter, schedule and discovery tests.
- [ ] Recompose the Live TV browse page with clear channel identity, programme context and useful empty/error/retry state. Do not alter live-player controls, provider selection, stream resolution or playback.
- [ ] Check Arabic RTL, long channel names, narrow phone width and tablet layout. Verify failed schedule lookup does not hide the channel list.
- [ ] Run Live TV tests, format and analyze; commit the browse-page work.

**Task gate:** Live TV browse tests pass; live playback and player files remain unchanged.

## Workstream completion gate
- [ ] All five root tabs have a meaningful, task-specific composition.
- [ ] Relevant widget/unit tests pass and no new analyzer issues are introduced.
- [ ] Dark, AMOLED, Light and Arabic RTL phone reviews are recorded; tablet review is recorded for shell and responsive grids.
- [ ] TV, player, provider and audio-selection source files remain unchanged.
