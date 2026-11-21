# Android TV Component and Responsibility Map

**Checked:** 2026-11-20 against `redesign/phase-2-catalog-experience`  
**Scope:** Complete Android TV application under `lib/tv/**`  
**Design:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Architecture at a glance

TV has a dedicated shell and presentation system. It is not a mobile screen with a remote attached.

| Area | Current source | Responsibility | Redesign boundary |
|---|---|---|---|
| TV design metrics/palette | `lib/tv/app/tv_design.dart` | `TvShellMetrics`, TV surface/focus design roles and TV-specific responsive measurements | Recompose/retune TV visuals; shared app roles must remain compatible with phone/tablet. |
| TV root shell | `lib/tv/app/tv_home_shell.dart` | Destination ownership, TV route entry points, media/player hand-off, selected screen and shell-level state | Keep route IDs, destination actions, state restoration and content callbacks. |
| Shell layout/insets | `lib/tv/app/tv_shell_layout.dart` | Floating nav rail, selected destination layout, full-bleed layout, safe insets, D-pad movement between rail and screen | Redesign visual composition without breaking rail-to-screen focus transfer or overscan bounds. |
| Back dispatch | `lib/tv/navigation/tv_back_dispatcher.dart`, `tv_back_key_guard.dart` | Back stack/exit confirmation and duplicate key handling | Behaviour owner; visual dialog may change, dispatch order and Back semantics may not. |
| Focus memory | `lib/tv/focus/tv_focus_memory.dart` | Remembers focused item by scope | Preserve scope IDs and focus restoration. |
| Focus primitives | `lib/tv/focus/tv_focusable.dart` | Focus target, activation, selected/disabled/focused appearance, semantics and pointer parity | Redesign focus ring/scale/contrast but preserve activation and semantic contract. |
| Remote keymap | `lib/tv/focus/tv_keymap.dart` | Maps Select/Enter/Gamepad, Escape/Back, menu, play/pause, seek and other remote intents | Do not change key mappings as a visual change. |
| Screen focus bridge | `lib/tv/focus/tv_screen_focus_controller.dart` | Shell requests focus into mounted destinations; async screen attach/request/owner handling | Preserve synchronous focus result and pending request semantics. |
| Navigation rail | `lib/tv/widgets/tv_navigation_rail.dart` | Collapsed/expanded rail, destination focus nodes, selected item and right movement hand-off | Retain destination IDs, per-item focus nodes, selected state, D-pad semantics. |
| Browse composition | `lib/tv/widgets/tv_browse_view.dart` | Focusable rows, spotlight, poster/media row types, see-all actions and page content composition | Shared TV layout primitive; page-specific composition should be distinct, not all screens identical. |
| Dialogs | `lib/tv/widgets/tv_dialog.dart` | Focus scope, action nodes, autofocus, remote action traversal | Visual redesign may change; focus trap prevention, default focus, Back/confirm/cancel and return focus must remain. |
| State panels | `lib/tv/widgets/tv_state_panel.dart`, `tv_browse_skeleton.dart`, `tv_loading_skeletons.dart` | Loading/empty/error/retry UI | Redesign state hierarchy and skeleton geometry while retaining focusable retry and async state contracts. |
| TV media primitives | `tv_spotlight.dart`, `tv_content_row.dart`, `tv_content_grid.dart`, `tv_media_card.dart`, `tv_poster_wall.dart`, `tv_top_ten_rank.dart` | Poster/backdrop display, title identity, focus scaling and ranked/browse layouts | Evolve TV-specific artwork presentation, spacing and hierarchy; avoid mobile component reuse where inappropriate. |
| Form/search controls | `tv_form_keyboard.dart`, `tv_search_keyboard.dart`, `tv_pill_button.dart`, `tv_list_row.dart` | Remote-first text entry, selections, list actions | Keep D-pad-only reachability, keyboard focus order and validation. |
| Global prompts | `tv_telegram_channel_prompt.dart`, `tv_update_gate.dart`, `tv_update_widgets.dart`, `tv_provider_order_dialog.dart`, `tv_continue_watching_menu.dart` | Update/Telegram/provider order/continue-watching transient flows | Recompose all transient surfaces, preserving actions and focus return. |

