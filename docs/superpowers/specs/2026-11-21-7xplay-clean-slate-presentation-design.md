# 7xPlay Clean-Slate Presentation Architecture — Design

**Status:** Approved to proceed under Rahul's standing delegation on 2026-11-21  
**Date:** 2026-11-21  
**Repository:** RahulExe69/7xPlay  
**Base:** main at f330df2cbf1bd9a299fbea2c1e54fa265640b6f9  
**Target:** Complete Android app presentation layer: handheld, tablet, Android TV, shared surfaces, and playback interfaces

## 1. Intent

Replace the remaining FlixQuest-derived presentation architecture with a genuinely new 7xPlay application experience. This is not another colour pass, widget reskin, or incremental facelift. The new app must have a distinct composition, navigation model, page hierarchy, and component language across every user-facing screen.

The reason for the reset is visible in the current code: main.dart and flixquest_main.dart still compose the app around the legacy root; UserState chooses between FlixQuestHomePage/MobileShell and the TV shell; and MobileShell still maps the five destinations to the existing Home, New & Hot, Discover, Search, and My FlixQuest screens. The previous work improved the styling and many individual surfaces, but did not remove this presentation foundation.

The replacement should feel like a product designed as 7xPlay from the start: cinematic, content-led, fast to navigate, and deliberately composed for each device. It must remain a working streaming app throughout the migration and preserve the behavior users already rely on.

## 2. Goals

1. Establish a new presentation architecture with a new application shell, navigation/routing boundary, shared UI foundation, and feature-owned screen composition.
2. Redesign every user-facing feature and state—not only the five primary tabs—including detail pages, account and settings flows, catalogue utilities, dialogs, sheets, downloads, live TV, and all player surfaces.
3. Give phone, tablet/foldable, and Android TV their own interaction and layout systems while sharing brand, typography, semantic tokens, content components, and behavior contracts.
4. Make each destination visually and structurally distinct according to its job. A Home discovery page, search, library, settings, and detail page must not look like the same template with different headings.
5. Preserve existing runtime functionality, data, APIs, services, playback behavior, providers, account/session behavior, localization, analytics, accessibility, and stored preferences.
6. Make the implementation maintainable: explicit UI boundaries, reusable primitives where they genuinely help, feature-level ownership, and tests around navigation and important states.
7. Validate rendered output on representative device classes and real interaction paths. A successful compile alone is not acceptance.

## 3. Non-goals and protected contracts

This is a presentation-layer reconstruction, not a backend or media-engine rewrite.

The following are protected unless a concrete incompatibility is discovered and Rahul is consulted:

- Playback engines and BetterPlayer integration, source resolution, provider aggregation/order, stream selection, unified audio selection, subtitles, fallback policy, watch progress, next episode, picture-in-picture, downloads and offline playback behavior.
- Existing API/backend contracts, network clients, repository behavior, catalogue/search semantics, account/authentication semantics, local persistence formats, bookmark/playlist/history data, synchronization, and guest behavior.
- Analytics event identifiers and stable destination IDs, deep-link formats and dispatch semantics, notification navigation, Android notification behavior, home-widget contracts, update gates, ads lifecycle, and remote/runtime configuration behavior.
- Existing localization content and supported locales. Presentation may improve the way translated content is laid out, but must not silently remove strings or supported languages.
- Flutter as the application platform. No framework migration and no dependency additions without a demonstrated need.
- Internal package identity and legacy identifiers. The pubspec package name and stable external/internal identifiers are not to be renamed merely to make the source tree look new.

The TV player and handheld player can receive entirely new control layouts and surrounding UI, but must continue to delegate media behavior to the existing playback implementation and its established contracts.

## 4. Anti-goals

The redesign fails even if it compiles when it:

- Reuses the old screen trees and mainly changes palette, spacing, corner radius, shadows, or iconography.
- Builds a new shell that still embeds the old pages as the permanent destination content.
- Applies one generic scaffold, hero, card grid, or bottom navigation to every page and form factor.
- Removes functionality, shortcuts, content states, settings, TV focus behavior, or edge-case flows to simplify the work.
- Hard-codes dark colours into components in a way that breaks Light, AMOLED, custom/dynamic, seasonal, or ambient themes.
- Introduces a new state-management or routing dependency without evidence that existing Flutter foundations cannot satisfy the need.
- Changes the playback engine or service/data contracts as collateral work.
- Declares completion from a green build without visual and behavior validation.

