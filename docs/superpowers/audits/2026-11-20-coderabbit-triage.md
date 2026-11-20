# CodeRabbit Review Triage — PR #24

**Checked:** 2026-11-20 against `redesign/phase-2-catalog-experience`  
**PR:** https://github.com/RahulExe69/7xPlay/pull/24  
**Purpose:** Verify each finding against the current code before touching it. A stale review comment is not a reason to re-apply a fix.

## Findings

| Finding | Current source evidence | Triage | Follow-up |
|---|---|---|---|
| Tablet rail loses destinations at 800×360 | `lib/mobile/app/mobile_nav_bar.dart` now puts the destination Column in an Expanded, bounded `SingleChildScrollView` with a minimum viewport height. | Fix already present in current branch. | Add/retain a compact landscape regression test proving the last destination can be reached at 800×360. |
| My 7xPlay shortcut loses semantic tap action | `_LibraryShortcut` in `lib/mobile/screens/my_flixquest_screen.dart` now has `Semantics(onTap: onTap)` in addition to `InkWell(onTap: onTap)`. | Fix already present in current branch. | Existing test checks labels and target size; consider a SemanticsAction.tap activation test. |
| Artwork title/facts/genres contrast in Light theme | `_heroIdentity` now uses explicit white artwork foreground, and `_facts` / `_genrePills` use translucent white when `onArtwork` is true. However, the flexible-space gradient still ends with `palette.page`, which is light in Light mode. | Still needs a focused correction/verification: white artwork text can reach a light final gradient stop. | Add a Light-theme regression test for the actual scrim/identity contrast, then keep the artwork identity over a sufficiently dark scrim independent of `palette.dark`. |
| Short overview truncated without Read more | `_synopsis` sets `maxLines` and ellipsis only when the text is expandable and closed. | Fix already present in current branch. | No code change needed unless a regression test exposes a mismatch. |
| Share action missing in wide title details | The wide `_twoColumns` layout includes `_summary`; `_summary` includes `_actions`; `_actions` includes the Share action tile. | Fix already present in current branch. | Add a wide-layout action assertion only if current widget test coverage does not already prove it. |
| Hero details overflow at 2× text scale | `HeroCard.heightFor` increases height with text scale (up to 408px), but the title still sits in a fixed 58px slot. `test/hero_card_layout_test.dart` currently tests the height helper and backdrop choice, not rendered controls at 2×. | Not yet proven fixed. | Add a rendered HeroCard test at compact phone width and 2× text scale with Play and My List both visible and no layout exception; change the component only if the test reproduces overflow. |
| Selected labels fail contrast in custom theme | `SegmentSwitch` and `TogglePill` now choose foreground based on primary luminance. The reviewed pale-pink primary `#E9B7D0` with current `#171017` foreground measures 10.82:1. | The specific reviewed palette case is fixed. | Retain contrast tests for both selected controls; consider a boundary-value palette test around the luminance threshold. |
| Playback recovery uses a stale same-language source snapshot | `player.dart` re-reads `_audioSourceKeysByLanguage[selectedLanguage]` after same-provider refresh and uses `refreshedLanguageSourceKeys` for penalties/failover. | Fix already present in current branch. | Keep regression coverage for a provider discovered during the refresh await. |
| Recovery reports success for a stalled native audio track | `_switchToAudioLanguage` accepts `requirePlaybackAdvance`; recovery calls it with `requirePlaybackAdvance: true`, and the native-track branch waits for `_waitForSourceReady(expectPlaying: true)`. | Fix already present in current branch. | Keep a regression test asserting an unchanged native track cannot satisfy recovery without playback advancement. |
| Sync screen labels missing from runtime locale JSON | All 11 sync keys used by the screen are present in each of `en.json`, `es.json`, `ar.json`, and `hi.json`. | Fix already present in current branch. | No code change needed; keep the four-locale runtime-asset validation. |

## Verification boundary

- These are source-level triage results, not a substitute for widget tests or rendered visual review.
- The current pull-request CI workflow does not yet run the full TV/player test inventory in the full-app roadmap.
- The current PR workflow installs Flutter 3.41.5 while `.fvmrc` pins 3.35.7. This drift is recorded for a deliberate toolchain decision; it must not be silently changed as part of a visual fix.
- The latest CI run before the landing-test correction failed to compile `test/landing_screen_brand_test.dart` because `TextDirection.rtl` resolved to the wrong imported symbol. The test import has since been changed to hide the conflicting Easy Localization symbol; the follow-up CI result is pending at the time of this audit.

## Next verified actions

1. Prove the Light-theme artwork/scrim contrast failure with a widget regression test, then correct only the artwork presentation.
2. Add rendered 2× HeroCard coverage before changing its fixed title slot.
3. Extend CI coverage for Android TV and player tests after their owning test tasks exist.