## Screen inventory

The checked tree contains dedicated screens for:

- `tv_home_screen.dart`
- `tv_catalog_screen.dart`
- `tv_search_screen.dart`
- `tv_live_screen.dart`
- `tv_media_details_screen.dart`
- `tv_collection_screen.dart`
- `tv_library_screen.dart`
- `tv_profile_screen.dart`
- `tv_auth_screen.dart`
- `tv_landing_screen.dart`
- `tv_settings_screen.dart`
- `tv_plus_screen.dart`
- `tv_wellness_screen.dart`
- `tv_playlist_import_screen.dart`
- `tv_playlist_name_screen.dart`
- `tv_shared_playlist_screen.dart`
- `tv_redeem_code_screen.dart`

Controllers/models/services also exist under `lib/tv/controllers/**`, `models/**` and `platform/**`; they must be treated as behaviour-owned unless an explicit bug is separately authorised.

## Existing regression coverage discovered

- Shell and navigation: `tv_shell_layout_test.dart`, `tv_navigation_rail_test.dart`, `tv_remote_navigation_test.dart`, `tv_back_dispatcher_test.dart`, `tv_back_key_guard_test.dart`.
- Browse and screens: `tv_browse_view_test.dart`, `tv_search_screen_test.dart`, `tv_search_keyboard_test.dart`, `tv_search_history_controller_test.dart`, `tv_sport_picker_test.dart`, `tv_collection_screen_test.dart`, `tv_media_details_test.dart`, `tv_library_screen_test.dart`, `tv_profile_screen_test.dart`, `tv_settings_screen_test.dart`, `tv_wellness_screen_test.dart`.
- Shared components/transient states: `tv_palette_test.dart`, `tv_loading_skeletons_test.dart`, `tv_poster_wall_test.dart`, `tv_title_logos_test.dart`, `tv_form_keyboard_test.dart`, `tv_provider_order_dialog_test.dart`, `tv_telegram_channel_prompt_test.dart`, `tv_update_test.dart`, `tv_localization_test.dart`, `tv_continue_watching_removal_test.dart`.
- Player overlap: `tv_subtitle_timing_panel_test.dart`; full TV player UI is owned by the player workstream.

## Critical invariants

1. Remote-only operation: every primary action, dialog action, picker, keyboard action and exit route is reachable without touch/mouse.
2. Focus: opening a page, modal, keyboard, loading state or nested route must not lose focus or leave the user trapped. Returning restores to the invoking control or a valid fallback.
3. Focus identity: retain scope IDs, destination IDs, focus keys and keymap semantics while re-skinning.
4. Viewing distance: title hierarchy, action labels and focus rings need TV-scale contrast and typography, not mobile density.
5. Safe area/overscan: keep rail and controls inside supported safe bounds across 16:9 TV windows and compact emulator sizes.
6. Async: optional rows and slow screens must retain already loaded content; loading/error transitions must not invalidate the currently useful focus target.
7. Data: preserve TV catalogue/search filters, history keys, sports selection, channel IDs, playlist/account/billing and route data contracts.
8. Player: `lib/tv/player/tv_player_screen.dart` currently wraps child content with immersive system UI/orientation management and a repaint boundary. The actual TV playback controls are also routed through the common player with its TV-control branch; redesign these once in the dedicated player plan, not as a duplicate TV-screen task.

## Open verification gaps

- Existing tests cover route/focus behaviour, but do not prove that every TV destination has a complete new visual composition.
- Add composition/accessibility tests for Home, catalogue, Live TV, account/playlist/Plus and dialogs as each screen is redesigned.
- Record screenshots and remote walkthroughs for TV aspect ratio, focus entry/restore, Back/cancel, keyboard/form entry and overscan.
- Do not mark any TV screen visually verified from source inspection or CI alone.
