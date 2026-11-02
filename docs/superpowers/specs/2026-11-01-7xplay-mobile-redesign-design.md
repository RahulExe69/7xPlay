# 7xPlay Mobile Experience Redesign — Design

**Status:** Proposed; awaiting product-owner approval  
**Date:** 2026-11-01  
**Repository:** `RahulExe69/7xPlay`  
**Target:** Android handheld UI (phones and tablets)

## Intent

Turn the 7xPlay Android app into a recognisable, premium streaming experience rather than a FlixQuest interface with a new colour palette. The redesign must change page composition, information hierarchy, content presentation, navigation details where appropriate, and interaction patterns across the mobile app.

The five primary destinations and all existing capabilities remain. Each page should have its own layout suited to its job while sharing one coherent 7xPlay visual language. Consistency comes from design rules and reusable primitives—not from repeating the same header, card, pill, and grid on every screen.

The movie-details screenshots supplied by the product owner illustrate the problem to solve: changing only the background and button colour is not sufficient. A successful redesign should be recognisably different even when viewed in grayscale.

## Goals

1. Establish one maintainable mobile design system using the existing Flutter foundations.
2. Give every primary destination a distinct information architecture and visual composition.
3. Redesign secondary/supporting destinations and surfaces so they do not fall back to legacy styling.
4. Make the 7xPlay identity deliberate: dark, cinematic, artwork-led, spacious, and restrained.
5. Preserve current app capabilities, data contracts, navigation restoration, localization, accessibility, offline behaviours, ads, and playback.
6. Validate actual rendered screens across themes, phone/tablet sizes, and right-to-left layout—not just successful compilation.

## Non-goals

- Redesigning Android TV or changing files under `lib/tv/**`.
- Changing the player, BetterPlayer controls, playback resolution, provider aggregation, unified audio selection, subtitles, source fallback, or download playback.
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

- Dark-first identity based on the approved 7xPlay mark: near-black and deep wine are the primary canvases.
- Amber/cinema gold is the main action accent. Ember supports secondary emphasis. Magenta is a rare signature, not a repeated decoration.
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

The redesign covers the full mobile experience, not only the five root tabs. The following inventory is based on the current repository and should be verified again when the implementation plan is written.

### Primary destinations

- **Home** — a distinctive editorial landing page with a deliberate featured title, clear Continue Watching access, varied content modules, curated rows, and useful shortcuts. Avoid a generic stack of identical rails.
- **New & Hot** — release and trend-first presentation: upcoming titles organised by release timing, currently popular content, and ranked lists where actual ranking data exists.
- **Discover** — exploratory browsing with movie/series context, genre and other filters, visible active criteria, and a clear route to results. Keep the power-user filters useful without making the entire page feel like a form.
- **Search** — a dedicated search experience with a prominent query field, recent searches, useful suggestions, mixed result types, clear empty/no-result states, and access to advanced filters.
- **My 7xPlay** — a personal library/account hub with profile state, Continue Watching, saved titles, playlists, downloads, and account/settings actions. It must remain useful offline.

### Content and catalogue destinations

- Movie and series details.
- Collections and filtered catalogue result grids.
- Season browsing and episode details/listing.
- Cast, crew, and person details.
- Credits and artwork/trailer galleries.
- Playlist listing, playlist detail, playlist import, and shared playlist views.

### Library, account, and utility destinations

- Downloads and offline content.
- My List/bookmarks and watch history/continue-watching surfaces.
- Settings, profile editing, sync, server status, update/about pages.
- 7xPlay Plus, payment, and wallet surfaces.
- 7x AI and other existing auxiliary product screens.
- Supporting bottom sheets, dialogs, menus, forms, toasts/snackbars, loading states, and error states reached from the above pages.

Each in-scope page must be reviewed and given a deliberate layout decision. A global palette or shared header change alone does not satisfy the requirement.

## Navigation and responsive behaviour

- Preserve the current five destinations in `MobileTab`: Home, New & Hot, Discover, Search, and My 7xPlay. Do not apply the older four-tab proposal in `docs/mobile_redesign_guide.md`.
- Preserve destination IDs, tab restoration, lazy construction/keep-alive behaviour, back-to-Home behaviour, per-tab scroll retention, and reselect-to-top/reset semantics.
- Preserve the current tablet navigation-rail model. Refine its visual treatment only where needed to match the new design system.
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

These are foundations, not an instruction to reuse every existing component. Retire or replace a primitive when its current shape prevents the desired page design.

### Boundaries

- Keep catalogue, provider, playback, account, and persistence logic behind their current interfaces.
- Keep mobile presentation changes in `lib/mobile/**` where practical. Shared code may change only after confirming the effect on both handheld and TV callers.
- Do not make a mobile-only visual decision in a theme default that unintentionally changes Android TV.
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
11. Android TV behaviour is unchanged; existing TV tests pass.
12. Deep-link, home-widget, navigation-restoration, catalogue, search, playlist, download, and player tests relevant to touched code pass.
13. Each implementation phase receives visual review on a phone in Dark, AMOLED, and Light, plus an Arabic RTL pass. Tablet screenshots are required for responsive navigation and layouts.
14. Touched files are formatted and Flutter analysis reports no new issues. Known pre-existing failures must be distinguished from regressions.

## Implementation sequencing proposal

The work is intentionally phased so each group can be reviewed as a coherent, runnable increment:

1. **Design-system foundation and audit:** document current component reuse, establish missing semantic tokens/primitives, define page-level design rules and a visual review checklist.
2. **Primary discovery experience:** Home and shared media presentation, then New & Hot and Discover.
3. **Search and personal hub:** Search and My 7xPlay, including the library entry points they own.
4. **Content journey:** movie/series details, collections, seasons, episodes, people, credits, and galleries.
5. **Library and account surfaces:** downloads, bookmarks, playlists, profile/settings, sync, server/update/about, Plus/payment/wallet, and auxiliary screens.
6. **System-wide refinement:** supporting sheets/dialogs/empty/loading/error states, tablet adaptation, RTL, text scaling, accessibility, motion and performance.
7. **Verification and integration:** behaviour tests, theme and screenshot matrix, TV/deep-link checks, review of the complete PR, and only then merge/build decisions.

This sequencing is a proposal for the implementation plan; exact file-level tasks, interfaces, and test commands belong in the plan after this design is approved.

## Open design questions

No product decision is required to preserve the current five-tab navigation, dark-first 7xPlay identity, Android TV/player boundaries, or existing functionality. The remaining creative decisions are deliberately delegated to the implementation plan and visual review, within the constraints above.

## Current in-flight work

PR #24 contains an early mobile catalogue polish and a substantial title-details layout experiment. It is not accepted as proof that the full redesign is complete. The implementation plan must audit that diff, retain useful work, revise anything that conflicts with this design, and expand scope to the rest of the app. Keep PR #24 draft until relevant validation and visual review are complete.
