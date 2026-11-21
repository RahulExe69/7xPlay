# 7xPlay Smarter Experience — Design

**Status:** Approved by the product-owner instruction to plan and execute  
**Date:** 2026-11-21  
**Repository:** RahulExe69/7xPlay  
**Base:** redesign/phase-2-catalog-experience at 34359b01a9a39a93fb1994405866ee7128a39420

## Intent

Make 7xPlay feel more personal and helpful without adding a mandatory account, hosted recommendation service, API dependency, or persistence migration. Improve three connected discovery journeys: Home recommendations, saved-title updates, and universal-search relevance.

## Existing behavior

- Home already loads trending, popular, new-release, upcoming, provider, and genre rows through HomeFeedController.
- MyList.items converts the local bookmark library to MediaItem objects. Movie and TV bookmark databases already store genre_ids (schema version 2).
- Continue Watching is local-first and already available to Home.
- Search already queries movies, series, and people in parallel, debounces typing, retains recent searches, and rejects stale responses.
- MediaItem exposes genre IDs, popularity, rating, kind and stable identity.

## Product design

### 1. Picked for you

Add a local deterministic recommendation row, separately for movies and series, using genre affinity inferred from the viewer's saved titles and active Continue Watching titles when matching catalogue metadata is already present in the loaded Home feed.

- Count saved-title genre IDs by media kind, enriching older saved records from matching feed items when available.
- Use active Continue Watching titles as additional taste signals when their matching feed items provide genre metadata.
- Score items already present in the loaded Home feed by overlap with that kind's saved-title genres.
- Use catalogue popularity and rating only as tie-breakers, not as substitutes for taste overlap.
- Exclude titles already in My List or Continue Watching.
- Deduplicate candidates and cap the row at 12 items.
- Do not show a personalized row when there is no usable saved-title or active-history genre profile. Existing curated Home sections remain the cold-start experience.
- Persist genre IDs when a title is added through the fallback MyList conversion path; existing bookmark schema already supports this.

### 2. Updates to My List

Add a local Home shelf for saved titles that appear in the feed's currently-airing/new-release or upcoming rows.

- Derive the shelf from the current Home response; do not issue additional requests.
- Show each saved title once, separated by movie/series in the mixed Home filter.
- Keep the existing My List unchanged.
- Do not claim push alerts or background monitoring. Push notifications require a separately designed polling, permission, quiet-hours and delivery policy and are deferred.

### 3. More relevant universal search

- Rank already-returned movie and series results by normalized title relevance: exact, prefix, contained phrase, then near-match; use popularity/rating as tie-breakers.
- Add bounded edit-distance matching for likely typos (only queries of at least four characters).
- Promote a typo-only top result only when there is a unique best edit-distance match. Ambiguous fuzzy matches remain ordinary results; do not guess.
- Preserve parallel multi-type search, people results, debounce, stale-query suppression, search history, filters and TMDB/API contracts.

## Approaches considered

1. **Local metadata-based ranking (selected):** use saved genres and already-loaded catalogue rows. Fast, deterministic, offline-friendly, private, no backend or dependency changes. Cold-start users keep the curated feed.
2. **Remote recommendation service:** richer cross-device profile, but requires backend/API changes, account semantics, privacy choices and hosting. Rejected for this increment.
3. **On-device ML model:** could learn more nuanced taste, but adds model/runtime size, tuning and explainability costs disproportionate to the current data volume. Rejected for this increment.

## Non-goals

- No new hosted AI or recommendation API.
- No new package dependency.
- No account, auth, backend, database schema, or bookmark-sync contract changes.
- No periodic release polling or push notification permission changes.
- No changes to provider selection, playback, ad placement, analytics event identifiers, navigation routes or tab IDs.
- No false personalization for cold-start or legacy bookmarks with missing genre metadata.

## Global constraints

- Preserve the approved 7xPlay visual identity and existing Home row/card primitives.
- Preserve Home's distinct movie/series rows and existing repetition limit.
- Keep My List and Continue Watching available and unchanged.
- Preserve English, Spanish, Arabic and Hindi translations.
- Keep search results stable when one upstream media type fails.
- Do not reorder people results or alter search history behavior.
- Do not add network calls for recommendations or watchlist updates.

## Acceptance criteria

1. A user with genre-tagged saved titles or active watched titles whose metadata is in the feed sees relevant non-saved catalogue items in a Picked for you row.
2. A user with no genre-tagged saved titles sees no empty or fabricated personalized row.
3. Saved and in-progress titles do not appear in Picked for you.
4. Items appearing in Home new-release/on-air or upcoming feed rows are surfaced in an updates shelf only when saved by the viewer.
5. Updates are deduplicated and separated by media kind.
6. Search sorts exact and prefix title matches ahead of weaker matches even when weaker results have higher popularity.
7. A uniquely close typo match can become the top result; an ambiguous typo does not.
8. Existing search, Home, bookmark, navigation and localization tests pass.
9. No new dependency, database migration, backend contract or API request is introduced.

## Deferred follow-up

A notification-based smart watchlist requires a separate design for release polling cadence, provider/catalogue source-of-truth, notification permissions, quiet hours, duplicate suppression, and battery/network limits. It is deliberately not included in this local-only increment.
