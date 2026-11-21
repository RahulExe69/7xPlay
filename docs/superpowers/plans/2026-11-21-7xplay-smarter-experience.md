# 7xPlay Smarter Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add local personalized Home recommendations, saved-title release updates, and more relevant typo-tolerant universal search to 7xPlay.

**Architecture:** A pure SmartHome helper scores the already-loaded feed using genre IDs from the local bookmark library. Home renders recommendation and watchlist-update rows through existing PosterRow components. MediaSearch gains deterministic title relevance ranking and conservative typo matching without changing its source/API contract.

**Tech Stack:** Flutter, Dart, Provider, existing TMDB-backed catalogue models, Flutter Test, GitHub Actions.

**Spec:** docs/superpowers/specs/2026-11-21-7xplay-smarter-experience-design.md

## Global Constraints

- Base branch: redesign/phase-2-catalog-experience; work on feat/smarter-experience, never on main.
- Do not change API/backend contracts, account semantics, database schemas, playback/provider behavior, ads, analytics identifiers, routes or navigation IDs.
- Add no dependency and no additional catalogue request for recommendation or watchlist shelves.
- Retain the existing bookmark schema's genre_ids column and local-first library behavior.
- Preserve the five Home filter modes and keep movie and series result rows separate.
- Preserve search's 350 ms debounce, people results, per-kind failure isolation, stale-query suppression and recent-search semantics.
- Add user-facing strings to assets/translations/en.json, es.json, ar.json, and hi.json.

## Review Focus

- Legacy bookmarks with null/empty genre IDs must not produce random personalized results — test empty-profile behavior.
- A saved or currently-watched item must not be recommended again — test both exclusion sets.
- Duplicate catalogue entries across feed rows or upcoming/current rows must appear once — test deduplication.
- A typo that is equally close to two different titles must not be auto-promoted — test ambiguity handling.
- A media-type request failing must not affect ranking or suppress other successful media-type results — retain and run existing search failure-isolation tests.

---

### Task 1: Local recommendation and watchlist ranking primitives

**Files:**
- Create: lib/catalog/smart_home.dart
- Create: test/smart_home_test.dart
- Modify: .github/workflows/build-android.yml (include the new test in the catalogue/search test step)

**Interfaces:**
- Consumes: MediaItem.kind, MediaItem.genreIds, MediaItem.stableId, MediaItem.popularity, MediaItem.rating.
- Produces: SmartHome.personalized({required Iterable<MediaItem> candidates, required Iterable<MediaItem> saved, Iterable<MediaItem> continueWatching = const [], int limit = 12}) -> List<MediaItem>.
- Produces: SmartHome.watchlistUpdates({required Iterable<MediaItem> saved, required Iterable<MediaItem> current, required Iterable<MediaItem> upcoming, int limit = 12}) -> List<MediaItem>.

- [ ] **Step 1: Write the failing unit tests.** Cover weighted genre overlap and tie-breakers, exclusion of saved/currently-watched items, empty legacy genre profiles, deduplication and limit, and saved-only matching across current/upcoming lists.
- [ ] **Step 2: Run the test to verify RED.** Run flutter test test/smart_home_test.dart. Expected: the test cannot compile because the new SmartHome contract does not exist yet; this is the expected missing-feature signal.
- [ ] **Step 3: Implement the minimal pure helper.** Derive genre weights per MediaKind, filter excluded/invalid/no-overlap candidates, deduplicate, sort by genre overlap then popularity/rating/title, and cap at the requested limit. Watchlist updates are the ordered intersection of saved IDs with current and upcoming items.
- [ ] **Step 4: Run the targeted test to verify GREEN.** Run flutter test test/smart_home_test.dart. Expected: all new tests pass.
- [ ] **Step 5: Add the new test to CI.** Extend the existing catalogue/search workflow test command to include test/smart_home_test.dart.

### Task 2: Wire smart Home shelves and preserve saved genre metadata

**Files:**
- Modify: lib/mobile/screens/home_screen.dart (homeRows)
- Modify: lib/mobile/my_list.dart (fallback Movie/TV constructors)
- Modify: test/home_screen_test.dart
- Modify: assets/translations/en.json
- Modify: assets/translations/es.json
- Modify: assets/translations/ar.json
- Modify: assets/translations/hi.json

**Interfaces:**
- Consumes: SmartHome.personalized, SmartHome.watchlistUpdates.
- Produces: per-kind Picked for you and Updates to your list PosterRow sections, only when non-empty.

