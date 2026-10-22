# Stream feedback and playback reports in Mixpanel

The movie/episode and live TV players share an optional exit survey and a
separate automatic report. Both use the existing `AnalyticsService` and Mixpanel
SDK, sharing the app’s project, identity and registered properties. The legacy
`total_streaming_duration` event also goes to Mixpanel. These custom stream events
are no longer written to Google Analytics. Event names, property names and value
types are preserved; historical Google Analytics data is not migrated.

## Testing on Android mobile or TV

Debug, profile and release builds now use the same normal frequencies:

- Survey: a 10% sample of eligible exits with a three-day cooldown.
- Automatic report: a 20% sample, sent only after at least five minutes of
  actual content playback and when the player exits or is replaced.
- Ads, pauses and buffering do not count toward the automatic report minimum.
- Menus/fullscreen Back behavior and exit-ad ordering are unchanged. Leave the
  player itself to trigger the survey. Automatic episode transitions produce
  only the silent report when selected and eligible.
- Both paths cover Android mobile and Android TV, including remote Select/Back.

The temporary debug frequency overrides are disabled. Hot restart an
already running app to recreate player/service instances with normal defaults.
Mixpanel upload timing does not change these sampling rates or watch-time
requirements.

## When the survey appears

- Only an actual Back/close exit from a player; menus, fullscreen, automatic
  episode changes and provider/channel switches do not trigger a survey.
- At least 60 seconds of observed content playback, or a content playback/setup
  error (including failure to start).
- A local random draw selects 10% of eligible exits, once per player route.
- At most once every three days per installation, including skipped surveys.
  The cooldown is saved when the dialog is rendered, not when it is sampled.
- Back returns immediately. The existing mobile exit ad finishes before the
  survey appears. Navigating away while waiting cancels the pending survey.
- Android TV supports remote focus, Select, and Back. All app languages have
  localized survey text. Users can skip, tap outside, or press Back.

The cooldown reduces the effective prompt rate below 10%. Survey selection is
local: unsampled survey sessions do not produce survey events. The independent
automatic sample below does not use this cooldown or open a prompt.

## Events and fields

Three fixed event names: `stream_feedback_shown`,
`stream_feedback_submitted`, `stream_feedback_dismissed`.
All carry the same frozen playback context; submitted adds `rating` and `issue`.

| Parameter | Meaning / values |
| --- | --- |
| `schema_version` | `1` |
| `media_type` | `movie`, `tv`, `live_tv` |
| `surface` | `mobile`, `tv` (player controls surface) |
| `tmdb_id` | Movie or series TMDB ID, as a string; omitted for live TV |
| `season_number`, `episode_number` | Series only; `s2`, `e3` (existing string values retained) |
| `channel_id`, `initial_channel_id` | Live TV only; last requested and initial channel IDs |
| `provider`, `initial_provider` | Final and initial provider codes; `dlhd` for live TV |
| `source_switches` | User provider/channel switch attempts, including unsuccessful attempts; `switches_0`, `switches_1`, etc. for event-level filtering |
| `quality` | Last observed video height, e.g. `1080p`, otherwise `unknown` |
| `connection_type` | Last observed connectivity transport, e.g. `wifi`, `mobile`, `none`, `unknown`; multiple transports sorted/joined with `_` |
| `network_changes` | Number of observed transport changes after initial detection |
| `session_ms` | Wall time in the player route, including pauses and ads |
| `watched_ms` | Observed content watch time, excluding prerolls, pauses and reported buffering |
| `startup_ms` | Route entry to first advancing content progress, excluding observed active preroll time; absent if content never starts |
| `buffering_ms`, `buffer_count` | Post-start content rebuffer time/count; startup waits and duplicate starts do not inflate the count |
| `rebuffer_ratio` | `buffering_ms / (watched_ms + buffering_ms)`, a fraction from 0 to 1 |
| `error_count` | Content player exception/setup-error observations, not unique root causes |
| `outcome` | `failed_to_start`, `abandoned_before_start`, `completed`, `exited` |
| `network_bytes` | Observed network bytes during the transfer observation window; absent when unsupported |
| `transfer_sample_ms` | Wall duration of that observation window |
| `stream_mbps` | Passive average receive rate in decimal Mbps, only with a positive byte delta and at least 10 seconds of observation |
| `rating` | Submitted only: `good`, `okay`, `bad` |
| `issue` | Submitted only: `none`, `buffering`, `did_not_play`, `quality`, `audio`, `subtitles`, `wrong_content`, `other` |

