# 7xPlay Full-App Experience Redesign — Design

**Status:** Revised scope; awaiting product-owner approval  
**Date:** 2026-11-20  
**Repository:** `RahulExe69/7xPlay`  
**Target:** Entire Android application — phones, tablets, Android TV, and all player/shell surfaces

## Intent

Turn the entire 7xPlay Android app into a recognisable, premium streaming experience rather than a FlixQuest interface with a new colour palette. The redesign must change page composition, information hierarchy, content presentation, navigation, interaction patterns, player experiences, and platform-specific layouts across phones, tablets, and Android TV.

The five primary destinations and all existing capabilities remain. Each page should have its own layout suited to its job while sharing one coherent 7xPlay visual language. Consistency comes from design rules and reusable primitives—not from repeating the same header, card, pill, and grid on every screen.

The movie-details screenshots supplied by the product owner illustrate the problem to solve: changing only the background and button colour is not sufficient. A successful redesign should be recognisably different even when viewed in grayscale.

## Goals

1. Establish one maintainable, platform-aware 7xPlay design system using the existing Flutter foundations.
2. Give every destination on every Android form factor a distinct information architecture and visual composition.
3. Redesign secondary/supporting destinations and surfaces so they do not fall back to legacy styling.
4. Make the 7xPlay identity deliberate: dark, cinematic, artwork-led, spacious, and restrained.
5. Redesign both movie/series and Live TV player interfaces while preserving playback engines, provider/audio logic, stream behaviour, and playback capabilities.
6. Preserve current app capabilities, data contracts, navigation restoration, localization, accessibility, offline behaviours, ads, and playback.
7. Validate actual rendered screens across themes, phone/tablet/TV layouts, player states, and right-to-left layout—not just successful compilation.

## Non-goals

- Changing playback engines, BetterPlayer internals, stream resolution, provider aggregation, unified audio selection, subtitles, source fallback, download playback, or backend playback contracts.
- Changing API/backend contracts, catalogue ranking, account/authentication semantics, persistence schemas, analytics event identifiers, deep-link formats, or notification behaviour.
- Removing existing product features to make layouts simpler.
- Replacing Flutter, changing dependencies without a demonstrated need, or renaming internal legacy package identifiers as part of a visual project.

## Product-owner decisions

The product owner selected **Approach A: shared design system first**, with independently composed page layouts. This document treats the selection as authoritative.

The AI assistant's user-facing product name is **7x AI**. Preserve the existing internal `flix_ai_*` localization keys, `FlixAiScreen`/controller/repository symbols, and `/flix-ai` route identifier.

## Approaches considered

### A. Shared design system, distinct page compositions — selected

Evolve the current theme-derived palette, brand colours, spacing/type tokens, and shared mobile widgets. Define reusable primitives for artwork, navigation, actions, metadata, list rows, surfaces, empty/error/loading states, and responsive content frames. Each destination uses those primitives in a layout designed for its specific task.

**Trade-off:** Requires more up-front design and component decisions, but reduces inconsistency and avoids a collection of one-off styles.

### B. Independent screen redesigns

Redesign each page separately, allowing every page to invent its own controls and spacing.

**Trade-off:** Fast visual freedom initially, but creates duplicate components and causes drift between screens. Rejected because the app is large and must feel like one product.

## Visual direction

### Brand and surfaces

- The committed product artwork is the source of truth: `RahulExe69/7x/products/7xplay/assets/icon.png` and `wordmark.png`. The icon's visible identity is a near-black cinematic canvas with a gold/yellow-to-orange/red 7/play symbol and a hot-pink-to-violet X.
- Build the interface on near-black and purple-black surfaces. Use warm gold/orange for primary actions; use hot pink/violet as restrained secondary signature colours. Do not take the draft cyan/blue values in `brand/tokens/colors.json` as the 7xPlay palette.
- Use `icon.png` only for the Android launcher. Use `wordmark.png` for in-app branding; do not stretch the square launcher icon into a header logo.
- Preserve intentional distinctions between Dark, AMOLED, Light, custom/dynamic, seasonal, and ambient theme modes. Do not hard-code dark-only text or surfaces into general-purpose components.
- Use surface layers, restrained hairlines, spacing, and contrast to establish hierarchy. Do not wrap every content block in a rounded card.
- Avoid repeated glow effects, giant saturated panels, gradients used as decoration, and accent-colour lines added merely to make a page appear redesigned.