## 5. Approaches considered

### A. Clean-slate presentation architecture — selected

Create a new app presentation composition: new shell(s), navigation and route boundary, design primitives, feature layouts, and platform-specific UI. Treat legacy widgets and pages as temporary migration sources or compatibility adapters only; do not use them as the permanent base of the new screens. Connect the new UI to existing providers, repositories, services, controllers, and playback contracts through clear feature-facing adapters/view models.

Why selected: It directly addresses the repeated failure mode: the current UI still feels like FlixQuest because the old screen architecture remains underneath the new styling. This is the only approach that can reliably deliver a recognisably different product throughout the app.

Trade-off: Higher initial architecture and migration cost. The work must be sequenced carefully so behavior stays intact and the app remains buildable.

### B. Rewrite existing screens in place — rejected

Replace individual widget trees while retaining most existing shell, screen, and routing structure.

Trade-off: Smaller initial change and easier access to current screen logic, but the architecture and interaction constraints that caused the current result remain. It is too easy to produce another reskin.

### C. Hybrid new shell with long-lived legacy screens — rejected as the end state

Introduce a new shell and shared component system, then gradually migrate screen content while old screen architecture remains a regular part of the app.

Trade-off: Useful as a short-lived migration technique, but unacceptable as the final design. It risks leaving a visually mixed app and turning temporary compatibility into permanent architecture. Approach A may use temporary adapters during migration, but every shipped destination must eventually use the new presentation layer.

## 6. Product identity and visual language

The committed 7xPlay icon and wordmark are the source of truth. The app's recognizable identity is a near-black / purple-black cinematic canvas, warm gold-yellow through orange-red for the 7/play mark, and hot pink through violet for the X.

- Use near-black and purple-black surfaces as the brand's strongest visual home. Gold/orange should carry primary actions and key emphasis; pink/violet are secondary signature accents.
- Do not use cyan or teal as the product's primary accent.
- Use the proper wordmark for in-app brand placement and the square launcher icon only for launcher/adaptive-icon contexts.
- Keep gradients, glows, borders and rounded panels purposeful. Do not make every control neon or every content group a card.
- Build semantic tokens for page/surface/raised surface, text hierarchy, separators, focus/selection, positive/warning/error, scrims, spacing, radii, motion, and typography.
- Preserve all existing theme modes and selected user preferences. The visual language must adapt correctly in Dark, AMOLED, Light, custom/dynamic, seasonal and ambient modes; the brand's cinematic dark presentation must not make Light mode broken or unreadable.
- Continue using the existing Figtree font family unless testing identifies a concrete issue.
- Respect text scaling, contrast, reduced motion, screen-reader labels, localization expansion, RTL, system insets, and focus visibility.

## 7. New presentation architecture

The new presentation layer should have a clear boundary from the app runtime and feature behavior.

### 7.1 Application composition

Introduce a new 7xPlay app composition root that owns presentation setup and selects the correct top-level experience for handheld/tablet or Android TV. Keep startup initialization, dependency injection, providers, network setup, authentication/session restoration, ads, notifications, sync, update gates, home widgets and runtime configuration wired through their current services.

The bootstrap may be refactored only where needed to expose clean dependencies to the new app root. Do not duplicate initialization or create a second competing source of truth. The old FlixQuest / FlixQuestHomePage composition should cease to be the active product root once the migration reaches completion; it may remain temporarily as a migration bridge while screens move.

### 7.2 Feature and shared UI boundaries

Create a new, clearly named presentation area for:

- App composition, responsive platform selection, navigation, and route compatibility.
- Shared semantic design tokens and a small set of composable UI primitives.
- Feature-level presentation for discovery/home, new and trending, browse/discover, search, library, title details, people/credits, collections, playlists, downloads/offline, live TV, profile/account, settings, payments/Plus, wellness, 7x AI, and support/system flows.
- Playback presentation for movie/series, live, and offline player surfaces, with adapters to the existing playback engines and player controllers.
- TV-specific focus, remote-control, and large-screen layout behavior, without forcing TV widgets into phone layouts.

