# 7xPlay YouTube × FlixQuest Fusion Implementation Plan

Date: 2026-11-22
Branch: `feat/youtube-flixquest-fusion`
Base: `main` at `f330df2cbf1bd9a299fbea2c1e54fa265640b6f9`

## Constraints

- Preserve all runtime, playback, provider, catalogue, persistence, download, deep-link and platform contracts.
- Do not include PR #27 changes accidentally; keep its open branch independent.
- No new backend, account, dependency or schema.
- Keep Android TV navigation unchanged.
- Local Flutter/Dart SDK and checkout are not available in the authoring environment; use repository CI as the authoritative compiler/test runner and do not claim physical-device verification.

## Task 1 — Lock navigation compatibility tests

- Add/extend widget tests for stable tab IDs, Search access from the app bar, restored Search destination and tablet rail behavior.
- Confirm RED on the new behavior before implementation.
- Keep old IDs unchanged.

## Task 2 — Introduce shared 7xPlay top app bar

- Extend the existing Home, Explore, New & Hot and You headers with consistent Search entry points; avoid adding a parallel app-bar framework.
- Keep the 7xPlay wordmark and brand palette; respect safe areas, RTL, text scaling and semantics.
- Route Search through the existing `MobileTabController`; do not create a second search route.

## Task 3 — Rework phone navigation into a YouTube-familiar dock

- Retain stable tab enum IDs and controller behavior.
- Use a full-width edge-to-edge icon + label dock, browse-first ordering and accessible hit targets.
- Keep all destinations reachable, including Search, and retain stable IDs.
- Preserve tablet rail and TV shell.

## Task 4 — Convert Home into a hybrid feed

- Retain existing HomeFeedController, Hero, Continue Watching, recommendation and category data.
- Add up to three centered, max-width thumbnail-led feed cards per Home trending section using existing MediaItem, artwork and playback actions.
- Preserve selected genre/kind chips and horizontal OTT shelves; See all opens the complete trending collection.
- Ensure no fake views/likes/channel data are rendered.
- Add tests for card metadata, play/details actions and My List actions.

## Task 5 — Unify Search and Explore entry points

- Add top-bar Search access from Home, Explore, New & Hot and You.
- Present movie/series search results with full-width video-feed cards while preserving debounce/history/filter/person behavior.
- Refine Explore/New & Hot headers and card spacing to match the same browsing language while keeping their specialized OTT functions.
- Add navigation and widget regression tests.

## Task 6 — Preserve OTT detail and player continuity

- Audit title details, episode browser and player route boundaries.
- Keep the existing player and stream behavior intact; no global mini-player is added without a shared player-state host.
- Do not alter provider resolution, audio selection, stream recovery or downloads.
- Keep TV implementation unchanged.

## Task 7 — Accessibility, localization and responsive pass

- Add translation keys for new labels in all maintained locales.
- Check RTL, large text, reduced motion, tablet layout and touch targets.
- Ensure no old FlixQuest branding leaks into the new 7xPlay app chrome.

## Task 8 — Verification and review

- Run focused Flutter tests and the full workflow suite through GitHub Actions.
- Run formatting/analyzer and Android debug/release build jobs according to workflow policy.
- Inspect PR diff for unrelated changes and confirm PR #27 is unaffected.
- Request CodeRabbit review, address valid findings and rerun CI.
- Report any device-only checks that Rahul must perform on the latest APK.

## Completion definition

Do not call the redesign complete until all acceptance criteria in the design document are checked against the final diff and fresh CI evidence. A green fast-test job alone is not a substitute for the Android build or visual device testing.