The SDK adds its standard metadata alongside the app’s registered `Platform`
and `OS Version` properties. Diagnostic properties remain structured strings
and numbers; Mixpanel does not require GA4 custom dimension registration.
No written comments, stream URLs, headers, tokens or raw error strings are sent.

### Reading the measurements correctly

`stream_mbps` is **not available internet bandwidth** and is not a speed test.
It uses the player's existing native byte counter. The baseline starts after
content progresses (or at the first available subsequent byte observation),
so initial prebuffering and most ad traffic are excluded. Native byte batches
can straddle the ad/content boundary. The window includes pauses, idle time and
source switches; caching and player download scheduling affect the rate.
Missing throughput means unavailable/insufficient observation, not zero speed.

This is one survey per player route, so measurements span all sources/channels
used in that route. For provider/channel fault attribution, start with
`source_switches = switches_0`. For switched routes, initial/final identifiers provide
context but cannot identify which source caused each stall. Source setup and
scraping before the player route opens are not included in `startup_ms`.
The survey describes respondents, not every playback session; do not interpret
its bad-rating percentage as the failure rate of the entire user population.

## Automatic reports for 20% of streams

`AutomaticStreamReport` draws once when each player session is created:
`Random().nextInt(5) == 0`. Selected sessions that meet the five-minute watch
minimum emit one `stream_playback_report` event when the player is exited or disposed. This
includes automatic episode/movie changes and navigation that removes the
player without calling its Back handler. The player does not wait for Analytics.
A final native byte flush waits at most two seconds in the background, then uses
the last observed counter if the native call fails or hangs.

There is no prompt or three-day cooldown for automatic reports. A selected
session is sent only if `watched_ms >= 300000` (five minutes). Pauses, prerolls,
startup waits and buffering do not count toward this minimum. The minimum also
applies in debug builds and to sessions with playback errors. Failed starts,
short watches and exits during ads produce no automatic report. The event still
sends when the player exits or is replaced, not immediately at the five-minute
mark. There is no additional per-progress event traffic. Sampling is per player
route, not per HLS segment, quality change, provider switch, or live channel switch. Each new
episode/movie player makes a new draw. A live route's report spans its channels;
use `source_switches = switches_0` for attribution to one channel/provider.

The automatic report contains exactly the same frozen content and diagnostic
fields as the survey, but substitutes these two fields for `rating` and `issue`:

| Parameter | Meaning |
| --- | --- |
| `end_reason` | `user_exit`, `content_switch`, or `route_disposed` |
| `playback_health` | The highest-priority observed diagnostic label below |

Labels, in priority order:

1. `failed_to_start`: no advancing content progress and at least one error.
2. `not_observed`: no advancing content progress and no observed error.
3. `playback_errors`: content started but one or more errors were observed.
4. `heavy_buffering`: at least 3 seconds rebuffering and a rebuffer ratio of at
   least 5%.
5. `slow_start`: at least 10 seconds startup time, excluding observed preroll.
6. `insufficient_playback`: fewer than 15 seconds watched, with none of the
   preceding observed issues.
7. `no_observed_issue`: none of those signals were observed over at least 15
   seconds of content playback.

The shared classifier also describes shorter survey sessions. Automatic reports
cannot have `failed_to_start`, `not_observed` or `insufficient_playback` labels
because their five-minute watch minimum excludes those sessions. Automatic data
therefore describes sustained watches, not the failure rate of all attempts.

