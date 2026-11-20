# 7xPlay Playback and Player Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Redesign every movie/series, Live TV, offline and Android TV player interface while preserving the existing playback engine, stream resolution, provider/audio behaviour and playback state contracts.

**Architecture:** Treat presentation and playback as separate layers. Recompose the existing player surfaces and selectors around the current controllers/services, with explicit UI tests for state, route and playback continuity. Keep engine, provider, stream, subtitle policy, resume, download and ad decisions unchanged unless a separately approved defect fix is necessary.

**Tech Stack:** Flutter 3.35.7, Dart, BetterPlayer Plus, Provider, existing playback/provider services, Flutter widget/unit tests.

**Spec:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Global Constraints
- Scope includes phones, tablets and Android TV player presentation.
- Preserve existing BetterPlayer/native playback controllers, stream URL/headers, provider discovery/ordering, source fallback and recovery contracts.
- Preserve one unified audio-language selector across all available providers; never split language selection into provider-specific menus.
- Keep the active stream playing while background provider discovery completes. Discovery must not cause a soft reset or unsolicited provider switch.
- Preserve source switching, current playback position, resume/history, next-episode, completion, offline file, subtitle, cast/remote, ad, analytics and feedback contracts.
- Keep movie/series and Live TV interaction appropriate to the platform. TV remains D-pad/focus-first; handheld remains touch/gesture-first.
- Do not change API/backend contracts, persisted keys, analytics IDs, provider IDs, deep-link formats, billing or download storage.
- Do not remove a current player capability or introduce an unsupported control such as an unimplemented PiP action.
- Preserve all supported themes and translations; new strings belong in en/es/ar/hi runtime JSON assets.
- Use .fvm/flutter_sdk/bin/dart format, .fvm/flutter_sdk/bin/flutter test, and .fvm/flutter_sdk/bin/flutter analyze.
- Keep PR #24 draft; do not merge or trigger a release APK workflow as part of this plan.

## Review Focus
1. Provider discovery finishes during playback: the active source and playback position remain stable while the unified language catalogue updates.
2. Same-language recovery: a native track already present on a stalled source must not be mistaken for a recovered stream; a source is ready only after actual playback progress.
3. Async source changes: late results from an old provider/episode cannot replace the currently selected source or controls.
4. Orientation, fullscreen and route hand-off: player state and controls remain coherent across supported transitions.
5. TV remote/focus, screen-reader semantics, missing artwork and long translated labels: every player action remains reachable and understandable.

---

## Task 1: Audit player architecture and freeze behaviour contracts

**Files**
- Review: lib/screens/common/player.dart, lib/screens/common/live_player.dart, lib/screens/common/player/player_watch_page.dart.
- Review: lib/screens/common/player/player_data_management.dart, player_background_save.dart, player_completion_detector.dart, player_next_episode_policy.dart.
- Review: lib/screens/common/player/player_sheet_ui.dart, player_feedback_ui.dart, player_episode_selection.dart, player_movie_recommendations.dart.
- Review: lib/screens/common/player/player_external_subtitles.dart, player_local_subtitles.dart, player_subtitle_timing_sheet.dart, tv_subtitle_timing_panel.dart, player_strings.dart.
- Review: lib/screens/common/player_settings.dart, provider_choose.dart, manual_source_picker.dart, sublanguage_choose.dart, offline_player_screen.dart.
- Review: lib/tv/player/tv_player_screen.dart, lib/screens/movie/movie_video_loader.dart, lib/screens/tv/tv_video_loader.dart.
- Test: test/player_background_save_test.dart, player_buffering_configuration_test.dart, player_completion_detector_test.dart, player_data_management_test.dart, player_feedback_ui_test.dart, player_menu_route_test.dart, player_next_episode_policy_test.dart, player_route_handoff_test.dart, player_sheet_ui_test.dart, player_subtitle_configuration_test.dart, player_subtitle_timing_sheet_test.dart.
- Test: test/unified_playback_language_service_test.dart, preferred_audio_language_policy_test.dart, provider_audio_language_cache_test.dart, provider_loader_test.dart, download_audio_selection_test.dart, live_playback_policy_test.dart, tv_subtitle_timing_panel_test.dart, plus relevant ad/feedback tests.

**Interfaces**
- Consumes current player entry points, controllers, provider/audio catalogues, subtitle policies, playback actions, and current platform route contracts.
- Produces a presentation/engine boundary map, state-transition inventory and a list of existing behaviours that must remain invariant.

- [ ] Inspect the complete PR #24 player/download/provider changes and record which changes concern UI, recovery, provider behaviour and download metadata. Do not discard or duplicate the consolidated recovery work.
- [ ] Verify each existing CodeRabbit playback comment against the current head: fresh language-source catalogue after provider refresh, stalled native-track recovery, and any related stale-snapshot/race issue. Record valid, fixed, or no-longer-applicable with evidence.
- [ ] Run the focused existing player/provider/audio/download tests before UI edits; record pre-existing failures without weakening assertions.
- [ ] Create docs/superpowers/audits/2026-11-20-player-boundaries.md documenting presentation-owned widgets versus playback-owned services and the no-soft-reset/unified-audio contracts.
- [ ] Identify which visible behaviours live in PlayerOne, PlayerWatchPage, sheet widgets and the TV player route. Do not move large player logic as a visual cleanup.
- [ ] Commit the audit and baseline test notes before the player UI changes.

