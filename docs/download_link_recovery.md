# Expired offline download links

New API-backed movie, episode and in-player downloads save a versioned source
identity: API base URL, provider ID and display name, raw server/quality, TMDB ID,
season/episode, format, height limit and audio choice. Preparation also records
the actual selected video/audio formats, including implicit default audio.
Display quality labels are not used to identify a server.

The native `RecoveringDownloader` runs inside Media3's existing download task.
It attempts the existing URL first, including on resume/retry. A positive expiry
response (an expiry message, or a rejected signed URL with a past expiry) can
trigger renewal through `/stream-movie` or `/stream-tv`. Generic 403/404 responses,
connection failures, timeouts, rate limits and server errors do not trigger a
scrape. Recovery is bounded to two successful renewal attempts per task; a
failed renewal is not repeated by Media3's automatic I/O retries. Manual retry
can try again later.

Renewal asks the saved provider for all servers, with the existing documented
fallback when full collection is disabled. Provider, server, raw quality and
format must match uniquely. The native helper then selects the original actual
video/audio identities and produces new stream keys. Missing or ambiguous
matches fail normally; there is no provider, quality or language substitution.
New headers replace expired source headers. Already saved subtitles are retained.

Refreshed requests are atomically checkpointed in `offline_requests/`. Media3's
original request remains the job identity, avoiding its stream-key merge behavior.
Queries, offline playback and MP4 export resolve the checkpoint. Pause/remove
cancel the task; late renewal cannot save or start a replacement after cancel.
Repeated enqueue of the same selection resumes its existing job, while a different
selection is rejected instead of mixing caches.

Each refreshed manifest has a new cache namespace. Complete resources at the
same URI can be copied locally when their strong ETag and full length match and
the existing bytes pass their recorded SHA-256 checksum. Manifests, changed URLs,
changed validators, weak/missing validators, partial resources and byte ranges
are fetched again. Signed parameters are never stripped from cache identities.
This preserves verified media where possible, and permits a full restart only
when no existing resource can be verified. Old cache generations are removed
when the replacement completes; removal also clears retained generations.

Downloads without this metadata, including pre-existing downloads and the
separate direct VixSrc provider, retain normal failure behavior. They are never
silently re-added or switched to an API provider. A damaged checkpoint fails
safely and does not prevent deleting the original download.

## Verification

Fixtures in `postman/mocks/download-recovery` follow `openapi.json`; HLS segment
bodies are synthetic. The owner's published-mock search was skipped because the
Postman CLI is signed out. No live CDN/provider behavior is claimed.

Start the local simulation on its documented fixture port:

```sh
postman simulation run postman/simulations/download-recovery.sim.yaml --port 4928 --output ndjson
```

From `android/`, with Java 17:

```sh
FQ_DOWNLOAD_SIMULATION_URL=http://127.0.0.1:4928/downloads ./gradlew :app:testDevDebugUnitTest --tests 'dev.beamlak.flixquest_v2.downloads.*'
```

The HTTP tests exercise the actual native resolver and Media3 HLS downloader/cache:
expiry during a segment, renewed headers, verified reuse without reading the
second HTTP body, changed/weak/missing validators, length changes, partial/corrupt
cache, source mismatch, malformed responses, full-collection fallback, checkpoint
reload and reading the completed cache with no upstream. They skip when the
simulation URL is absent. The other native tests run without the simulation and
cover exact track selection after manifest reordering, bounded retries,
cancellation, persistence, legacy behavior and removal.

From the Flutter project root:

```sh
.fvm/flutter_sdk/bin/flutter test --no-pub test/offline_download_test.dart test/download_audio_selection_test.dart test/video_utils_test.dart
```

A real-device pause/resume against production providers is still needed to verify
their particular expiry responses and cache validators. The synthetic media tests
verify cache readability, not decoded playback.
