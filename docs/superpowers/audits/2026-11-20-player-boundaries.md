# Player Presentation and Playback Ownership Audit

**Checked:** 2026-11-20 against `redesign/phase-2-catalog-experience`  
**Scope:** Movie/series streaming, Live TV, offline playback and TV player presentation  
**Design:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Architecture at a glance

The current streaming player is not a single cosmetic widget. `lib/screens/common/player.dart` is the large stateful composition root and contains BetterPlayer controller ownership, controls, provider/audio selection, recovery and many interactions. It imports smaller player UI modules and policy/data helpers. The safe redesign seam is presentation widgets/sheets and their layout. Do not rewrite the controller lifecycle as a visual cleanup.

| Area | Current source | Owns | Presentation-only boundary |
|---|---|---|---|
| Main movie/series player | `lib/screens/common/player.dart` (`PlayerOne`) | BetterPlayer controller, active data source, selected provider/language, track selection, stream setup/switch/recovery, controls and route state | Recompose widget trees/control panels without changing controller ownership, data-source lifecycle, async request guards or selection policies. |
| Handheld watch page | `lib/screens/common/player/player_watch_page.dart` | Portrait/non-fullscreen watch-page layout: video at top, now-playing artwork context, action chips and next content | Page layout, information hierarchy, action presentation and responsive spacing only; callbacks/route lifecycle remain stable. |
| Player-owned sheet theme/primitives | `lib/screens/common/player/player_sheet_ui.dart` | Theme for sheets/panels, shared panel and sheet presentation helpers | Retheme/recompose using semantic roles; do not change BetterPlayer configuration or source state. |
| Data/history persistence | `player_data_management.dart`, `player_background_save.dart` | Save recent movie/episode progress, persist completion/resume state, background save error reporting | Behaviour-owned. Keep persistence keys, timestamps/position rules and async save sequencing. |
| Completion/next episode policies | `player_completion_detector.dart`, `player_next_episode_policy.dart` | Completion detection and teaser/next-episode gating | Behaviour-owned; UI displays decisions and callbacks only. |
| Episode/recommendations/feedback/ad surfaces | `player_episode_selection.dart`, `player_movie_recommendations.dart`, `player_feedback_ui.dart`, `stream_feedback_prompt.dart`, `player_preroll_ad.dart` | Presentation plus interactions driven by existing policy/services | Redesign visible layout and states; preserve event IDs, trigger timing, feedback/ad decisions and callbacks. |
| Subtitle surfaces | `player_external_subtitles.dart`, `player_local_subtitles.dart`, `player_subtitle_timing_sheet.dart`, `tv_subtitle_timing_panel.dart` | File selection, external subtitle state, style/timing controls and TV timing panels | Redesign selection/settings UI but keep subtitle parsing, offsets, file handling, track config and timing policy intact. |
| Player settings | `lib/screens/common/player_settings.dart`, `sublanguage_choose.dart` | User playback preferences, DND status, subtitle language preferences | Presentation only; do not change preference values, storage keys or OS permission flow. |
| Provider and manual source menus | `provider_choose.dart`, `manual_source_picker.dart` | Provider discovery selection and a D-pad dialog for TV manual provider selection | Keep provider IDs/order, manual/auto policy, loading/error behaviour and remote focus; redesign platform-specific surface. |
| Unified audio/source catalog | `unified_playback_language_service.dart`, `provider_audio_language_cache.dart`, `preferred_audio_language_policy.dart`, source maps in `PlayerOne` | Audio languages across provider sources, preference/default selection, caching, selection/fallback and active stream | Preserve one single cross-provider language selector; all available provider languages feed it. UI does not split languages by provider. |
| Movie/series stream preparation | `lib/screens/movie/movie_video_loader.dart`, `lib/screens/tv/tv_video_loader.dart`, `video_providers/provider_loader.dart`, `scraper_api.dart` | Stream fetch, provider loading, metadata/headers and player hand-off | Behaviour-owned. Do not change endpoints, provider aggregation/order, source identity, stream URLs, headers or download playback contracts. |
| Live TV playback | `lib/screens/common/live_player.dart` | BetterPlayer controller, stream variants, channel changes, programme context, recovery, ads/feedback and remote/touch controls | Recompose overlay/control presentation only; keep channel IDs, stream variant, headers/key/DRM and channel/source lifecycle intact. |
| Offline playback | `lib/screens/common/offline_player_screen.dart` | Local-file BetterPlayer source, playback metadata, subtitles and feedback | Redesign controls/status/empty-error surfaces; preserve local path, file validity, download state and resume metadata. |
| TV player shell wrapper | `lib/tv/player/tv_player_screen.dart` | Immersive system UI, landscape orientation and repaint boundary around the TV player child | Keep orientation/system UI lifecycle intact. It is not the whole TV controls implementation. |