**Task gate:** Player responsibilities and test baseline are documented; no provider, stream, resume or persisted-state contract is changed by the audit.

## Task 2: Redesign the movie/series player frame and primary controls

**Files**
- Modify presentation only: lib/screens/common/player.dart, lib/screens/common/player/player_watch_page.dart.
- Review/modify: lib/design/app_palette.dart, lib/design/app_tokens.dart only when shared roles are genuinely missing; use the approved AppBrand/AppPalette foundation.
- Create: test/player_presentation_test.dart.
- Run: test/player_route_handoff_test.dart, player_menu_route_test.dart, player_data_management_test.dart, player_buffering_configuration_test.dart.

**Interfaces**
- Consumes the current playback controller, media metadata, selected source, loading/buffering/error state, control callbacks and current orientation/route information.
- Produces a cinematic 7xPlay player presentation with the same control callbacks and source lifecycle.

- [ ] Add failing widget tests for initial loading, playing, paused, buffering, recoverable error, exhausted-source error and controls-visible/hidden states.
- [ ] Run the new tests and confirm they fail on the missing presentation behaviour rather than on mocked playback setup.
- [ ] Recompose the player canvas, title/context, transport controls, timeline/seek interaction, volume/brightness affordances where currently supported, playback speed/quality/action entry points, and control visibility.
- [ ] Keep all existing control callbacks and controller ownership; do not recreate or dispose the active BetterPlayer controller solely to change presentation.
- [ ] Add responsive tests for portrait phone, landscape phone, tablet and long-title/text-scale cases. Ensure controls do not obstruct captions, video or system navigation.
- [ ] Run the player presentation and route-handoff tests; format touched files.

**Task gate:** Every existing primary player action remains available and functional; UI changes do not restart playback or alter stream selection.

## Task 3: Redesign unified audio, provider, subtitle and settings surfaces

**Files**
- Modify presentation only: lib/screens/common/player/player_sheet_ui.dart, player_external_subtitles.dart, player_local_subtitles.dart, player_subtitle_timing_sheet.dart, tv_subtitle_timing_panel.dart, lib/screens/common/player_settings.dart, provider_choose.dart, manual_source_picker.dart, sublanguage_choose.dart.
- Create: test/player_selection_surfaces_test.dart.
- Run: test/unified_playback_language_service_test.dart, preferred_audio_language_policy_test.dart, provider_audio_language_cache_test.dart, provider_loader_test.dart, player_subtitle_configuration_test.dart, player_subtitle_timing_sheet_test.dart, tv_subtitle_timing_panel_test.dart.

**Interfaces**
- Consumes the existing unified language catalogue, selected source/provider, subtitle options/timing and current settings callbacks.
- Produces one coherent language selector plus distinct, readable provider/source, subtitle and settings surfaces without changing selection policy.

- [ ] Add tests proving all available provider audio languages appear in one selector, language labels are de-duplicated/normalised by current policy, and a late provider refresh updates choices without restarting the current stream.
- [ ] Add tests proving user-selected provider/language changes use the current callbacks and preserve playback position; loading an additional provider does not soft-reset the active player.
- [ ] Run existing audio/provider/subtitle tests and compare before changing presentation.
- [ ] Recompose the unified audio sheet, provider/source selection, subtitle selection/timing and player settings with clear current-selection, unavailable/loading/error and confirmation states.
- [ ] Preserve manual-source fallback, language preference policy, subtitle file handling, external subtitle timing, and TV-specific subtitle timing controls.
- [ ] Run new and existing selector tests; check RTL, long language labels, compact height, screen-reader semantics and 48dp touch targets.

**Task gate:** Exactly one unified audio-language selection experience remains; provider discovery and switching do not introduce unintended resets or change engine policy.

## Task 4: Redesign episode, recommendation, feedback, ad and download player states

**Files**
- Modify presentation only: lib/screens/common/player/player_episode_selection.dart, player_movie_recommendations.dart, player_feedback_ui.dart, stream_feedback_prompt.dart, player_preroll_ad.dart, lib/screens/common/offline_player_screen.dart.
- Test: test/player_feedback_ui_test.dart, player_next_episode_policy_test.dart, player_sheet_ui_test.dart, adsterra_playback_ads_test.dart, vast_preroll_test.dart, offline_download_test.dart; create test/player_auxiliary_surfaces_test.dart.

**Interfaces**
- Consumes current next-episode/resume policy, recommendations, stream feedback, ad service and local-download state.
- Produces redesigned auxiliary player surfaces with existing policy and callback semantics.

- [ ] Add tests for next-episode availability, dismissal, end-of-playback recommendations, feedback prompt states, ad gate states and offline-player error/empty/playing states.
- [ ] Run all listed existing policy/ad/download tests before editing.
- [ ] Redesign episode picker, next-episode affordance, recommendation shelf, stream feedback/report overlays and preroll/ad presentation without changing trigger timing, provider policy or analytics IDs.
- [ ] Redesign offline player chrome and empty/error state while preserving local path resolution, file availability, progress and resume metadata.
- [ ] Run owning tests and confirm screen-reader labels, compact landscape layout and remote focus where TV shares a surface.

