# 7xPlay Phase 0 — Initial Repository Audit

**Audit date:** 2026-10-29  
**Repository:** `RahulExe69/7xPlay`  
**Scope:** Read-only source-tree and selected-file inspection. This is an initial audit, not a full build or runtime verification.

## Confirmed findings

### Framework and platform
- The project is a Flutter/Dart application. `pubspec.yaml` identifies the package as `flixquest` and declares Flutter/Dart dependencies.
- The Android application ID and Gradle namespace are currently `dev.beamlak.flixquest_v2`.
- Android manifest and Kotlin source trees contain original-project package paths. Renaming package identity requires coordinated updates, not only changing the display name.
- Android-specific functionality exists for downloads, playback, links, widgets, and streaming Do Not Disturb. These integrations should be regression-tested before any framework migration.
- The README still brands the project as FlixQuest and describes Android mobile/tablet/Android TV support. The launcher/splash assets and widget resource names also include original branding.

### Search and provider architecture
- Search/catalog logic exists in `lib/catalog/media_search.dart`; it includes a `SearchSource` abstraction and TMDB search source.
- Stream providers are implemented separately under `lib/video_providers/`, including `provider_loader.dart` and `scraper_api.dart`.
- `ProviderLoader.loadFirstSuccessful` is documented as trying providers sequentially and stopping at the first successful provider. This is relevant to the desired all-provider aggregation: current stream resolution and global catalogue search are distinct flows and should not be conflated.
- A provider-selection screen exists at `lib/screens/common/provider_choose.dart`. The desired user experience should allow broad search first while preserving source selection when needed for playback.
- Further code-level tracing is required before changing search or playback behaviour.

### Advertising
- Advertising code is spread across several areas, not just a single policy flag. The repository tree includes ad policy, content ads, placements, ad repositories, VAST handling, playback-ad services and widgets, ad-block checks, hosted banners, native Android ad bridges, ad configuration documents, and numerous tests.
- `lib/data/ads/ads_policy.dart` currently initializes its ad-free notifier to `false`; it does not default to globally ad-free.
- The player imports ad-related widgets/services directly. Removing ads safely therefore requires a dependency/call-site audit, not merely changing a boolean.
- Existing ad tests should be revised or replaced to verify that ad requests and UI are absent in the intended 7xPlay build, while playback and unrelated features still work.

### Authentication and integrations
- The app contains existing authentication, API, Firebase, notification, analytics, subtitle, metadata, and AI-related code. These must be mapped before removing or replacing services.
- Preserve the current account backend initially unless a separate, planned migration is approved. Rebranding should not silently break existing accounts.
- Do not infer backend ownership, service availability, or AI model/quota details from client-side code alone.

### Tests and build status
- The repository contains a substantial Flutter test suite and Android native tests, including tests related to ads, player behaviour, downloads, authentication, API contracts, and search.
- This audit did not execute Flutter analysis, tests, Gradle builds, or runtime playback. No build/test pass is claimed.

## Risks to resolve before implementation

1. **Brand and Android identity:** choose whether to change application ID. A new ID is a different Android install identity and may prevent in-place upgrades from the old app.
2. **Local dependency:** `pubspec.yaml` references a path dependency at `../flixquest-betterplayer`. A clean CI/build environment must confirm how this dependency is supplied.
3. **Ad removal scope:** legacy code, native bridges, configs, dependencies, and tests all need a deliberate removal plan.
4. **Search aggregation:** catalogue search, provider discovery, and playable-stream resolution are different responsibilities. Build a shared media/source model rather than merging arbitrary result lists by title alone.
5. **Provider reliability:** distinguish a provider page from a resolved playable stream and preserve provider-specific requirements where allowed.
6. **Legal and upstream obligations:** preserve GPL-3.0 and third-party notices and review applicable distribution terms.

## Recommended implementation sequence

1. Finish tracing search-to-watch flow and the player resolver contract.
2. Record a baseline build/analyzer/test result when the required Flutter SDK and local path dependency are available.
3. Establish the final application ID and branding asset plan before identity changes.
4. Remove ads comprehensively in a dedicated, reviewable change.
5. Implement provider aggregation and deduplication with focused unit tests.
6. Fix and verify the Watch-to-playback path.
7. Complete branding cleanup, then build and test release artifacts.

## Audit status

- [x] Repository tree and selected configuration/source files inspected.
- [x] Major branding, ad, provider, platform, and test areas identified.
- [ ] Full search-to-player call graph traced.
- [ ] Baseline Flutter analysis/tests/build executed.
- [ ] All external services and their ownership documented.
- [ ] Implementation-level verification completed.

This report should be updated as additional code paths are traced and tests are run.
