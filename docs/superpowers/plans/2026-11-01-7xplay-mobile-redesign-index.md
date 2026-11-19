# 7xPlay Mobile Redesign — Implementation Plan Index

**Status:** In progress — approved by Rahul on 2026-11-19  
**Design:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md  
**Repository branch:** redesign/phase-2-catalog-experience

The approved design covers multiple independently testable subsystems. Execution is therefore split into four workstreams so every increment remains reviewable and runnable.

| Order | Workstream | Plan | Primary deliverable |
|---|---|---|---|
| 1 | Core browse | 2026-11-01-7xplay-core-browse.md | Shared mobile foundation, five-tab shell, Home, New & Hot, Discover, Search, Live TV browsing |
| 2 | Content journey | 2026-11-01-7xplay-content-journey.md | Title details, collections, seasons, episodes, people, credits and artwork galleries |
| 3 | Personal library | 2026-11-01-7xplay-personal-library.md | My 7xPlay, Downloads, My List, playlists, Wellness/Viewing Insights and offline-first presentation |
| 4 | Account/support | 2026-11-01-7xplay-account-support.md | Settings, profile/auth, sync/status/update/about, Plus, wallet, 7x AI and sheets |

## Execution order and gates
1. Execute and review Core browse first because its theme and mobile primitives are consumed by the other workstreams.
2. Execute Content journey and Personal library next. They consume the core design foundation but remain separate review units.
3. Execute Account/support after the shared primitives stabilise.
4. Complete a cross-workstream visual/accessibility pass and regression suite before considering the PR ready.
5. Keep the consolidated PR #24 in draft until the full mobile scope and validation matrix are complete. Merging to main, publishing releases, and triggering release APK workflows are separate decisions and are not authorised by this plan.

## Common task protocol
- Read the design spec and workstream plan before editing.
- Inspect current implementation and tests before changing files; the plan does not authorise blind replacement.
- Add a focused failing test, run it, implement the smallest presentation change, then rerun the test.
- Preserve data, persistence, analytics, navigation, ad and playback contracts.
- Format touched files and run task-level Flutter analysis.
- Visually review Dark, AMOLED and Light, plus Arabic RTL, on phones and tablets where applicable.
- Record known pre-existing failures separately rather than masking them.

**Pinned Flutter SDK:** 3.35.7 from .fvmrc.

## Repository baseline and PR #24 audit
PR #24 is the single consolidated draft for the redesign, playback recovery/download fixes, and Karamara-first provider ordering. Its diff contains:
- lib/mobile/screens/title_details_screen.dart: major details-page composition change;
- lib/mobile/widgets/page_kit.dart: BrandAccentRule and shared page component edits;
- lib/mobile/screens/discover_screen.dart, my_flixquest_screen.dart, new_and_hot_screen.dart and search_screen.dart: page-heading/header decoration changes;
- the approved design spec and this plan package.

The content-journey executor must audit the existing title-details work and retain/revise each meaningful change rather than discard or duplicate it. The core-browse executor must review the repeated heading accent rule and use it only where it serves hierarchy or identity.

## Coverage checklist
- [ ] Five root tabs retained with existing IDs.
- [ ] Home, New & Hot, Discover and Search have distinct compositions.
- [ ] My 7xPlay, Downloads, My List, watch-history entry points, playlists and Wellness/Viewing Insights covered.
- [ ] Title details, collections, seasons, episodes, people, credits, artwork galleries and Live TV browsing covered.
- [ ] Settings, profile/auth, sync, server status, update/about, Plus/payment/wallet and 7x AI covered.
- [ ] Supporting sheets/dialogs and their callbacks covered.
- [ ] Dark, AMOLED, Light, custom/dynamic, seasonal and ambient themes checked.
- [ ] Arabic RTL, Spanish and Hindi retained/updated.
- [ ] Offline, navigation restoration, deep links, home-widget and ads contracts preserved.
- [ ] Android TV and playback/provider/audio selection unchanged.

## Approval status

Rahul approved implementation of this redesign on 2026-11-19. Continue in reviewable commits on `redesign/phase-2-catalog-experience` and keep `redesign/7xplay-native-experience` in sync. Preserve the five tab IDs, feature contracts, playback/provider boundaries, and the Android TV implementation. PR #24 remains draft until the full mobile scope and validation matrix are complete.


## Current implementation status — 2026-11-19

### Delivered in the consolidated PR
- Core mobile browse pass: distinct Home, New & Hot, Discover, Search, My 7xPlay, and five-destination navigation work is present on the PR branch.
- Brand-hub integration: the actual 7xPlay product launcher PNG and wordmark PNG are copied from `RahulExe69/7x`; launcher artwork is launcher-only, and the in-app header/rail use the wordmark directly. The draft blue-green token direction and mismatched adaptive layers are not treated as the product palette.
- Playback/provider consolidation: the work formerly in PRs #25 and #26 is included in this PR, including automatic recovery readiness, download recovery metadata, Karamara-first provider ordering, and no auto-switch just because background discovery finishes.
- Content journey: title-details work is present; collection pages now have a larger brand-led header and deliberate initial empty/error/retry states. Collection paging/tab state and retry/empty behaviour are covered by focused tests.

### Still in progress
- Complete the remaining collection, season/episode, person, credits, gallery and detail support journeys with page-specific compositions and responsive/RTL checks.
- Extend the personal library beyond the My 7xPlay hub: Downloads, My List/bookmarks, playlists, and Wellness.
- Complete settings/profile/auth/support/Plus/wallet/7x AI and supporting-sheet visual audits.
- Finish cross-theme, RTL, text-scale, compact-phone and tablet visual review, then run the broader regression suite and final analyzer pass.

The latest collection page tests are now explicitly included in the PR workflow so the new empty/retry coverage runs on subsequent commits. Do not mark the redesign complete while any remaining workstream or validation gate above is open.