## Required invariants

1. The active video remains playing while background provider discovery resolves. Adding providers/audio metadata must not soft-reset, reinitialize or silently switch the current stream.
2. The player shows one unified language selector across all available providers. Do not make provider-specific audio selectors.
3. Source changes are explicit or policy-driven through existing callbacks. Preserve watch position and active-provider selection semantics.
4. Recovery success means playback is actually ready/advancing; a native track already listed on a stalled stream is not proof that the stream recovered.
5. During automatic recovery after an explicit language choice, re-read the same-language source catalogue after awaited refreshes so newly discovered candidate providers are not missed.
6. Preserve BetterPlayer controller ownership, stream URL/headers, source setup/fallback policy, provider order/IDs, video formats/size metadata and ad gates.
7. Preserve subtitle tracks/files/languages/timing; movie and series resume/watch-history, completion and next-episode policy.
8. Preserve downloads/local file playback and metadata, ad/preroll contracts, feedback/reporting callbacks, analytics events, DND permission flow and wake lock.
9. Phone/tablet controls remain touch/gesture usable. TV controls remain remote-first with focus entry/restore, Back and remote key mappings.
10. Never introduce an unsupported PiP/cast/action merely because the new design has room for it.

## PR #24 work to protect

The current branch includes recovery work in `player.dart` and supporting download metadata. Source inspection confirms:
- `_switchToAudioLanguage(... requirePlaybackAdvance: true)` makes a native track selection wait for source readiness during recovery.
- `_refreshCurrentProviderSource` first checks whether current playback is already advancing, avoiding a needless source replacement.
- Explicit-language automatic fallback waits briefly for language discovery, then re-reads `_audioSourceKeysByLanguage[selectedLanguage]` after same-provider refresh.
- Recovery failure handling penalizes only the provider that failed and attempts eligible same-language sources.
These are behaviour changes already present on the PR branch; the redesign must not remove or duplicate them. The dedicated regression tests listed in the player plan must remain active.

## Existing test coverage discovered

- Controller/data/route: `player_background_save_test.dart`, `player_buffering_configuration_test.dart`, `player_completion_detector_test.dart`, `player_data_management_test.dart`, `player_route_handoff_test.dart`, `playback_action_test.dart`, `playback_wake_lock_test.dart`.
- Player presentation/support: `player_feedback_ui_test.dart`, `player_menu_route_test.dart`, `player_next_episode_policy_test.dart`, `player_sheet_ui_test.dart`, `player_subtitle_configuration_test.dart`, `player_subtitle_timing_sheet_test.dart`.
- Provider/audio: `provider_loader_test.dart`, `provider_audio_language_cache_test.dart`, `preferred_audio_language_policy_test.dart`, `unified_playback_language_service_test.dart`, `video_provider_order_test.dart`, `provider_order_test.dart`, `download_audio_selection_test.dart`.
- Live/offline/ads: `live_playback_policy_test.dart`, `offline_download_test.dart`, `adsterra_playback_ads_test.dart`, `vast_preroll_test.dart`.
- TV overlap: `tv_subtitle_timing_panel_test.dart`, `tv_provider_order_dialog_test.dart`, `tv_remote_navigation_test.dart`.

## Open verification gaps

- Current CI now includes player/provider/subtitle/download/Live TV tests, but does not yet prove the new player widget composition because new presentation-specific tests are still to be written.
- Existing tests prove controller/policy helpers, not a rendered full-player visual redesign.
- Add state matrix tests for loading, buffering, playing, paused, recoverable/exhausted failure, selection sheets, next episode, offline playback and TV focus.
- Add test that background provider discovery updates the unified audio choices without a current stream reset or provider auto-switch.
- Add screenshots/walkthroughs for portrait phone, landscape phone, tablet and TV; Dark/AMOLED/Light; Arabic RTL; text scale 1.3; remote controls and focus restore.
- Do not mark player UI visually verified from helper tests or source inspection.