Keep data, domain, services, models, providers and persistence concerns in their current homes unless a small adapter is required. The implementation plan should map existing source files to their new presentation owners before moving or deleting code.

### 7.3 Components and composition rules

Build shared components around stable design and behavior contracts: artwork surfaces, hero/editorial feature layouts, poster and landscape media cards, ranked items, continue-watching progress, episode rows, people/credit items, metadata groups, primary/secondary actions, filter controls, forms, sheets/dialogs, focusable TV controls, and loading/empty/error states.

Components should provide semantic slots and state variants rather than dictate entire page composition. Screen layouts should combine them in distinct ways. Avoid a component library that is merely a renamed copy of the existing widget directory.

### 7.4 Navigation and compatibility

Create a new presentation-owned navigation boundary with explicit route definitions and typed feature destinations where practical. Preserve existing inbound deep-link paths, notification navigation, Android back behavior, restoration keys where needed, stable analytics destination IDs, tab/default-home preference semantics, and current screen handoffs.

Do not add a router dependency by default. First map the current Navigator usage and determine whether Flutter's existing Navigator APIs can support the new boundary. Compatibility routes/adapters may forward existing external route identifiers to the new destinations during migration.

Navigation must cover nested flows, details pushed above the active destination, modal sheets, player entry/exit, guest/auth transitions, TV back dispatch, and restoration after process recreation.

## 8. Experience scope

All user-visible surfaces are in scope. At minimum, the inventory and redesign must include:

### Handheld and tablet

- First-launch/landing, guest and authenticated entry, sign-in/sign-up/recovery, profile and account management.
- Five primary destinations: Home, New & Hot, Discover, Search, and Library (the existing stable destination IDs remain compatible even if the user-facing Library name and layout are redesigned).
- Movie/series title details, seasons, episodes, people/credits, collections, search results, filters, recommendations, and content-specific sheets.
- Watchlist/bookmarks, playlists, shared playlists/import, continue watching, recent activity, and library management.
- Downloads, download selection, offline content, offline player, storage-related states.
- Live TV browsing, channel/category discovery, channel playback, guide-like or schedule surfaces where current data supports them.
- Movie/series player, source/provider selection, manual source selection, provider status/order, subtitles/audio/settings sheets, next episode and completion states, player feedback and error/retry states.
- Profile, authentication, device/session limit, Plus/payments/wallet/redeem, wellness, 7x AI, support, About, update, language, theme, playback preferences, sync, and system settings.
- Image viewer, photo viewer, dialogs, bottom sheets, confirmation flows, prompts, ads-related visual surfaces, loading/empty/error/offline states.

### Android TV

- Landing/auth, TV home and top-level navigation, catalogue/discovery, search with remote-friendly keyboard, library, media details, collections, profiles, playlists, Plus, wellness, settings, and all dialogs/sheets.
- TV movie/series player, Live TV, and offline playback surfaces.
- Remote-first focus architecture, visible focus, predictable back handling, focus restoration, directional movement, and large readable layouts.

### Player presentation

Redesign the surrounding player experience and controls from the ground up: immersive playback canvas, clear title/context, discoverable transport controls, source/audio/subtitle entry points, episode progression, player settings, failure/retry states, and coherent minimized/fullscreen/landscape transitions. Preserve the existing playback controllers, engines, source selection and media behavior. The exact controls and states must be inventoried from the current player code before replacement.

## 9. Responsive and interaction requirements

- Phone: touch-first hierarchy, thumb-reachable primary actions, readable content rails/lists, safe-area-aware navigation, and deliberate portrait/landscape behavior.
- Tablet/foldable: use available width intelligently with content max-widths, adaptive navigation and multi-column compositions; do not just stretch phone layouts.
- Android TV: ten-foot layout, remote-first focus order and memory, no hover-only affordances, clear focus indication, and sensible back behavior.
- Handle narrow windows, split-screen/resizing, keyboard presence, RTL, long localized strings, large text scale, and reduced-motion settings.
- Loading skeletons must match each page's actual layout. Empty, error, offline, permission, and retry states are part of each feature's design—not generic afterthoughts.

