# 7xPlay Full Android Application Redesign — Master Plan

**Status:** Design approved by Rahul on 2026-11-20; full-app planning completed on 2026-11-20; implementation not yet started from this expanded plan  
**Design:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md  
**Repository:** RahulExe69/7xPlay  
**Working branch:** redesign/phase-2-catalog-experience  
**Consolidated review surface:** PR #24 — https://github.com/RahulExe69/7xPlay/pull/24

## Mission and acceptance rule

Redesign the **entire Android application** as 7xPlay: Android phones, tablets, Android TV, movie/series playback, Live TV playback, offline playback, every navigation destination, supporting page, sheet, dialog, overlay, form, loading/empty/error state and responsive layout.

A screen is not complete because its palette, icon, title accent or border changed. Each screen needs a task-specific 7xPlay composition and a recorded behaviour/visual review. The existing capabilities and underlying data/playback/account contracts must remain intact.

The selected design approach is one shared, maintainable 7xPlay design system with platform-appropriate, independently composed screens. The visual identity is the supplied 7xPlay artwork: near-black/purple-black surfaces, warm gold/amber/orange-red primary identity, hot-pink/violet secondary identity. No cyan/blue palette substitution.

## Workstreams

The full project is split into six independently testable plans. The first four cover the handheld app; the final two cover player presentation and Android TV. All six are part of the same full-app acceptance gate.

| Order | Workstream | Plan | Main ownership |
|---|---|---|---|
| 1 | Core foundation and handheld browse | docs/superpowers/plans/2026-11-01-7xplay-core-browse.md | Shared visual foundation, mobile shell, Home, New & Hot, Discover, Search and handheld Live TV browse |
| 2 | Content journey | docs/superpowers/plans/2026-11-01-7xplay-content-journey.md | Title details, collections, seasons, episodes, people/credits, galleries and image-viewer journeys |
| 3 | Personal library | docs/superpowers/plans/2026-11-01-7xplay-personal-library.md | My 7xPlay, Downloads, My List/bookmarks, playlists, Wellness/Viewing Insights and offline-first presentation |
| 4 | Account and support | docs/superpowers/plans/2026-11-01-7xplay-account-support.md | Settings, auth/profile, language, sync/status/update/about, Plus/payment/wallet, 7x AI and supporting sheets/dialogs |
| 5 | Playback and player experience | docs/superpowers/plans/2026-11-20-7xplay-player-experience.md | Movie/series player, Live TV player, offline player, selectors/sheets/overlays, mini/fullscreen transitions where supported, and TV player UI |
| 6 | Android TV experience | docs/superpowers/plans/2026-11-20-7xplay-android-tv-experience.md | Complete TV shell, destinations, browse/content/library/account/support UI, dialogs, focus, remote and keyboard experience |

The core browse plan owns handheld Live TV browsing; the Android TV plan owns TV Live TV browsing; the player plan owns playback UI on all form factors. This avoids overlapping screen ownership.

## Repository inventory and screen ownership

This inventory was checked against the current PR branch tree on 2026-11-20. The relevant directories include:

