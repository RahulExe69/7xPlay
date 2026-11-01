# 7xPlay Content Journey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver a coherent journey from catalogue card through title details, seasons, episodes, collections, people, and credits.

**Architecture:** Keep catalogue and playback decisions in existing controllers/models; redesign mobile presentation around the approved title-details direction. Retain useful PR #24 work, audit it against the approved design, and adapt rather than duplicate it. Keep existing route entry points stable.

**Tech Stack:** Flutter 3.35.7, Dart, Material 3, Provider, current catalogue models/services, existing mobile media widgets, Flutter widget/unit tests.

**Spec:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Global Constraints
- Target handheld presentation only; do not change lib/tv/**.
- Keep current route names, deep-link formats, MediaItem identifiers and catalogue data contracts.
- Do not change player, BetterPlayer, resume policy, unified audio selector, provider aggregation/fallback, subtitle or download-playback behaviour.
- Keep displayWatchNowButton gating and the existing availability check for unreleased titles.
- Keep existing download, My List, playlist, trailer, share, cast/crew and details actions.
- Preserve current ad placement IDs; ads remain inside the Details information area, never above the primary Play/Resume action.
- Preserve Dark, AMOLED, Light, custom/dynamic, seasonal, ambient and Arabic RTL presentation.
- Use .fvm/flutter_sdk/bin/flutter test, .fvm/flutter_sdk/bin/dart format, and .fvm/flutter_sdk/bin/flutter analyze.
- Do not merge PR #24 or trigger APK workflows as part of this plan.

## Review Focus
1. Movie vs series data shape: optional series metadata must not leave empty/incorrect sections.
2. Unreleased/unaired content: existing availability policy determines which actions are enabled.
3. Resume states: every CTA label must match existing watch-history and next-episode rules.
4. Missing posters, stills, logos and biographies: stable placeholders with no layout collapse.
5. Narrow width, tablet split layout, Arabic RTL and text scale 1.3: primary actions and episode rows remain usable.

---

## PR #24 mandatory audit
PR #24 currently changes title_details_screen.dart substantially (approximately 412 additions and 131 deletions), with shared page_kit.dart changes. Before replacing any part, review each changed section and record retained/revised/reverted decisions. Preserve working responsive layout, playback CTA, watch-list, playlist, trailer and details-tab work. The repeated BrandAccentRule treatment on browse pages is audited in the core-browse plan.

### Task 1: Audit and finish cinematic title details

**Files**
- Modify: lib/mobile/screens/title_details_screen.dart.
- Review/modify: lib/mobile/widgets/details_header.dart, details_parts.dart, episodes_section.dart, episode_row.dart, title_sheet.dart.
- Review: lib/mobile/widgets/media_art.dart, pill_button.dart, poster_card.dart, page_kit.dart.
- Test: test/title_details_screen_test.dart, test/details_play_test.dart, test/episode_cast_test.dart.

**Interfaces**
- Consumes MediaItem, current watch-history/resume data, existing title actions, displayWatchNowButton, downloads, playlist, trailer/share handlers and metadata.
- Produces an artwork-led details page with readable primary Play/Resume, secondary actions, overview, episode access and current details sections. Existing route entry points and callback semantics remain valid.

- [ ] Review every changed section in PR #24 title_details_screen.dart and shared page_kit.dart. Record retained/revised/reverted decisions in a short audit note. Check CTA, ad and feature-flag behaviour first.
- [ ] Extend title_details_screen_test.dart and details_play_test.dart for movie/series identity, resume-state labels, hidden Play when displayWatchNowButton is false, download availability, My List, trailer/share actions, selected season, long titles and missing artwork.
- [ ] Run .fvm/flutter_sdk/bin/flutter test test/title_details_screen_test.dart test/details_play_test.dart test/episode_cast_test.dart. Record pre-existing failures separately; do not change playback policy to fix a visual test.
- [ ] Complete the approved hierarchy: artwork/header, title identity, metadata, main CTA, download CTA, synopsis/cast/creator details, action row, season/episode area, and sticky information tabs. Keep ads within Details information, never above Play/Resume.
- [ ] Run the three tests plus test/tablet_screens_test.dart. Visually check phone, tablet, Dark, AMOLED, Light, Arabic RTL, and text scale 1.3. Commit after primary actions are visible and reachable.

**Task gate:** Resume and feature-flag tests pass; downloads, My List, playlists, trailers and share remain reachable; detail deep links still work.

### Task 2: Give collections and catalogue result grids a complete page treatment

**Files**
- Modify: lib/mobile/screens/collection_screen.dart.
- Review/modify: lib/mobile/widgets/poster_grid.dart, media_rows.dart, section_header.dart.
- Test: test/collection_screen_test.dart, test/discover_screen_test.dart; create test/poster_grid_test.dart if absent.

**Interfaces**
- Consumes MediaCollection, current catalogue paging/source and PosterCard/media-art helpers.
- Produces a paginated collection page and responsive grid preserving filters, pagination, title routes and empty/error behaviour.

- [ ] Add tests for 3-column phone, 5-column tablet and 6-column wide grids, poster aspect ratio, load-more behaviour, empty results, failed-page retry and missing poster paths.
- [ ] Run collection and Discover tests plus the new grid test; verify any failure is a presentation or existing source issue.
- [ ] Redesign collection title/context, active filter (when available), and sort/filter actions. Use only metadata supplied by the current collection model; never fabricate item counts.
- [ ] Refine grid density/gutters using existing posterGridColumns, posterGridDelegate, AppBreakpoints and card semantics unless tests show a concrete defect. Keep current pagination and result actions.
- [ ] Run collection, Discover and poster-grid tests, format and analyze; commit.

**Task gate:** Pagination/filter behaviour is intact; missing artwork never collapses a grid cell; phone/tablet/wide grid tests pass.

### Task 3: Redesign season and episode browsing

**Files**
- Modify: lib/mobile/screens/season_screen.dart, episode_screen.dart.
- Review/modify: lib/mobile/widgets/episodes_section.dart, episode_row.dart.
- Test: test/title_details_screen_test.dart, test/episode_cast_test.dart; create test/season_screen_test.dart and test/episode_screen_test.dart if absent.

**Interfaces**
- Consumes current season/episode models and existing navigation, play and download callbacks.
- Produces readable season and episode surfaces; playback delegates to the existing route and arguments.

- [ ] Add tests for season ordering, specials position, currently watched season selection, episode Play/Download/Details callbacks, and unaired disabled states as determined by existing logic.
- [ ] Run title-details and episode-cast tests plus the new screen tests.
- [ ] Compose season selection and episode rows so still, episode number/title, metadata, synopsis, progress and availability are individually scannable. Use directional layout and current MediaArt fallbacks.
- [ ] Assert exact existing media/episode identifiers are passed into callbacks. Do not implement a second resume algorithm or modify provider/audio selection.
- [ ] Run season, episode and details tests; format and analyze; commit.

**Task gate:** No playback routing, resume policy, provider/audio selection or download policy changes; season/episode tests pass.

### Task 4: Redesign people and credits surfaces

**Files**
- Modify: lib/mobile/screens/person_screen.dart, credits_screen.dart.
- Review/modify: lib/mobile/widgets/media_art.dart and relevant person/list widgets.
- Test: create test/person_screen_test.dart and test/credits_screen_test.dart; run test/episode_cast_test.dart.

**Interfaces**
- Consumes existing person, filmography, cast/crew and image data from catalogue sources.
- Produces distinct person-profile and title-credits compositions with current navigation callbacks and no invented biography/filmography fields.

- [ ] Add tests for no profile image, missing biography, empty filmography, missing role/department, mixed movie/series credits, long names, and one remote subsection failing while other sections remain visible.
- [ ] Run the new people/credits tests and episode-cast tests.
- [ ] Implement person identity first, then biography and filmography. Make credits roles scannable and media links obvious. Do not reuse the title-details hero composition for a person page.
- [ ] Add RTL and semantic-label cases. Verify missing photos keep a fixed avatar box and all themes have a readable fallback.
- [ ] Run title-details, collections, season/episode, credits, person, Discover and relevant deep-link/tablet tests; format and analyze; commit.

**Task gate:** People/credits sections fail independently, missing images remain stable, and each page preserves title navigation.

## Workstream completion gate
- [ ] Every content page has a materially distinct composition.
- [ ] Existing resume/availability/download/trailer/share logic remains authoritative.
- [ ] Relevant widget/unit tests pass; no new analyzer issues.
- [ ] Dark, AMOLED, Light, Arabic RTL and tablet reviews are recorded.