**Task gate:** Auxiliary surfaces preserve existing timing, policy, reporting, ad and offline playback behaviour.

## Task 5: Redesign Live TV player and channel overlays

**Files**
- Modify presentation only: lib/screens/common/live_player.dart, Keep TV-specific presentation changes to lib/tv/player/tv_player_screen.dart in Task 6 so the file has one task owner.
- Review: lib/screens/common/live_tv_screen.dart, lib/tv/screens/tv_live_screen.dart for player hand-off only; browse-page composition belongs to the core-browse and Android-TV plans.
- Test: test/live_playback_policy_test.dart, daddylive_service_test.dart, live_stream_discovery_test.dart, tv_remote_navigation_test.dart; create test/live_player_presentation_test.dart.

**Interfaces**
- Consumes current channel identity, selected stream variant, schedule metadata, stream recovery state, remote/touch callbacks and current player controller.
- Produces redesigned Live TV playback UI and channel/programme overlays with unchanged stream and channel selection behaviour.

- [ ] Add tests for channel identity, available variants, channel switching, current/upcoming programme labels, loading, buffering, retry, failed stream and D-pad/pointer action handling.
- [ ] Run existing Live TV policy, discovery and Daddylive service tests.
- [ ] Redesign Live TV chrome, programme information, channel up/down/list, schedule context and recovery/feedback overlays.
- [ ] Preserve channel IDs, stream variants, headers, DRM/key handling, schedule time semantics, channel switch callbacks and current route behaviour.
- [ ] Verify that switching channels or variants changes only through the existing channel/source lifecycle; no unrelated state reset is introduced.
- [ ] Run focused tests and validate phone landscape, tablet and TV remote behaviour.

**Task gate:** Channel/stream behaviour and playback policy are unchanged; Live TV player states are reachable and visually coherent.

## Task 6: Integrate and redesign the Android TV player presentation

**Files**
- Modify presentation only: lib/tv/player/tv_player_screen.dart, lib/screens/common/player/tv_subtitle_timing_panel.dart.
- Review: lib/screens/common/player.dart TV-control branch and all callers of useTvControls.
- Test: test/tv_remote_navigation_test.dart, tv_subtitle_timing_panel_test.dart, tv_provider_order_dialog_test.dart, tv_update_test.dart; create test/tv_player_presentation_test.dart.

**Interfaces**
- Consumes the existing TV player route, D-pad/remote keymap, focus memory, player control callbacks and playback state.
- Produces a TV-first control layout with readable viewing-distance typography, predictable focus, discoverable controls and safe back behaviour.

- [ ] Add widget tests for focus entry/restore, directional movement across controls, play/pause, seek, subtitles, provider/audio selector entry, back and control timeout.
- [ ] Run current TV remote, subtitle timing and provider-order dialog tests.
- [ ] Recompose TV player overlays/menus for remote-first use; keep controls within overscan-safe bounds and avoid touch-only gestures as the sole action.
- [ ] Preserve existing key mappings, focus nodes/lifetimes and player route/engine ownership.
- [ ] Verify large-screen layout at TV aspect ratios and confirm all controls are reachable without focus traps.
- [ ] Run the full player + TV player focused regression set.

**Task gate:** TV player remains operable entirely by remote; focus and stream behaviour are preserved.

## Task 7: Full player regression and continuity matrix

**Files**
- Test: all player tests listed above plus test/unified_playback_compile_test.dart, test/playback_action_test.dart, test/playback_wake_lock_test.dart, test/player_route_handoff_test.dart, test/video_provider_order_test.dart.
- Review: any touched presentation files and docs/superpowers/audits/2026-11-20-player-boundaries.md.

- [ ] Run all player/provider/audio/subtitle/download/ad/Live TV/TV player focused tests together.
- [ ] Run Flutter analysis and translation-catalog validation; separate known baseline failures from regressions.
- [ ] Visually inspect Dark, AMOLED, Light and custom theme modes, Arabic RTL, long translated labels, reduced motion, text scale 1.3, phone portrait/landscape, tablet and Android TV.
- [ ] Walk through start, pause, seek, audio change, provider discovery, explicit provider switch, subtitle change, recovery, episode change, completion, download playback, route back/forward and Live TV channel switching.
- [ ] Verify the player remains continuous while background provider discovery finishes; record evidence for the unified audio selector and no-soft-reset acceptance criteria.
- [ ] Update the plan checkboxes and audit with the exact test commands/results; request CodeRabbit review only after the player workstream reaches a stable review point.

**Workstream completion gate**
- [ ] Player presentation is materially redesigned on handheld and TV.
- [ ] No unintended player soft resets, provider auto-switches or audio-selector duplication.
- [ ] Existing engine, subtitle, recovery, resume, ads, analytics, download and route contracts pass regression tests.
- [ ] Visual and remote/focus reviews are recorded across the stated matrix.
