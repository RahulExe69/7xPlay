# 7xPlay YouTube × FlixQuest Fusion Design

Date: 2026-11-22
Status: implementation direction approved by the user through an explicit request to begin the fusion redesign.

## Intent

Make 7xPlay feel immediately familiar to people who use YouTube without turning it into a generic video app or removing its FlixQuest entertainment identity. The product combines YouTube's browsing grammar—feed-first discovery, compact app chrome, category chips, thumbnail-led cards, fast search access, persistent mini-player and low-friction navigation—with FlixQuest's movie/series/anime catalogue, cinematic title pages, season/episode browsing, provider/server selection, audio/subtitle controls, downloads and playback.

The result must feel like one coherent 7xPlay product, not two apps stitched together.

## Goals

- Give Home a YouTube-like, vertically browsable feed with wide thumbnail cards, familiar category chips and clear metadata.
- Retain OTT shelves where they add value: Continue Watching, trending, new episodes, popular movies, anime and curated collections.
- Make search immediately accessible from the top app bar while retaining the existing Search route and stable destination ID.
- Make bottom navigation familiar and predictable while preserving all existing destination IDs and restoration behavior.
- Keep title details, seasons, episodes, providers, playback, downloads and offline library unmistakably entertainment-first.
- Make the mini-player and player transitions feel persistent and connected to browsing, without changing stream selection or playback-engine contracts.
- Preserve brand identity: near-black cinematic base, warm amber/orange and selective pink/violet; wordmark in app chrome.
- Maintain phone, tablet, Android TV, accessibility, reduced-motion and localization support.

## Non-goals

- Pixel-perfect copying of YouTube branding, proprietary assets, exact layouts or trademarks.
- User-generated video uploads, creator channels, comments, likes, monetization or social graph.
- A Shorts feed unless a lawful, supported short-clip catalogue exists; trailers/previews can be surfaced only from verified metadata.
- Replacing Flutter, the player engine, scraper/provider integrations, TMDB catalogue interfaces, local persistence or native platform code.
- Introducing Firebase/Supabase/backend requirements, accounts, new permissions or extra catalogue requests to simulate YouTube features.
- Reworking Android TV into a phone-style UI.

## Product behavior

### App chrome and navigation

- A compact YouTube-inspired top app bar uses the 7xPlay wordmark, Search, Cast (only when existing support is available) and profile/library entry points.
- The five stable tab IDs remain `home`, `new`, `discover`, `search`, and `mine`. The phone dock is edge-to-edge and ordered Home, Explore, New & Hot, Search and You; labels/icons may be refreshed, but IDs, deep links, analytics and session restoration remain compatible.
- The visible phone navigation prioritizes Home, Explore, New & Hot and You/Library destinations; Search is always reachable from the top app-bar action and remains a valid restored/deep-linked destination. A fifth visible destination may remain if required by the existing tab model; implementation must avoid hiding a route without an alternative entry point.
- Tablet navigation retains a side rail and TV navigation remains unchanged.

### Home feed

- Top category chips filter the existing catalogue without creating new backend requests.
- A vertical feed uses YouTube-like full-width landscape cards for featured recommendations and editorial rows.
- Existing horizontal poster shelves remain for dense browsing and recognizable OTT discovery patterns.
- Continue Watching and My List updates remain prominent and use existing local history/bookmark data.
- Trending Home shelves use up to three centered, max-width video-feed cards per content type, with See all opening the full collection; Top Ten, My List, genre and service shelves retain their OTT poster treatments.
- Cards expose title, year, content type, rating/genres when available, and overflow actions such as Watch Later/My List. Do not invent views, likes, creators or engagement metrics.

### Search and Explore

- Search action opens the existing SearchScreen from Home, Explore, New & Hot and You, and preserves debounce, history, filters, person results and ranking.
- Movie and series search results use full-width video-feed cards with title metadata and familiar play/overflow affordances; people results and genre discovery retain their specialized layouts.
- Explore retains FlixQuest's rich movie/series filters, genre/provider/year/rating/status selection and collection results, presented with a more familiar browsing surface.
- New & Hot remains the release/trending surface, not a fabricated subscriptions feed.

### Entertainment details and playback

- Movie/series details retain backdrop/poster, synopsis, genres, cast, trailers, related titles, Play/Resume, Download, My List, seasons and episodes.
- Provider/server selection, audio selection, subtitle tools and download recovery remain unchanged.
- The player may adopt YouTube-like gestures and mini-player affordances only where the existing custom player supports them safely. No changes to source-selection or recovery policy as part of the visual migration.
- Existing Android TV layout and D-pad focus model remain intact.

## Approaches considered

1. **Full YouTube clone:** rejected. It would erase FlixQuest's cinematic identity and require unsupported creator/social/short-form concepts.
2. **Small YouTube-inspired Home only:** rejected. It would leave Search, navigation, mini-player and other surfaces feeling disconnected.
3. **Unified hybrid experience (selected):** adopt YouTube's browsing grammar across app chrome, feed, search access and player continuity, while retaining FlixQuest's OTT content model and detailed entertainment flows. This best matches the user's explicit clarification.

## Implementation calls

- Keep Flutter and existing dependencies.
- Build on merged `main` after PR #24; do not base the fusion branch on closed PR #28.
- Keep open PR #27 safe and separate. Its smarter Home/search changes are stacked on the PR #24 foundation and should be reviewed/rebased independently before merge.
- Use existing media models, controllers, providers and local persistence.
- Prefer extending shared widgets over duplicating a second navigation or content system.
- Keep current theme modes and brand palette; default dark remains the visual centre.
- Use tests for stable tab IDs, navigation entry points, feed card semantics, accessibility and preservation of existing details/player routes.
- No backend, account, dependency or schema changes without a separate approval.

## Acceptance criteria

- The Home page reads as a familiar, thumbnail-led video feed while still showing recognizable movie/series/anime shelves.
- Search is discoverable from the top bar and existing Search route still works for restore/deep links.
- Details and episode browsing retain FlixQuest behavior and data.
- Existing play, download, provider selection, audio/subtitle, My List and watch-history callbacks remain connected.
- All five stable tab IDs and restoration tests continue to pass.
- Tablet and TV navigation behavior is not regressed.
- UI is responsive, localized, accessible and respects reduced motion.
- CI tests and Android build complete successfully; physical-device validation is explicitly reported separately if unavailable.
