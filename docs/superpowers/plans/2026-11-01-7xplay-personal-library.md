# 7xPlay Personal Library and Playlists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make My 7xPlay, Downloads, My List, watch-history entry points and playlists feel like a cohesive personal library while keeping saved and offline content reliable.

**Architecture:** Redesign the personal hub as a local-first aggregation of existing account, bookmark, download, watch-history and playlist providers. Each remote subsection fails independently; offline files and locally saved metadata remain usable. Keep all repository, sync and persistence contracts unchanged.

**Tech Stack:** Flutter 3.35.7, Dart, Provider, current local download/bookmark/playlist repositories, easy_localization, Flutter widget/unit tests.

**Spec:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Global Constraints
- Target handheld presentation only; do not change lib/tv/**.
- Preserve My 7xPlay's root tab ID mine and current tab restoration semantics.
- Keep download engine, local storage paths, bookmark repository, playlist repository, sync payloads and player local-file routes unchanged.
- Do not change authentication/session semantics or user-owned playlist data.
- Preserve offline-first behaviour: a network failure cannot make completed local downloads unavailable or blank the whole hub.
- Preserve current playlist IDs, share URI formats, import validation, permissions and sync behaviour.
- New user-facing strings must be translated in en, es, ar, hi. Keep existing translation keys and compatibility values where possible.
- Preserve theme modes, Arabic RTL, text scale 1.3, accessibility labels and existing ad contracts.
- Use .fvm/flutter_sdk/bin/flutter test, .fvm/flutter_sdk/bin/dart format, and .fvm/flutter_sdk/bin/flutter analyze.

## Review Focus
1. Offline/airplane mode: local completed downloads and saved metadata remain visible and actionable.
2. Guest mode: no account-only action should imply that a guest is signed in.
3. Sync failure: local playlists/bookmarks remain available and errors are scoped to sync.
4. Imported/shared playlists: permissions and URI handling remain correct.
5. Missing artwork/large names/Arabic labels: stable grid dimensions and usable actions.

---

### Task 1: Redesign My 7xPlay as an offline-capable personal hub

**Files**
- Modify: lib/mobile/screens/my_flixquest_screen.dart.
- Review/modify as needed: lib/mobile/widgets/settings_kit.dart, account_form.dart, media_rows.dart, poster_grid.dart.
- Update visible brand strings only where required: assets/translations/en.json, es.json, ar.json, hi.json. Retain legacy keys.
- Test: test/my_flixquest_screen_test.dart, test/translation_catalog_test.dart, test/offline_download_test.dart.

**Interfaces**
- Consumes current user/session state, bookmark, RecentProvider/watch-history, offline-download, playlist and sync providers plus existing settings/account routes.
- Produces a My 7xPlay hub showing guest/signed-in state and useful personal content without requiring network access.

- [ ] Extend my_flixquest_screen_test.dart: locally stored My List and Downloads remain visible offline; a remote subsection failure does not replace the page; guest and signed-in headers reflect current session state; entry actions open existing destinations.
- [ ] Run My 7xPlay, offline-download and translation tests.
- [ ] Recompose profile identity/status, Continue Watching, My List, Playlists, Downloads and account/settings actions by usefulness. Do not invent counts or show failed remote requests as successful loaded sections.
- [ ] Replace visible FlixQuest product copy with 7xPlay where it belongs, across all four locale files. Retain translation keys and internal class names; do not rename provider brands or user-owned titles.
- [ ] Run focused tests, format and analyze. Test offline, guest, signed-in, Arabic RTL and text scale 1.3; commit.

**Task gate:** My 7xPlay remains useful offline and for guests; library routes remain reachable; no account/provider persistence semantics changed.

### Task 2: Redesign Downloads and My List/bookmarks

**Files**
- Modify: lib/screens/common/downloads_screen.dart, bookmark_screen.dart.
- Review/modify: lib/mobile/my_list.dart, lib/mobile/widgets/poster_grid.dart, settings_kit.dart.
- Test: test/offline_download_test.dart; create test/downloads_screen_test.dart and test/bookmark_screen_test.dart if absent.

**Interfaces**
- Consumes existing offline-download and bookmark providers/repositories and local file metadata.
- Produces download and saved-title pages that call existing pause/resume/retry/delete and bookmark actions exactly as before.

- [ ] Add UI tests for completed/downloading/paused/failed states, progress, retry/pause/resume/delete callbacks, completed local files during network loss, and empty My List navigation.
- [ ] Run offline-download and the new download/bookmark screen tests; run bookmark repository tests if repository code is touched.
- [ ] Redesign Downloads around title/episode identity, state, size/progress when available, and the most relevant action. Keep quality management and destructive actions in existing sheets/confirmation flows.
- [ ] Redesign My List with the current responsive poster grid and bookmark actions. Empty state links to browsing; do not invent filters or sort modes.
- [ ] Run download/bookmark tests, format and analyze. Do not modify download engine, storage paths or local playback.

**Task gate:** Completed files remain playable offline; statuses/actions are correct; bookmark state and persistence are unchanged.

### Task 3: Redesign playlist listing, detail, import and share surfaces

**Files**
- Modify: lib/mobile/screens/playlists_screen.dart, playlist_screen.dart, playlist_import_screen.dart, shared_playlist_screen.dart.
- Review/modify: lib/mobile/playlists.dart, lib/mobile/widgets/title_sheet.dart.
- Data code is out of scope unless separately approved: lib/data/playlists/playlist.dart, playlist_store.dart, lib/data/repositories/playlist_repository.dart, lib/data/sync/playlist_sync_engine.dart.
- Test: create test/mobile_playlists_screens_test.dart; run test/data/playlist_sync_engine_test.dart.

**Interfaces**
- Consumes current Playlist model, PlaylistProvider, playlist store/repository, import/share URI handling and title action callbacks.
- Produces local, imported and shared playlist views while retaining share links, IDs, edit permissions, sync and import validation.

- [ ] Add screen tests for empty/populated list, create/rename/delete, add/remove title, reorder only if currently supported, import validation, shared read-only/editable permissions, and failed sync while local data remains visible.
- [ ] Run playlist screen and playlist-sync tests.
- [ ] Redesign playlist index and detail: collections should have useful cover/metadata and clear management actions; detail should prioritise the title list and existing play/open-details actions. Do not add unsupported collaboration/sorting controls.
- [ ] Redesign import/shared pages to clarify destination, validation result, ownership and permissions. Preserve exact URI formats, parsing and clipboard/share behaviour.
- [ ] Run screen/sync/translation tests, format and analyze. Check Arabic RTL and long playlist names; commit.

**Task gate:** Playlist IDs, URI formats, sync payloads, permissions and offline contents are unchanged; tests pass.

### Task 4: Verify personal hub and route continuity

**Files**
- Modify only as needed: lib/mobile/screens/my_flixquest_screen.dart, lib/mobile/app/mobile_shell.dart.
- Test: test/my_flixquest_screen_test.dart, test/mobile_shell_test.dart, test/home_widget_navigation_test.dart, test/app_session_state_store_test.dart.

**Interfaces**
- Consumes the outputs of Tasks 1–3 and the existing five-tab navigation contract.
- Produces verified entry paths from My 7xPlay and stable route/restore behaviour when leaving and returning.

- [ ] Add cross-screen navigation assertions for My List, Downloads, playlists, profile and settings actions.
- [ ] Run the personal hub, mobile shell, home-widget navigation and session-store tests.
- [ ] Fix only presentation/navigation integration defects. Do not change shell tab IDs or introduce nested navigation that breaks root deep links.
- [ ] Format changed Dart files, run focused tests and flutter analyze, then commit the integrated personal-library workstream.

**Task gate:** Tab state, deep links and route restoration pass alongside offline library tests.

## Workstream completion gate
- [ ] My 7xPlay, Downloads, My List and all playlist variants have deliberate page compositions.
- [ ] Offline, guest, sync-failure and shared-permission tests pass.
- [ ] No data repository, persistence key, share URI or playback path changed.
- [ ] Dark, AMOLED, Light, Arabic RTL and tablet reviews are recorded.