### Typography and information hierarchy

- Use the existing Figtree family and evolve `AppType` rather than adding a second type system.
- Titles, section headings, metadata, supporting copy, and actions must have clearly differentiated roles.
- Content density should match the task: discovery can be visually rich; settings and account controls should be efficient and easy to scan.
- Preserve text scaling and avoid truncating important actions or metadata.

### Artwork and content presentation

- Make posters, backdrops, title logos, episode stills, and people imagery do useful information work.
- Establish distinct treatments for hero features, portrait poster rails, landscape editorial cards, ranked lists, continue-watching progress, episode rows, and people/credit lists.
- Do not force all content into the same poster card or horizontal rail.
- Loading skeletons should reflect the shape and hierarchy of the final content. Empty and error states should be designed, not left as raw text.

### Interaction and motion

- Primary actions should be visually obvious; secondary actions should remain discoverable without competing with Play/Resume.
- Use predictable selected, pressed, disabled, loading, and error states.
- Motion should clarify transitions and preserve context. Respect reduced-motion settings and avoid expensive full-screen opacity animations during scrolling.
- Keep navigation and state-restoration behaviour stable unless a specific screen has a separately approved reason to change.

## App-wide scope

The redesign covers the entire Android application: handheld, tablet, TV, movie/series player, and Live TV player. No application destination is excluded. The following inventory is based on the current repository and must be verified against the current tree when the implementation plan is written.

### Primary destinations — phones and tablets

- **Home** — a distinctive editorial landing page with a deliberate featured title, clear Continue Watching access, varied content modules, curated rows, and useful shortcuts. Avoid a generic stack of identical rails.
- **New & Hot** — release and trend-first presentation: upcoming titles organised by release timing, currently popular content, and ranked lists where actual ranking data exists.
- **Discover** — exploratory browsing with movie/series context, genre and other filters, visible active criteria, and a clear route to results. Keep the power-user filters useful without making the entire page feel like a form.
- **Search** — a dedicated search experience with a prominent query field, recent searches, useful suggestions, mixed result types, clear empty/no-result states, and access to advanced filters.
- **My 7xPlay** — a personal library/account hub with profile state, Continue Watching, saved titles, playlists, downloads, and account/settings actions. It must remain useful offline.

### Content and catalogue destinations — all Android form factors

- Movie and series details.
- Collections and filtered catalogue result grids.
- Season browsing and episode details/listing.
- Cast, crew, and person details.
- Credits and artwork/trailer galleries.
- Playlist listing, playlist detail, playlist import, and shared playlist views.

### Library, account, and utility destinations — all Android form factors

- Downloads and offline content.
- My List/bookmarks and watch history/continue-watching surfaces.
- Settings, profile editing, sync, server status, update/about pages.
- 7xPlay Plus, payment, and wallet surfaces.
- 7x AI and other existing auxiliary product screens.
- Supporting bottom sheets, dialogs, menus, forms, toasts/snackbars, loading states, and error states reached from the above pages.

Each in-scope page must be reviewed and given a deliberate layout decision. A global palette or shared header change alone does not satisfy the requirement.

### Player experiences — movie/series and Live TV

- Redesign the complete player presentation: playback surface framing, controls, seek/progress UI, transport actions, settings and selection sheets, audio/subtitle/language selection, provider/source selection, episode navigation, recommendations, feedback, ads, loading/buffering/error/recovery states, and accessibility/focus behaviour.
- Redesign mini-player, expanded player, fullscreen, orientation changes, system bars, back navigation, picture-in-picture/foreground transitions where currently supported, and player-to-page gestures as a coherent experience.
- Redesign Live TV playback presentation and its channel/programme overlays, channel switching, schedule context, and player states.
- Preserve BetterPlayer and native playback engines, stream/provider resolution, provider aggregation and fallback, unified cross-provider audio selection, subtitle timing/selection, download playback, watch history/resume policy, ad contracts, analytics identifiers, and all existing playback callbacks. UI changes must consume existing interfaces; any necessary engine change requires a separate explicit decision.