- [ ] **Step 1: Add failing Home behavior tests.** Use a saved movie/series with genre metadata and a feed with overlapping and non-overlapping candidates. Assert the per-kind Picked for you row is present with the correctly ordered non-saved items. Add a separate case where saved titles overlap the feed's current/upcoming lists and assert the updates row contains only saved matches, with duplicates removed. Assert cold-start users have neither row.
- [ ] **Step 2: Run the relevant tests to verify RED.** Run flutter test test/home_screen_test.dart. Expected: the new row assertions fail because homeRows does not yet render them.
- [ ] **Step 3: Persist available genre metadata in fallback MyList conversions.** Set genreIds: item.genreIds when constructing fallback Movie and TV objects.
- [ ] **Step 4: Build recommendation/update candidates from the existing HomeFeed.** Rank already-loaded spotlight, top-ten, trending, popular, new-release, top-rated, upcoming and service-shelf items; exclude My List and Continue Watching. Include both new-release/on-air and upcoming rows when finding watchlist updates. Do not issue another network request.
- [ ] **Step 5: Integrate both rows into the existing lead repetition budget.** Keep rows per media kind and use existing PosterRow; maintain the first-feed repetition cap and mixed-kind My List behavior.
- [ ] **Step 6: Add translated row labels.** Use picked_for_you and my_list_updates keys in all four supported locale files.
- [ ] **Step 7: Run the targeted tests to verify GREEN.** Run flutter test test/home_screen_test.dart test/smart_home_test.dart. Expected: all tests pass.

### Task 3: Improve universal-search relevance and conservative typo matching

**Files:**
- Modify: lib/catalog/media_search.dart
- Modify: test/search_screen_test.dart

**Interfaces:**
- Produces: MediaSearch.rankTitles(String query, List<MediaItem> items) -> List<MediaItem>.
- Preserves: MediaSearch.run, topResultFor, source interfaces, debounce and UI generation handling.

- [ ] **Step 1: Write failing tests.** Assert an exact title is ranked ahead of a more popular prefix/substring candidate; a single-edit typo such as avatr uniquely promotes Avatar; and two equally close typo candidates do not produce a speculative top result.
- [ ] **Step 2: Run the targeted test to verify RED.** Run flutter test test/search_screen_test.dart. Expected: the fuzzy-match assertion fails because current topResultFor supports exact and prefix only.
- [ ] **Step 3: Implement deterministic relevance ranking.** Normalize titles using the existing normalize; score exact, starts-with, contains and bounded token edit-distance matches in descending order; break ties with popularity, rating and stable title ordering.
- [ ] **Step 4: Keep fuzzy top-result promotion conservative.** Promote a fuzzy-only result only when it is the unique candidate at the smallest accepted edit distance; leave ambiguous candidates in the normal result list without a top-result guess.
- [ ] **Step 5: Apply ranking independently to movie and series results.** Keep people ordering unchanged and retain per-kind error isolation.
- [ ] **Step 6: Run the targeted tests to verify GREEN.** Run flutter test test/search_screen_test.dart. Expected: all tests pass.

### Task 4: Focused regression verification

**Files:**
- No additional production files expected.

- [ ] **Step 1: Run Home, search, bookmark and catalogue regressions.** Run flutter test test/home_screen_test.dart test/home_feed_controller_test.dart test/continue_watching_test.dart test/search_screen_test.dart test/data/bookmark_repository_test.dart. Expected: exit code 0 and no failed tests.
- [ ] **Step 2: Run Flutter analysis.** Run flutter analyze. Expected: no new issues attributable to this branch.
- [ ] **Step 3: Review the complete branch diff against the recorded base SHA.** Confirm no backend/API schema, DB migration, dependency, playback, ad, route or tab behavior changed.
- [ ] **Step 4: Record the exact CI/build result and deferred notification scope.** Do not claim a passing suite or build unless the relevant GitHub Actions run completed successfully.

---

## Execution Notes

- Use feat/smarter-experience based on PR #24's head SHA. The local container cannot resolve GitHub, so branch isolation and commits are managed through the connected GitHub repository rather than a local Git worktree.
- Test-driven red/green evidence is required. The targeted GitHub Actions workflow is the execution environment for Flutter tests because the repository is not mounted locally.
- Do not merge into the redesign branch or main; preserve the draft PR review gate.
- A fresh independent reviewer is unavailable in this session. Perform a separate self-review after CI and state that limitation in the final report.
