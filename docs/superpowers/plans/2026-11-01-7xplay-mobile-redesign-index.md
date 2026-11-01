# 7xPlay Mobile Redesign — Implementation Plan Index

**Status:** Proposed; awaiting plan approval  
**Design:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md  
**Repository branch:** redesign/phase-2-catalog-experience

The approved design covers multiple independently testable subsystems. Execution is therefore split into four workstreams so every increment remains reviewable and runnable.

| Order | Workstream | Plan | Primary deliverable |
|---|---|---|---|
| 1 | Core browse | 2026-11-01-7xplay-core-browse.md | Shared mobile foundation, five-tab shell, Home, New & Hot, Discover, Search |
| 2 | Content journey | 2026-11-01-7xplay-content-journey.md | Title details, collections, seasons, episodes, people and credits |
| 3 | Personal library | 2026-11-01-7xplay-personal-library.md | My 7xPlay, Downloads, My List, playlists and offline-first presentation |
| 4 | Account/support | 2026-11-01-7xplay-account-support.md | Settings, profile/auth, sync/status/update/about, Plus, wallet, Flix AI and sheets |

## Execution order and gates
1. Execute and review Core browse first because its theme and mobile primitives are consumed by the other workstreams.
2. Execute Content journey and Personal library next. They consume the core design foundation but remain separate review units.
3. Execute Account/support after the shared primitives stabilise.
4. Complete a cross-workstream visual/accessibility pass and regression suite before considering the PR ready.
5. Keep PR #24 draft until review and validation are complete. Merging, publishing releases, and triggering APK workflows are separate decisions and are not authorised by this plan.

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
At plan creation PR #24 is open and draft. Its diff contains:
- lib/mobile/screens/title_details_screen.dart: major details-page composition change;
- lib/mobile/widgets/page_kit.dart: BrandAccentRule and shared page component edits;
- lib/mobile/screens/discover_screen.dart, my_flixquest_screen.dart, new_and_hot_screen.dart and search_screen.dart: page-heading/header decoration changes;
- the approved design spec and this plan package.

The content-journey executor must audit the existing title-details work and retain/revise each meaningful change rather than discard or duplicate it. The core-browse executor must review the repeated heading accent rule and use it only where it serves hierarchy or identity.

## Coverage checklist
- [ ] Five root tabs retained with existing IDs.
- [ ] Home, New & Hot, Discover and Search have distinct compositions.
- [ ] My 7xPlay, Downloads, My List, watch-history entry points and playlists covered.
- [ ] Title details, collections, seasons, episodes, people and credits covered.
- [ ] Settings, profile/auth, sync, server status, update/about, Plus/payment/wallet and Flix AI covered.
- [ ] Supporting sheets/dialogs and their callbacks covered.
- [ ] Dark, AMOLED, Light, custom/dynamic, seasonal and ambient themes checked.
- [ ] Arabic RTL, Spanish and Hindi retained/updated.
- [ ] Offline, navigation restoration, deep links, home-widget and ads contracts preserved.
- [ ] Android TV and playback/provider/audio selection unchanged.

## Approval boundary
This index and the linked plans describe intended implementation only. No product-code changes are authorised until Rahul approves the plan package and chooses an execution approach.
