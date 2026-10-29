# 7xPlay — Rebranding & Product Completion Roadmap

> **Status:** Active implementation. Checkboxes represent verified work, not assumptions.
>
> **Current implementation branch:** `rebrand/7xplay-identity-and-apk-size`
>
> **Verified in source changes:** Added a new 7xPlay mark/wordmark, Android launcher and TV banner vectors, Android label, splash/notification assets, About-page links, localized product-name strings, README refresh, and an optimized per-ABI release workflow. The CI build still needs to pass before the build pipeline is considered verified. Fresh screenshots and device-level visual checks remain outstanding.
>
> **Compatibility boundary:** The application ID/namespace (`dev.beamlak.flixquest_v2`) and internal Dart package name (`flixquest`) are deliberately retained for now. Firebase and verified `flix.quest` links are attached to the current Android identity. The separately hosted scraper API is not part of this repository; its legacy `FLIXQUEST_API_URL` config key remains for compatibility.
>
> **Product direction:** Android-first. Keep the current Flutter application for now while avoiding unnecessary blockers to future iOS support. Do not rewrite to React + Capacitor unless a repository audit demonstrates a clear benefit.

## Goals
- Establish a coherent, original 7xPlay identity across the app, repository, and releases.
- Preserve working authentication and useful existing features.
- Remove advertising code and dependencies where appropriate without breaking unrelated functionality.
- Make cross-provider search, deduplication, language aggregation, and playback reliable.
- Deliver tested Android builds and document remaining limitations honestly.
- Preserve applicable open-source licences, notices, and third-party terms.

## Phase 0 — Repository Audit & Technical Decisions
- [ ] Record the default branch, active branches, open pull requests, and current release/build state.
- [ ] Map app architecture, navigation, state management, player, provider interfaces, and network services.
- [ ] Inventory visible and hidden original-project branding.
- [ ] Inventory ad SDKs, ad configuration, ad entry points, manifest declarations, and transitive dependencies.
- [ ] Map account API, scraper/provider service, Firebase, metadata, subtitle, analytics, notification, and AI integrations.
- [ ] Identify which integrations are upstream-owned, externally hosted, or under our control.
- [ ] Record existing tests and baseline build/analyzer results where the environment permits.
- [ ] Identify features that must not regress, including login, guest access, profiles, watchlists, history, subtitles, and playback.
- [ ] Decide application ID, namespace migration, icon direction, versioning, and release strategy before changing them.
- [ ] Keep Flutter as the default unless audit findings justify a framework migration.

**Exit criteria:** A technical inventory exists, risky dependencies are understood, and the app can be built or existing build failures are recorded.

## Phase 1 — Brand Identity
- [x] Use **7xPlay** consistently as the user-facing product name in the main Android label, About page, and four bundled translations; a full-repository/visual sweep is still required.
- [x] Create an original logo and launcher icon suitable for small Android sizes (vector sources added; visual/device review pending).
- [x] Define brand colours and icon style in `docs/7xplay_brand_guide.md`; typography/component-wide UI redesign remains open.
- [x] Update Android launch/splash source resources and configure CI to generate the splash PNG before building; build verification pending.
- [ ] Replace old branding throughout every dialog, overlay, player surface, settings, and error path; About page and bundled translations have been updated, but full source sweep remains open.
- [ ] Update the repository description and refresh screenshots after device review; README and brand-guide documentation have been updated.
- [ ] Remove obsolete assets only after confirming they are no longer referenced.
- [ ] Preserve required copyright, open-source licence, and third-party attribution notices.

**Exit criteria:** A repository-wide search and visual review finds no accidental user-facing old branding; required legal notices remain.

## Phase 2 — Android Identity & Future Platform Readiness
- [x] Update Android app label, launcher icon, and TV banner resource references (native build still needs CI verification).
- [x] Update splash and notification icon source resources.
- [ ] Review Android application ID, Kotlin namespace, deep links, intent filters, and exported components.
- [ ] Decide whether to use com.sevenx.play; do not change the package until upgrade/install consequences are understood.
- [ ] Review permissions and remove only those proven unnecessary.
- [x] Update CI artifact naming to 7xPlay per-ABI release outputs; release version/build-number policy remains to be reviewed.
- [ ] Verify clean installation, app restart, session persistence, and upgrade behaviour.
- [ ] Keep shared business logic and platform-specific code clearly separated where practical.
- [ ] Document iOS blockers and platform-specific dependencies, but do not require an iOS release in this phase.

**Important:** A new application ID is treated as a different Android app identity. Existing installations may not upgrade in place, and local app data may not transfer automatically.