These are initial diagnostic thresholds, not a user satisfaction score or proof
that the stream was correct. Audio sync, subtitle accuracy and wrong content
still require user feedback. Raw measurements remain available when several
issues occurred together. Existing Mixpanel collection settings/consent still apply.

A Back handler and subsequent dispose share the same report reservation and
immutable measurement snapshot, so they cannot double-report or resample.
Forced process termination and crashes may skip dispose and lose that session's
report; this is not crash reporting or an exact census of stream attempts.
Loader/scraper failures before a player is created are outside this sample.

To use this in another player, create one `AutomaticStreamReport` with its state,
collect the shared `StreamFeedbackSession` measurements, then call `send` before
disposing the native controller. Pass a `StreamFeedbackContext`, a frozen
measurement, the end reason, and the native counter/flush callback. Production
writers send through `AnalyticsService` to Mixpanel; tests inject a writer/random
draw or mock the SDK transport.

## Reading the reports in Mixpanel

Use the same Mixpanel project as the app’s other events. No new token, SDK or
backend is required. After an updated build sends events:

1. Open **Events**, filter by `stream_playback_report` or one of the survey event
   names, and expand an individual event to inspect its properties.
2. In **Insights**, select `stream_playback_report` and count Total Events.
   Break down by `provider` or `playback_health`. Filter by `media_type`,
   `surface`, `connection_type` and `source_switches = switches_0` as needed.
3. Add numeric property aggregations, such as average or P90 `startup_ms` and
   `rebuffer_ratio`, to compare playback measurements.
4. For survey results, select `stream_feedback_submitted`, break down by `rating`
   or `issue`, and filter to the provider/content of interest. Compare shown,
   submitted and dismissed counts separately to assess response rate.

Useful investigations:

- Bad-rating share per provider, with response counts alongside percentages.
- `wrong_content` by TMDB ID and season/episode to identify bad source matches.
- Survey `failed_to_start` outcomes and `did_not_play` issues by provider/version.
- Buffering complaints alongside rebuffer ratio and connection type.
- Automatic `playback_errors` and `heavy_buffering` among sustained watches.

Keep automatic and survey events separate in counts and rates. The legacy
`total_streaming_duration` event carries the existing rolling in-memory
`duration_seconds` counter and retains its previous call sites; it is separate
from the sampled, five-minute-gated diagnostic report. Do not sum its rolling
values to estimate total watch time.

## Verify before release

Use an updated Android mobile or TV build and inspect the project’s **Events**.
The Flutter SDK batches events, normally uploading about every 60 seconds while
the app runs and when it enters the background. Awaiting event logging means
SDK enqueue completion, not server acknowledgement. Existing Mixpanel opt-out
settings remain effective; tracking failures never block Back.

Normal sampling and the survey cooldown apply in debug builds too. Verify movie,
episode and live playback, failed starts, provider/channel switches, exit ads,
remote Back/Select, and network changes. Survey events should include the same
playback context, with rating/issue added only on submission.

For automatic reports, watch content for at least five minutes, then exit or
advance to another episode. Only selected qualifying sessions produce a
`stream_playback_report`; exit followed by dispose must not duplicate it. A watch
shorter than five minutes, including a failed start, must not send an automatic
report. Hot restart after changing build/debug settings. A missing individual
event can be expected from sampling; it does not by itself show an upload failure.

Automated tests check normal sampling, cooldown, minimum watch time, complete
payloads, duplicate suppression and failure handling. SDK transport tests verify
that the default production writers route all four stream diagnostic events and
the legacy duration event to the existing Mixpanel instance. Injected writers
and mocked platform transport prevent tests from sending live events.

References:

- [Mixpanel Flutter SDK](https://docs.mixpanel.com/docs/tracking-methods/sdks/flutter)
- [Mixpanel Insights](https://docs.mixpanel.com/docs/reports/insights)
- [Inspecting raw events in Events View](https://mixpanel.com/blog/updated-live-view-a-more-powerful-tool-to-help-you-debug-and-integrate-mixpanel/)
