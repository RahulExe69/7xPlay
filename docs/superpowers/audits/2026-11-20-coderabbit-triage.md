# CodeRabbit Review Triage — PR #24

**Checked:** 2026-11-20 against `redesign/phase-2-catalog-experience`  
**PR:** https://github.com/RahulExe69/7xPlay/pull/24  
**Purpose:** Verify each finding against the current code before touching it. A stale review comment is not a reason to re-apply a fix.

## Findings

| Finding | Current source evidence | Triage | Follow-up |
|---|---|---|---|
| Tablet rail loses destinations at 800×360 | `lib/mobile/app/mobile_nav_bar.dart` now puts the destination Column in an Expanded, bounded `SingleChildScrollView` with a minimum viewport height. | Fix already present in current branch. | Add/retain a compact landscape regression test proving the last destination can be reached at 800×360. |
| My 7xPlay shortcut loses semantic tap action | `_LibraryShortcut` in `lib/mobile/screens/my_flixquest_screen.dart` now has `Semantics(onTap: onTap)` in addition to `InkWell(onTap: onTap)`. | Fix already present in current branch. | Existing test checks labels and target size; consider a SemanticsAction.tap activation test. |
| Artwork title/facts/genres contrast in Light theme | `test/title_details_screen_test.dart` failed first with the old Light-theme gradient end luminance of `0.9740810301656981`. Commit `f797084` imports `AppBrand` and changes the final artwork gradient colour to `AppBrand.background`. The same test now passes in Actions run `44704315977`. | Fixed and regression-tested. | Keep the Light-theme luminance assertion and validate the rendered page in the visual review matrix. |
| Short overview truncated without Read more | `_synopsis` sets `maxLines` and ellipsis only when the text is expandable and closed. | Fix already present in current branch. | No code change needed unless a regression test exposes a mismatch. |
| Share action missing in wide title details | The wide `_twoColumns` layout includes `_summary`; `_summary` includes `_actions`; `_actions` includes the Share action tile. | Fix already present in current branch. | Add a wide-layout action assertion only if current widget test coverage does not already prove it. |
| Hero details overflow at 2× text scale | `HeroCard.heightFor` increases height with text scale (up to 408px), but the title still sits in a fixed 58px slot. `test/hero_card_layout_test.dart` currently tests the height helper and backdrop choice, not rendered controls at 2×. | Not yet proven fixed. | Add a rendered HeroCard test at compact phone width and 2× text scale with Play and My List both visible and no layout exception; change the component only if the test reproduces overflow. |
| Selected labels fail contrast in custom theme | `SegmentSwitch` and `TogglePill` now choose foreground based on primary luminance. The reviewed pale-pink primary `#E9B7D0` with current `#171017` foreground measures 10.82:1. | The specific reviewed palette case is fixed. | Retain contrast tests for both selected controls; consider a boundary-value palette test around the luminance threshold. |
| Playback recovery uses a stale same-language source snapshot | `player.dart` re-reads `_audioSourceKeysByLanguage[selectedLanguage]` after same-provider refresh and uses `refreshedLanguageSourceKeys` for penalties/failover. | Fix already present in current branch. | Keep regression coverage for a provider discovered during the refresh await. |
| Recovery reports success for a stalled native audio track | `_switchToAudioLanguage` accepts `requirePlaybackAdvance`; recovery calls it with `requirePlaybackAdvance: true`, and the native-track branch waits for `_waitForSourceReady(expectPlaying: true)`. | Fix already present in current branch. | Keep a regression test asserting an unchanged native track cannot satisfy recovery without playback advancement. |
| Sync screen labels missing from runtime locale JSON | All 11 sync keys used by the screen are present in each of `en.json`, `es.json`, `ar.json`, and `hi.json`. | Fix already present in current branch. | No code change needed; keep the four-locale runtime-asset validation. |

## Verification boundary

- These are code and test-level triage results, not a substitute for rendered visual review.
- The current pull-request CI workflow does not yet run the full TV/player test inventory in the full-app roadmap.
- The current PR workflow installs Flutter 3.41.5 while `.fvmrc` pins 3.35.7. This drift is recorded for a deliberate toolchain decision; it must not be silently changed as part of a visual fix.
- `test/landing_screen_brand_test.dart` originally failed to compile because the Easy Localization import shadowed Flutter's `TextDirection`; `hide TextDirection` was added to that import in commit `284a2a5`, and the landing-screen test passed in run `44704315977`.
- The Light-theme contrast test went red as intended in run `44703930399` (32 title tests passed, the new regression failed at luminance 0.974); the presentation fix in `f797084` made the same test group pass in run `44704315977`.
- Run `44704315977` completed successfully on `f797084e44d37739bbe367c228ea79e29b49b21f`. All existing mobile/provider/playlist/library groups in the workflow passed. The optimized APK job was intentionally skipped for pull requests.

## Next verified actions

1. Add rendered 2× HeroCard coverage before changing its fixed title slot.
2. Run the newly added Android TV and player regression batches plus `flutter analyze`; record any pre-existing failures separately from regressions.
3. Complete rendered phone/tablet/TV and player-state reviews; source and CI results alone do not prove visual acceptance.