## Phase 3 — UI Rebranding & UX Consistency
- [ ] Apply the 7xPlay design system to home, search, details, player, profile, settings, and subscription screens.
- [ ] Standardise cards, buttons, dialogs, loading states, empty states, error states, and navigation.
- [ ] Remove stale names, logos, watermarks, and upstream-specific UI copy where legally and technically appropriate.
- [ ] Verify responsive layouts on small and large screens and different aspect ratios.
- [ ] Check dark/light themes if both are supported.
- [ ] Fix dead buttons, accidental transparent overlays, broken navigation, and unclear loading feedback.
- [ ] Ensure accessibility basics: readable contrast, scalable text, and labelled controls.

**Exit criteria:** Core journeys can be completed without dead ends, visual glitches, or inconsistent branding.

## Phase 4 — Complete Advertising Removal
- [ ] Remove banner ads and their placement code.
- [ ] Remove interstitials, playback pop-ups/pop-unders, and other intrusive ad triggers.
- [ ] Remove VAST pre-roll and player-exit/relaunch ad behaviour.
- [ ] Remove unused ad SDKs, dependencies, resources, identifiers, and configuration.
- [ ] Remove ad-specific manifest entries and permissions when no longer needed.
- [ ] Remove obsolete ad callbacks, remote-config flags, and dead code.
- [ ] Check build flavours and release variants for leftover ad integrations.
- [ ] Confirm removing ads does not break player startup, navigation, app lifecycle, or unrelated premium entitlements.
- [ ] Run searches for ad SDK/package names and inspect dependency trees.

**Exit criteria:** No unintended ad requests or ad UI remain in supported builds, and the app passes regression tests. Hiding ads with a flag alone does not satisfy this phase.

## Phase 5 — Unified Search Across Providers
- [ ] Search all compatible configured providers without requiring a user to select a server first.
- [ ] Add provider timeouts, cancellation, retries where appropriate, and independent error handling.
- [ ] Show partial results as providers respond, where the architecture allows.
- [ ] Deduplicate the same movie or series across providers.
- [ ] Prefer stable metadata identifiers (for example, TMDB IDs when available); use title, year, media type, season, and episode as fallbacks.
- [ ] Avoid merging unrelated titles with similar names.
- [ ] Aggregate provider/source availability under a single media result.
- [ ] Aggregate available audio languages, subtitle languages, and quality options only when supported by source metadata or verified stream details.
- [ ] Show which provider offers each option and allow source selection when needed.
- [ ] Handle provider failures without failing the entire search.
- [ ] Add sensible caching and pagination without showing stale results as current.

**Expected behaviour:** If one provider offers English, another offers Hindi and English, and another offers Bengali, one deduplicated title should expose the combined available options while retaining the source mapping for each option.

## Phase 6 — Reliable Stream Resolution & Playback
- [ ] Trace the complete flow from tapping Watch to stream resolution and player startup.
- [ ] Fix Watch actions that currently produce an overlay or no visible action.
- [ ] Define a clear contract between provider results, resolver output, and the player.
- [ ] Distinguish playable stream URLs from ordinary webpages and unresolved source pages.
- [ ] Handle supported redirects, required headers, cookies, and source-specific constraints appropriately.
- [ ] Present clear loading, retry, no-source, and playback-error states.
- [ ] Verify pause, seek, buffering, fullscreen, orientation, and lifecycle recovery.
- [ ] Support audio-track selection when the media stream actually exposes multiple tracks.
- [ ] Support subtitle selection and external subtitles where available.
- [ ] Verify playback progress and continue-watching behaviour.
- [ ] Test representative providers, formats, devices, and network conditions.
- [ ] Respect applicable provider terms, content rights, and access restrictions; do not bypass DRM or access controls.

**Exit criteria:** A user can choose a supported source and reach actual playback, or receive an accurate actionable error—not a silent failure.

## Phase 7 — Authentication & Account Safety
- [ ] Re-test sign-in, registration, guest access, sign-out, and session restoration.
- [ ] Re-test password reset/recovery and profile/account updates.
- [ ] Verify secure token storage and authenticated API requests.
- [ ] Verify account deletion and relevant data-handling flows.
- [ ] Preserve existing accounts and backend compatibility during the initial rebrand.
- [ ] Remove legacy authentication paths only after confirming they are unused.
- [ ] Verify errors do not expose tokens, credentials, or private user information.

**Rule:** Do not replace or migrate the authentication backend as a side effect of changing the app's name.

## Phase 8 — Existing Features & Integrations
- [ ] Create a feature inventory before deleting code or dependencies.
- [ ] Re-test watchlists, favourites, viewing history, and continue-watching.
- [ ] Re-test metadata/artwork and subtitle integrations.
- [ ] Review notifications, background work, and app lifecycle behaviour.
- [ ] Inspect Flix AI's backend/model configuration, usage limits, persistence, and error handling.
- [ ] Verify subscription status and entitlement handling.
- [ ] Document which features require external services or account access.
- [ ] Remove genuinely unused dependencies only after code and build checks.
- [ ] Keep useful features working unless a deliberate product decision says otherwise.