### Android TV destinations and interaction

- Include every screen and flow under `lib/tv/**`, the TV navigation shell, TV landing/home/catalogue/detail/library/settings surfaces, TV-specific account and utility flows, TV dialogs/sheets, and TV player-control surfaces.
- Preserve TV-specific focus traversal, D-pad/remote semantics, focus restoration, overscan/safe areas, readable viewing-distance typography, remote/back behaviour, and existing TV navigation contracts.
- Use TV-specific composition and interaction patterns where a handheld component would be inappropriate; visual consistency does not mean forcing touch-first layouts onto TV.

## Navigation and responsive behaviour

- Preserve the current five destinations in `MobileTab`: Home, New & Hot, Discover, Search, and My 7xPlay. Do not apply the older four-tab proposal in `docs/mobile_redesign_guide.md`.
- Preserve destination IDs, tab restoration, lazy construction/keep-alive behaviour, back-to-Home behaviour, per-tab scroll retention, and reselect-to-top/reset semantics.
- Preserve the current tablet navigation-rail model. Refine its visual treatment only where needed to match the new design system.
- Preserve the Android TV navigation and focus model; redesign its appearance without replacing D-pad navigation with touch-first controls.
- Use the existing responsive breakpoints as a starting point. Re-evaluate phone portrait, phone landscape, tablet, and wide layouts page by page.
- Keep directional layout correct in Arabic. Prefer directional padding/alignment APIs for new layout code.

## Architecture and boundaries

### Existing foundations to evolve

- `lib/design/app_brand.dart` — approved 7xPlay brand colours.
- `lib/design/app_palette.dart` — theme-derived semantic colour roles.
- `lib/design/app_tokens.dart` — spacing, radii, breakpoints, and typography.
- `lib/mobile/widgets/page_kit.dart` — shared page/control primitives, to be evolved selectively.
- `lib/mobile/widgets/media_art.dart`, `media_rows.dart`, `hero_card.dart`, `poster_card.dart`, `episodes_section.dart`, and adjacent mobile widgets — current artwork and content building blocks.
- `lib/mobile/app/mobile_shell.dart`, `mobile_nav_bar.dart`, and `mobile_tabs.dart` — current mobile shell and five-tab navigation.
- `lib/tv/**` — current Android TV shells, screens, navigation, focus handling, and TV-specific presentation.
- `lib/screens/common/player.dart`, `lib/screens/common/live_player.dart`, and `lib/screens/common/player/**` — current movie/series and Live TV player UI and playback orchestration; separate presentation-only changes from engine behaviour.

These are foundations, not an instruction to reuse every existing component. Retire or replace a primitive when its current shape prevents the desired page design.

### Boundaries

- Keep catalogue, provider, playback, account, and persistence logic behind their current interfaces.
- Keep platform-specific presentation in the relevant `lib/mobile/**` and `lib/tv/**` areas. Shared code may change only after confirming the effect on every caller.
- Do not make a phone-only or TV-only visual decision in a shared theme default that unintentionally changes another platform.
- Keep player UI refactors separated from playback engine/provider/audio state logic; no engine changes are implied by a presentation task.
- Retain existing ad placement identifiers and required ad placements. They may move only to intentional, non-obstructive positions; do not remove placements.
- Do not rename localization keys or delete translations to simplify a redesign.

## Quality and acceptance criteria

The redesign is accepted only when all of the following hold:

1. Every in-scope screen has a materially reconsidered composition or hierarchy. No screen is marked redesigned solely because its colours, heading accent, or border changed.
2. The five primary destinations are visually distinct but recognisably part of the same 7xPlay product.
3. Shared components have documented responsibilities and do not force identical layouts onto unrelated pages.
4. Existing actions and content remain available, including playback entry points, downloads, bookmarks, playlists, sharing, trailers, filters, search, profile/account flows, sync, updates, Plus/payment/wallet, and auxiliary pages.
5. Existing navigation IDs, restoration, deep links, home-widget links, analytics identifiers, and back/reselect behaviour continue to work.
6. Dark, AMOLED, Light, custom/dynamic, seasonal, and ambient theme modes remain legible and intentional.
7. Arabic RTL, Spanish, and Hindi remain supported. New user-facing text is translated in `assets/translations/{en,es,ar,hi}.json`.
8. Text scale up to at least 1.3 does not clip primary actions or critical information. Tap targets for primary interactive controls are at least 48 logical pixels where applicable.
9. My 7xPlay and Downloads preserve offline-first behaviour; one failed remote section must not replace the whole page with an error.
10. Ads remain present according to their existing contracts and do not obstruct primary actions or the first useful content.
11. Android TV screens receive a complete visual redesign while TV navigation, D-pad focus, remote behaviour, and supported playback behaviour remain functional.
12. Movie/series and Live TV player interfaces are redesigned across supported states; playback engines, provider/audio selection, subtitles, recovery, resume, and download playback remain behaviourally unchanged.
13. Deep-link, home-widget, navigation-restoration, catalogue, search, playlist, download, player, TV focus/navigation, and platform-specific tests relevant to touched code pass.
14. Each implementation phase receives visual review on phones/tablets in Dark, AMOLED, and Light, plus an Arabic RTL pass; TV screenshots and remote/focus walkthroughs are required.
15. Touched files are formatted and Flutter analysis reports no new issues. Known pre-existing failures must be distinguished from regressions.

## Implementation sequencing proposal

The work is intentionally phased so each group can be reviewed as a coherent, runnable increment:

1. **Full-app inventory and design-system foundation:** audit every mobile, tablet, TV, and player screen; map shared components and platform-specific systems; establish semantic tokens/primitives and a visual review checklist.
2. **Handheld discovery and personal hub:** Home, New & Hot, Discover, Search, My 7xPlay, and their complete secondary flows.
3. **Content journey:** movie/series details, collections, seasons, episodes, people, credits, galleries, and all catalogue result destinations.
4. **Library, account, and utility surfaces:** downloads, bookmarks, playlists, profile/settings, sync, server/update/about, Plus/payment/wallet, 7x AI, and every auxiliary screen.
5. **Movie/series player experience:** redesign all player UI, sheets, overlays, mini-player/fullscreen transitions, and playback states while preserving the playback engine and behaviour.
6. **Live TV experience:** redesign Live TV browsing and player UI, channel/programme overlays, remote controls, and recovery states while preserving stream resolution and playback behaviour.
7. **Android TV experience:** redesign TV shell, destinations, catalogue/content pages, library/account/utility flows, dialogs, and player presentation with D-pad/focus-first interaction.
8. **System-wide refinement:** supporting sheets/dialogs/empty/loading/error states, responsive layouts, RTL, text scaling, accessibility, motion and performance.
9. **Verification and integration:** behaviour tests, theme/screenshot matrix, TV remote/focus walkthroughs, player regression checks, review of the complete PR, and only then merge/build decisions.

This sequencing is a proposal for the implementation plan; exact file-level tasks, interfaces, and test commands belong in the plan after this design is approved.

## Open design questions

No product decision is required to preserve the current five-tab navigation, dark-first 7xPlay identity, Android TV/player boundaries, or existing functionality. The remaining creative decisions are deliberately delegated to the implementation plan and visual review, within the constraints above.

## Current in-flight work

PR #24 contains an early mobile catalogue polish and a substantial title-details layout experiment. It is not accepted as proof that the full redesign is complete. The implementation plan must audit that diff, retain useful work, revise anything that conflicts with this design, and expand scope to the rest of the app. Keep PR #24 draft until relevant validation and visual review are complete.
