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


## Build-speed optimisation addendum — 2026-11-21

### Changes now implemented in `.github/workflows/build-android.yml`

- Enabled Flutter SDK caching in the regression and release jobs; retained the existing lockfile-keyed Pub cache without double-caching Pub packages through the Flutter action.
- Enabled Gradle cache writes for trusted same-repository PR runs and manual branch runs. Fork-originated PRs remain read-only.
- Added an independent PR-only `build-debug-apk` job. It targets `android-arm64` only, builds the `prod` debug variant, skips a duplicate Pub resolution with `--no-pub`, checks that the APK exists and has package ID `com.sevenx.play`, then uploads one artifact with compression disabled.
- The full optimised multi-ABI release build remains separate and keeps minification, resource shrinking, obfuscation, icon tree shaking and split-debug symbols.
- Gradle parallel execution and build cache were already enabled in `android/gradle.properties`; no unverified compiler or configuration-cache flags were added.

### Measured comparison

- Previous full split-release job, run [44735255828](https://github.com/RahulExe69/7xPlay/actions/runs/44735255828): 7m43s end-to-end; its APK build step took 5m41s for three ABIs.
- New PR debug job, run [44916095271](https://github.com/RahulExe69/7xPlay/actions/runs/44916095271), source SHA `ccd8e6e7c65adb44fca8498e8a3d59ce905a655c`: ARM64 debug build step took 3m20s; artifact upload took 3s. The artifact became available about 5m27s after the job started; full job cleanup completed at about 6m22s.
- The first run paid cold setup/cache costs: Flutter setup 53s and Gradle cache setup 52s. It restored existing Gradle caches and wrote new PR-branch build/dependency/transform cache entries during job cleanup. The next run is required to measure warm-cache performance.
- This is not an apples-to-apples benchmark: the new job is a single-ABI debug APK; the old job produced three minified/obfuscated release APKs.

### Current debug artifact

- Workflow run: [44916095271](https://github.com/RahulExe69/7xPlay/actions/runs/44916095271)
- Artifact name: `7xPlay-debug-arm64-ccd8e6e7c65adb44fca8498e8a3d59ce905a655c`
- Package ID verified by `aapt`: `com.sevenx.play`; version `4.3.0+10`.
- Artifact expiry: 2026-12-05.
- APK build and upload jobs succeeded independently of the regression job.

### Regression follow-up

The regression job in run `44916095271` failed because the language service fixture used a plain `Set<String>` where the implementation requires `LinkedHashSet<String>`. That was corrected, then a lint finding was addressed with a targeted `// ignore: prefer_collection_literals` on `LinkedHashSet<String>.of([identity])`; the concrete ordered set is required by the service test contract. The final fix is in commit `6cf32e2710796e4fea302144334f415044715d36`, and run `44917663866` passed the provider tests, all configured regression groups and Flutter analysis.

### Further performance boundary

GitHub-hosted runners are ephemeral. Repository caching can preserve SDKs and Gradle dependencies/build-cache entries, but not a live Gradle daemon or a persistent workspace between jobs. Lower, repeatable build times beyond this require a persistent self-hosted or larger runner; that would need separately provisioned compute and cost approval. Do not enable Gradle configuration cache without verifying Flutter/AGP/plugin compatibility for the pinned toolchain.


### Warm-cache result — 2026-11-21

- Warm PR run: [44916704829](https://github.com/RahulExe69/7xPlay/actions/runs/44916704829), PR head `51054577d4f821ba0a81ec54c3b43adb4ddba423`.
- Flutter setup fell from 53s to 21s (32s saved).
- Gradle cache restore took 67s versus 52s on the first run; this stage is still a bottleneck and should not be described as improved.
- Pub restore plus dependency resolution was 7s versus 8s on the first run.
- ARM64 debug compile fell from 200s to 118s (82s / 41% faster).
- Artifact upload took 4s; the artifact was available 3m42s after job start, down from 5m27s (about 32% faster time-to-artifact).
- Regression coverage in the next run progressed through the provider tests and all other configured groups; Flutter analysis found one `prefer_collection_literals` info lint. An attempted `LinkedHashSet.fromIterable` constructor was invalid and was reverted. The final test fixture retains `LinkedHashSet<String>.of([identity])` with a targeted lint suppression because the concrete ordered set type is required. The corrected run [44917663866](https://github.com/RahulExe69/7xPlay/actions/runs/44917663866) passed all configured regression groups and `flutter analyze`.
- Current artifact `7xPlay-debug-arm64-51054577d4f821ba0a81ec54c3b43adb4ddba423` is successful and downloadable from run 44916704829. It is ARM64-only, app ID `com.sevenx.play`, version `4.3.0+10`, and about 114 MB (debug build).

### Further optimisation priorities

1. Keep the separate ARM64 debug preview job as the rapid PR feedback path; don't wait for the three-ABI release packaging job.
2. Measure further cache restore time, especially Gradle transforms and dependency archives, before excluding any cache categories.
3. Do not switch the build to Gradle configuration cache without verifying Flutter 3.41.5 and every applied plugin are compatible. Gradle warns that ignoring configuration-cache problems can cause incorrect task state; Android's official guide says to verify plugin compatibility first.
4. The repository is public and currently uses GitHub's standard `ubuntu-24.04` runner. GitHub documents 4 vCPU / 16 GB for that public-repo runner; simply changing to `ubuntu-latest` is not a larger compute tier. A persistent or larger runner may improve repeat builds further but requires infrastructure or an eligible paid runner entitlement; it has not been enabled.


### Latest validated PR head — 2026-11-21

- PR head: `6cf32e2710796e4fea302144334f415044715d36`.
- Workflow run: [44917663866](https://github.com/RahulExe69/7xPlay/actions/runs/44917663866).
- ARM64 debug job succeeded; regression job succeeded; the optimized multi-ABI release job was skipped as intended for a PR.
- ARM64 debug compile: 85s. Flutter SDK setup: 14s. Gradle cache setup: 48s. Pub cache plus dependency resolution: 4s. Artifact upload: 2s.
- The regression job passed all configured groups, including provider/audio, mobile screens, Android TV, ads policy, VAST/playback primitives, movie/series, Live TV and offline player behaviour; `flutter analyze` also passed.
- Latest artifact: `7xPlay-debug-arm64-6cf32e2710796e4fea302144334f415044715d36`, artifact ID `14712910120`, available through run 44917663866 and expiring 2026-12-05.
- This validates the CI speed path and configured regression set; it does **not** mark the full approved UI redesign complete. PR #24 remains draft and unmerged.