- Handheld destinations and secondary routes: lib/mobile/screens/** and lib/mobile/app/**.
- Handheld shared components and overlays: lib/mobile/widgets/**.
- Common routes and player entry points: lib/screens/common/**.
- Movie/series route and legacy compatibility entry points: lib/screens/movie/** and lib/screens/tv/**.
- Authentication/profile flows: lib/screens/user/**.
- TV shell, focus/navigation, screens and controls: lib/tv/app/**, lib/tv/navigation/**, lib/tv/focus/**, lib/tv/screens/**, lib/tv/widgets/** and lib/tv/player/**.
- Playback-specific presentation and support: lib/screens/common/player.dart, lib/screens/common/live_player.dart, lib/screens/common/player/**, player settings, source/provider/language pickers and offline-player routes.

The workstream executors must inspect the actual route graph and callers before deciding a legacy screen is unused. Do not silently omit a route because a newer screen appears to replace it.

## Screen/flow coverage checklist

### Handheld shell and discovery
- [ ] Brand/design tokens and shared presentation primitives.
- [ ] Five mobile root destinations and restoration: Home, New & Hot, Discover, Search, My 7xPlay.
- [ ] Home editorial composition, Continue Watching, content modules and ads.
- [ ] New & Hot releases/trending/ranked lists.
- [ ] Discover movie/series context, filters, active criteria and results.
- [ ] Search query/history/suggestions/results/filters and return-state restoration.
- [ ] Handheld Live TV channel/programme browsing.

### Content journey
- [ ] Movie and series title details, Play/Resume and all secondary actions.
- [ ] Collections, filtered grids, pagination and empty/retry states.
- [ ] Seasons, episodes, episode details and cast/crew.
- [ ] People, credits, galleries, trailers and image viewers.
- [ ] Legacy movie_detail/tv_detail/episode_detail/seasons_detail and cast/crew entry points audited for live usage and route continuity.

### Personal library
- [ ] My 7xPlay guest/signed-in state and personal content shortcuts.
- [ ] Downloads, download selection, offline metadata and offline player hand-off.
- [ ] My List/bookmarks and watch history/Continue Watching.
- [ ] Playlist list/detail/import/shared playlist/rename and share flows.
- [ ] Wellness/Viewing Insights and all loading/empty/error states.
- [ ] Local/offline content remains usable when network subsections fail.

### Account, support and product utilities
- [ ] Landing/guest access, sign-in/sign-up, forgot password, edit profile, email/password changes and delete account.
- [ ] Settings, language, theme, playback and preference controls.
- [ ] Sync, server status, update, About and deep-link/loading hand-off states.
- [ ] Plus, payment, wallet, redemption and entitlement surfaces.
- [ ] 7x AI and all loading/result/empty/error/retry states.
- [ ] All dialogs, sheets, menus, snackbars, forms and destructive confirmation states.

### Player experiences
- [ ] Movie/series player frame and transport controls.
- [ ] Unified audio selector across provider sources and available languages.
- [ ] Provider/source selection, manual source, subtitle selection/timing and player settings.
- [ ] Loading, buffering, recovery, failure, completion and next-episode states.
- [ ] Recommendations, feedback/reporting, preroll/ad and download-related overlays.
- [ ] Live TV player, programme/channel overlays and channel switching.
- [ ] Offline player presentation.
- [ ] TV player and remote-first player controls.
- [ ] Fullscreen/orientation/route hand-off and compact-player transitions wherever the current app supports them.

### Android TV
- [ ] TV shell/navigation, brand system and TV-specific page/widget primitives.
- [ ] Home, catalogue, search, Live TV browse and sport selection.
- [ ] TV details, collections, grids, poster walls and title logos.
- [ ] TV library, profile/auth, settings, Plus, Wellness and playlist flows.
- [ ] Redeem code, landing/auth, dialogs, keyboards, update gates and state panels.
- [ ] D-pad/remote navigation, focus restore, Back dispatch, overscan/safe areas and viewing-distance typography.
- [ ] TV player controls are completed by the player plan.

## Execution order and dependency gates

1. **Baseline and audits.** Run baseline focused tests, inspect the entire PR #24 diff and current route graph, triage CodeRabbit findings against the current head, and complete shared mobile/TV/player component maps.
2. **Core foundation.** Complete the design token/component audit and mobile shell foundation first. Do not let a shared token change break TV or player surfaces.
3. **Handheld experience.** Complete Core Browse, then Content Journey, Personal Library and Account/Support. These plans can be sequenced after the foundation and reviewed independently.
4. **Player presentation.** Work from the player-boundary audit. The player interface can be redesigned only after presentation/engine responsibilities and continuity assertions are explicit.
5. **Android TV.** Complete TV-specific design, shell, focus, browse, content, account and dialog tasks. The TV player surface is shared with the player workstream and must not be redesigned twice.
6. **Cross-app integration.** Run the full screen, theme, localization, accessibility, playback, focus, route, offline, ad and navigation matrix. Validate the app on handheld and TV before asking for final review.
7. **Review and integration.** Request CodeRabbit review of stable increments, address only verified findings, run verification again, and ask Rahul before changing PR #24 from draft, merging, publishing or triggering release APK workflows.

## Shared invariants

- Keep MobileTab IDs home, new, discover, search and mine; preserve tab restoration, deep links, home-widget routes, Back-to-Home and reselect behaviour.
- Preserve TV navigation, focus-node lifetimes, D-pad key mappings, remote-only usability, Back dispatch and focus restoration.
- Preserve current catalogue sources/ranking, MediaItem IDs, route names, page entry points, query/history persistence keys and API/backend contracts.
- Preserve authentication/session, guest access, profile mutations, billing/product IDs, payment hand-offs, Plus entitlements, wallet values, sync and server/update behaviour.
- Preserve offline downloads, storage paths, local file playback, bookmark and playlist persistence/share/import semantics.
- Preserve playback engine/BetterPlayer ownership, source URL/headers, provider ordering and aggregation, source fallback/recovery, unified cross-provider audio selector, subtitles/timing, watch history/resume, next episode, preroll/ad, feedback and analytics contracts.
- Keep ad placement IDs and required placements; they must not obscure Play/Resume, TV remote controls or the first useful content.
- Keep Dark, AMOLED, Light, custom/dynamic, seasonal and ambient modes where supported. Use AppPalette semantic roles rather than dark-only assumptions.
- Preserve English, Spanish, Arabic and Hindi. Any new visible copy must be in runtime JSON assets for all four locales.
- Preserve Arabic RTL, text scale 1.3 (and test enlarged scale where CodeRabbit findings demand it), reduced-motion and accessible semantic actions. Primary controls must meet the existing 48dp target requirement where applicable.
- Use existing Flutter 3.35.7 SDK pinned in .fvmrc; no framework/dependency migration is part of the redesign.
- No screen is accepted from code changes alone: every task has focused tests and recorded visual review for its platform.

## PR #24 baseline and audit status

As checked on 2026-11-20:
- PR #24 is open, not merged, and still a draft. It targets main from redesign/phase-2-catalog-experience.
- PR metadata reports 66 changed files, 4,978 additions and 1,047 deletions across the consolidated branch. The branch also contains the full-app design-spec and plan-document updates.
- The PR description reports workflow run 44516087368 passed selected groups covering provider aggregation/fallback, 7x AI, shared headers, brand/palette, Home/feed, catalogue/New & Hot/Discover/Search and collection/poster-grid tests. The APK job was skipped under the existing draft/PR policy. This is a historical selected-test report, not proof that the expanded full-app plan passes or that the current head has been fully verified.
- The diff includes brand/launcher/wordmark work, mobile shell and screens, a substantial title-details experiment, bookmarks/downloads/sync/wellness changes, player recovery/download metadata changes, Karamara-first provider ordering, translations and tests.
- Keep the useful PR #24 implementation. Audit it screen by screen, retaining, revising or reverting only with a reason. Do not rebuild the same work in parallel or treat palette/heading edits as completion.
- PR #24 changed both UI and playback/provider behaviour. The player plan must protect the existing recovery/provider work while separating player UI from playback-engine responsibilities.

## CodeRabbit review triage

The current PR discussion contains nine actionable findings and review comments around mobile rail height, semantic shortcut activation, title artwork contrast, overview expansion, wide-layout sharing, hero-card text overflow, custom-theme selected-label contrast, provider recovery freshness/stalled-track handling and missing runtime sync translations.

- [ ] Re-fetch each exact thread/current code location before changing anything.
- [ ] Record each finding as valid, already fixed, no longer applicable or intentionally rejected with technical rationale.
- [ ] Add/retain regression tests for every accepted finding.
- [ ] Request a new CodeRabbit review after the implementation increment, not while PR #24 is still accumulating unrelated documentation-only commits.

CodeRabbit feedback is evidence to investigate, not an instruction to blindly change code.

## Progress tracking and truthful status

Every screen/flow is tracked independently using these states:

1. **Not audited** — current route/callers, presentation and tests have not been inspected.
2. **Remaining** — audit is complete and the approved redesign work is still outstanding.
3. **In progress** — implementation is actively being changed.
4. **Implemented** — composition has changed, but behavioural tests/visual checks may remain.
5. **Tested** — focused regression tests and analysis pass for the touched scope.
6. **Visually verified** — rendered phone/tablet/TV review is recorded for the relevant theme, locale, layout and interaction mode.

Do not promote a screen to a later state without the corresponding evidence. PR branch presence alone means only that code exists on the branch; it does not mean merged, tested, or visually accepted. All new checkboxes start unchecked until verified.

## Common task protocol

- Read the approved design and the owning workstream plan before editing.
- Inspect current implementation, callers, route graph and tests before changing a screen.
- Add a focused failing test first, verify the failure, implement the smallest presentation change, then rerun tests.
- Preserve the global invariants above and owning workstream boundaries.
- Review any shared widget change against all mobile and TV callers.
- Format touched files, run focused tests, translation validation and Flutter analysis.
- Record visual screenshots and walkthrough results rather than relying on assumptions from source code.
- Review every stable increment with CodeRabbit and verify its comments against repository reality.
- Keep PR #24 draft until every workstream and the complete verification matrix pass.

## Final acceptance gate

- [ ] All six workstreams completed.
- [ ] Every screen/flow in the coverage checklist has a recorded state of at least Visually verified.
- [ ] Full relevant Flutter test suite passes; any baseline failure is documented and proven unrelated.
- [ ] Flutter analysis reports no new issues.
- [ ] English/Spanish/Arabic/Hindi translation catalog is valid, with no missing runtime strings.
- [ ] Phone portrait/landscape, tablet, Android TV remote/focus, themes, Arabic RTL, text scale and accessibility review evidence is recorded.
- [ ] Playback continuity, unified audio selector, provider discovery, subtitles, resume, offline playback and Live TV regression walkthrough passes.
- [ ] Offline library/downloads, auth/profile, account, billing, sync, ads and deep-link/navigation contracts pass.
- [ ] CodeRabbit findings are triaged and accepted fixes are verified.
- [ ] Rahul has reviewed the complete result and separately approved PR readiness/merge/release decisions.