## 10. Migration and safety strategy

Migrate by vertical feature slices over a stable new shell and component foundation. Each slice must include its screen layout, all important states, navigation wiring, behavior parity, and tests. Avoid a prolonged hybrid app where a new Home sits beside several unmodified legacy pages.

The implementation plan must:

1. Inventory current routes, widgets, controllers, providers, platform branches, playback entry points, global overlays, and feature dependencies.
2. Establish the new app composition and shared design foundations without changing service initialization behavior.
3. Add the new navigation boundary and compatibility mappings.
4. Migrate handheld/tablet destinations and all secondary/system/detail flows in coherent groups.
5. Rebuild TV-specific experiences and focus/navigation behavior.
6. Rebuild player presentation surfaces while retaining player engines and contracts.
7. Remove obsolete presentation-only widgets and old shell references only after every consumer is migrated and tests pass.
8. Keep each implementation slice buildable and reviewable; do not combine unrelated backend cleanup or dependency churn into the redesign.

Temporary adapters are allowed only when they are isolated, documented, and have a removal condition.

## 11. Validation and acceptance

The redesign is complete only when all of the following are demonstrated:

- Every screen and overlay in the agreed inventory uses the new presentation architecture; no legacy screen tree remains the permanent content implementation.
- The new Home, Discover, Search, Library, details, settings, player and TV screens are recognisably different from the current app in layout and information hierarchy—not merely in colour.
- All five destination IDs, default-home setting, restoration, tab reselection behavior, deep links, notifications, external intents, and TV back/focus behavior remain correct.
- Existing catalogue, provider, audio/subtitle, player, downloads, bookmarks, playlists, auth/guest, sync, billing, wellness, ads, update, and account functionality remains intact.
- Dark, AMOLED, Light, custom/dynamic, seasonal and ambient themes render with accessible contrast.
- Phone portrait/landscape, tablet/foldable, and Android TV layouts are visually inspected. RTL, text scaling, reduced motion, empty/loading/error/offline states are exercised.
- Automated tests cover shared components, navigation compatibility, important route flows, platform switching, and critical presentation states; existing tests remain green.
- Flutter analyze and relevant test suites pass. A release/debug APK build is executed in a real CI or Flutter environment and the resulting APK is installed and smoke-tested on Android hardware/emulator.
- No unapproved dependency, backend, persistence, package identity or playback-engine changes are introduced.

A progress report must distinguish code completed, tests actually run, builds actually produced, and device validation actually performed. Never label unexecuted checks as passed.

## 12. Builder decisions

The implementation owner may choose exact class names, file boundaries, widget APIs, layout values, route representation, and migration order where they preserve this design. The builder must document any necessary deviation and must not widen the task into runtime/backend/player-engine changes.

Because the project is large, work should be split into independently testable phases and reviewed as one coherent product. The intended end state is one new 7xPlay presentation architecture—not a permanent side-by-side stack of new and legacy screens.

## 13. Source references inspected

- lib/main.dart: bootstrap, global providers/services, and active import of the legacy app composition.
- lib/flixquest_main.dart: MaterialApp/theme/global wrappers and existing runtime lifecycle wiring.
- lib/screens/user/user_state.dart: presentation selection for handheld/TV and authenticated/landing state.
- lib/mobile/app/mobile_shell.dart, mobile_nav_bar.dart, mobile_tabs.dart: current handheld navigation, five legacy destinations, restoration and analytics IDs.
- lib/tv/app, lib/tv/screens, lib/tv/player: current TV experience and focus architecture to inventory and replace at the presentation layer.
- lib/screens/common/player.dart, live_player.dart, offline_player_screen.dart, and lib/screens/common/player/: current playback presentation and behavior boundaries.
- lib/design/app_palette.dart, app_tokens.dart, and docs/7xplay_visual_direction.md: current semantic palette, layout tokens and brand identity.
- docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md: previously approved full-app redesign scope and protected behavior contracts.