## Phase 9 — Backend & Service Configuration
- [ ] Document every backend endpoint and external service used by the app.
- [ ] Keep the account API distinct from the scraper/provider service in documentation and configuration.
- [ ] Identify the responsibilities of Firebase, metadata, subtitles, analytics, and notification services.
- [ ] Confirm ownership, availability, terms, and migration options for each dependency.
- [ ] Separate public configuration from secrets.
- [ ] Do not ship private API keys, service credentials, or privileged tokens in the client.
- [ ] Decide which services to retain, replace, or retire based on evidence.
- [ ] Handle optional-service failures gracefully.
- [ ] Record any server-side work required; a mobile client change alone cannot implement missing backend functionality.

## Phase 10 — Performance, Reliability & Privacy
- [ ] Reduce unnecessary startup work and repeated network requests.
- [ ] Optimise artwork loading, caching, pagination, and memory use.
- [ ] Prevent duplicate provider requests and race-condition UI updates.
- [ ] Handle network changes, timeouts, offline states, and retries.
- [ ] Test long playback sessions and low-memory Android devices.
- [ ] Fix crashes and unhandled exceptions found during testing.
- [ ] Review logging and analytics for sensitive data.
- [ ] Remove dependencies only when safe and supported by build/test evidence.
- [ ] Verify Android back-button, screen rotation, and lifecycle behaviour.

## Phase 11 — Automated Testing & Release Engineering
- [ ] Add/verify reproducible optimized per-ABI release builds; workflow has been changed but CI has not yet passed.
- [ ] Run formatter, static analysis, unit tests, and integration tests that the project supports.
- [ ] Add tests for search merging/deduplication and language/source aggregation.
- [ ] Add tests for Watch action, resolver failures, authentication, and ad-free behaviour.
- [ ] Build and install a release APK on a clean Android device/emulator.
- [ ] Build an Android App Bundle if needed for the distribution target.
- [ ] Test upgrades from prior releases if in-place upgrade compatibility is intended.
- [ ] Verify signing and release configuration without exposing signing secrets.
- [ ] Verify CI workflow status and archive build artifacts.
- [ ] Update version numbers and release notes.
- [ ] Record failed or unavailable tests rather than claiming they passed.

## Phase 12 — Documentation, Licence & Final Cleanup
- [ ] Update README, screenshots, feature descriptions, and build instructions.
- [ ] Update issue templates and contribution instructions where present.
- [ ] Document required environment variables and safe local setup.
- [ ] Search the repository for stale names, package IDs, URLs, and obsolete configuration.
- [ ] Preserve GPL-3.0 and other required licence notices and comply with distribution obligations.
- [ ] Review upstream branding and third-party attribution requirements.
- [ ] Remove only confirmed obsolete files and workflows.
- [ ] Document remaining bugs, provider limitations, platform limitations, and external dependencies.
- [ ] Produce a release checklist and a final verification report.

## Definition of Done

A 7xPlay release is ready only when:
1. The app has a consistent 7xPlay identity.
2. Advertising is removed from supported builds and no longer breaks app behaviour.
3. Search combines and deduplicates provider results correctly.
4. Available languages and sources are accurately represented.
5. Watch leads to working playback for supported sources, with useful errors otherwise.
6. Authentication and essential existing features pass regression testing.
7. Android release builds install and are practically tested.
8. Repository documentation, licensing, and release workflow are up to date.
9. Known limitations and unverified behaviour are clearly documented.
10. No phase is marked complete without evidence.

## Execution Rules

- Work in small, reviewable commits and use feature branches for risky changes.
- Audit before deleting code or replacing a framework.
- Avoid unrelated changes while fixing a specific phase.
- Never claim builds, tests, playback, or provider behaviour were verified unless they were actually checked.
- Keep a progress log with links to commits, PRs, test results, and unresolved blockers.
- Android is the immediate target; iOS is a future compatibility goal, not a release requirement.


## Implementation log — 2026-10-29

- Added original 7xPlay SVG mark and wordmark, plus Android vector icon/background/TV banner.
- Rebranded Android production/dev labels, About-page title and project links, splash layers, status-bar notification icons, and four language files.
- Kept `applicationId`, namespace, package imports, old external dependency repository path, and `FLIXQUEST_API_URL` stable to avoid breaking Firebase auth, deep links, or the externally hosted scraper configuration.
- Changed Android CI from universal debug output to R8/resource-shrunk release builds split by `arm64-v8a`, `armeabi-v7a`, and `x86_64`, with Flutter icon tree shaking and Dart obfuscation/split symbols. Each device-targeted download should be smaller than the old all-ABI debug APK.
- CI build, artifact sizes, signing continuity, install/upgrade behaviour, login, playback, widget appearance, and Android TV visuals remain unverified until the workflow completes and device smoke tests are performed.
- Without a stable production keystore configured as repository secrets, CI falls back to the runner debug key; such an APK is for testing, not a trustworthy long-term update channel.
