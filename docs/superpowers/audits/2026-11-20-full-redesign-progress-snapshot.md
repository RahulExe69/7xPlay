# 7xPlay redesign progress snapshot

**Snapshot date:** 2026-11-20  
**Branch:** `redesign/phase-2-catalog-experience`  
**PR:** [#24](https://github.com/RahulExe69/7xPlay/pull/24)  
**Compared against:** `main` at `a6fdc9e82de123d00c601ab96395c699b8dfbd47`  
**Compared head:** `779843c44f6d4b09ad9b722b785d75a4d6e1b8c8`

This is a factual checkpoint, not a completion claim. The approved scope is a full redesign of all Android app surfaces (handheld, tablet and TV), including the complete movie/series, Live TV and offline player UI, while preserving playback/provider/data behaviour.

## Branch comparison

- PR #24 is open, draft and unmerged.
- The branch is 165 commits ahead and 0 behind `main`.
- 83 files changed: 5,719 additions and 1,268 deletions.
- The diff is a consolidated branch comparison; counts include implementation, tests, documentation and workflow changes, not only UI work.

## Implemented or materially updated in this diff

- 7xPlay brand assets and identity: app brand definitions, wordmark asset, launcher asset, warm gold/orange-red and pink/violet identity, near-black visual direction, translation strings and Android app label.
- Mobile navigation shell: redesigned bottom navigation while retaining the five root destinations and existing navigation model.
- Main mobile destinations: Home, Discover, Search, New & Hot and My 7xPlay have updates of varying depth.
- Browse/content surfaces: title details, collection, playlists, person/season surfaces and shared hero/page components have updates.
- Library/support surfaces: bookmark, downloads, landing and sync screens have material updates.
- Playback-related changes in this diff: `player.dart` changes and playback recovery/audio/download metadata logic updates. These are not proof that the full player UI has been redesigned.
- Provider ordering: Karamara prioritisation and provider tests.
- CI/tests: expanded Android regression workflow and focused tests for redesigned/updated surfaces, TV navigation/branding, ads policy, player behaviour and provider/audio logic.

## Explicitly not complete / still required

### Handheld and tablet
- Finish a route-by-route audit of every mobile screen and secondary destination, then redesign any surfaces still using inherited FlixQuest layouts.
- Verify all dialogs, sheets, selectors, loading/empty/error states, settings, account/payment/wallet, imports, shared playlists, deep-link, update, language, image-viewer and other support flows.
- Verify tablet responsive layouts and navigation rail behaviour.

### Player and Live TV
- Complete the movie/series player visual redesign: controls, mini-player, expanded/fullscreen states, overlays, sheets and settings.
- Complete the unified audio/provider/subtitle selection surfaces and related feedback/recommendation/episode/download/ad states.
- Redesign and verify Live TV player/channel overlays.
- Redesign and verify offline player presentation.
- Preserve existing BetterPlayer/native playback controllers, source resolution, headers, provider order/fallback, playback continuity, audio selection, subtitles, resume, downloads, ads and analytics. No visual work may silently change these contracts.

### Android TV
- Full redesign of TV home/catalogue/details/search/library/collection/live/settings/profile/auth/playlist/Plus/wellness and supporting screens.
- Verify remote focus, back/reselect behaviour, focus restoration, readable TV layouts and player controls. The current diff includes only a small direct TV screen implementation change plus tests/branding adjustments; the TV plan/audit documents are not implementation.

### Validation and release readiness
- Fix the current failing provider/audio regression test, rerun the complete regression suite and Flutter analysis.
- Verify actual screens on device/emulator at relevant sizes, text scaling, RTL and accessibility settings.
- Produce a debug APK from the exact final tested PR head and attach it as a CI artifact before asking Rahul to install it.
- Do not merge PR #24 or claim the full skeleton is complete until the above is implemented and verified.

## Latest build / APK status at this checkpoint

- Latest PR workflow run: [44714678338](https://github.com/RahulExe69/7xPlay/actions/runs/44714678338), head `779843c44f6d4b09ad9b722b785d75a4d6e1b8c8`.
- Regression job failed in `test/unified_playback_language_service_test.dart`: `Set<String>` was supplied where `LinkedHashSet<String>` is required (the earlier compile syntax issue was fixed, exposing this type mismatch).
- Remaining test groups were skipped after that failure.
- Optimized APK job was skipped by the pull-request workflow policy.
- No workflow artifacts were attached to this run. Recent relevant runs checked also had no APK artifacts. There are no GitHub releases currently published.
- Therefore there is no verified latest debug APK available for device testing at this checkpoint.

## Next execution order

1. Correct the Set/LinkedHashSet test fixture with the intended insertion-order semantics and rerun the failing test.
2. Rerun all regression groups and analysis; fix any newly exposed failures.
3. Continue implementation by workstream: handheld/tablet remaining surfaces, player/Live TV/offline, then Android TV.
4. Run the complete screen and interaction acceptance matrix.
5. Build and publish a debug APK artifact from the exact verified PR head; provide Rahul the artifact and test checklist.
6. Keep PR #24 draft/unmerged until the full approved scope is done and reviewed.
