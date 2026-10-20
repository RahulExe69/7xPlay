# Stream feedback in Google Analytics

The movie/episode and live TV players share an optional exit survey and a
separate automatic report. Both use the existing Firebase Analytics SDK, never
Firestore or a new backend. The existing Mixpanel analytics are unchanged.

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
Enabling Firebase Analytics DebugView changes upload/debug visibility, not these
sampling rates or the watch-time requirements.

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
| `season_number`, `episode_number` | Series only; `s2`, `e3` so GA4 treats them as app categorical dimensions |
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

The largest submitted payload (series plus all measurements) has exactly 25
custom parameters. Do not add fields without revisiting the GA4 limit test.
App version, OS, device model and geography can use GA4's built-in dimensions.
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
issues occurred together. The largest automatic episode payload also fits the
25-parameter limit. SDK collection settings/consent still apply.

A Back handler and subsequent dispose share the same report reservation and
immutable measurement snapshot, so they cannot double-report or resample.
Forced process termination and crashes may skip dispose and lose that session's
report; this is not crash reporting or an exact census of stream attempts.
Loader/scraper failures before a player is created are outside this sample.

To use this in another player, create one `AutomaticStreamReport` with its state,
collect the shared `StreamFeedbackSession` measurements, then call `send` before
disposing the native controller. Pass a `StreamFeedbackContext`, a frozen
measurement, the end reason, and the native counter/flush callback. Production
writers send only to Google Analytics; tests inject their writer and random draw.

## One-time GA4 setup

1. In Firebase project settings, confirm Google Analytics is enabled/linked.
   Open that same property in Google Analytics.
2. In **Admin → Data display → Custom definitions**, create event-scoped
   dimensions for `rating`, `issue`, `media_type`, `surface`, `provider`,
   `initial_provider`, `quality`, `connection_type`, `outcome`, `source_switches`,
   `playback_health`, `end_reason`. Add `tmdb_id`,
   `season_number`, `episode_number`, `channel_id`, `initial_channel_id` if you
   need content-level inspection. IDs can cause high-cardinality reports.
3. Create custom metrics for `watched_ms`, `startup_ms`, `buffering_ms`,
   `buffer_count`, `rebuffer_ratio`, `error_count`,
   `network_changes`, `network_bytes`, `transfer_sample_ms`, `stream_mbps`.
   For millisecond values choose the milliseconds unit if offered; otherwise
   use Standard and keep the `_ms` suffix. Use Standard for the ratio and Mbps.
4. Wait 24–48 hours for custom definitions to become usable in reports.
5. Under **Explore → Free form**, filter Event name to
   `stream_feedback_submitted`, put Provider in Rows, Rating in Columns,
   and Event count in Values. Add filters for app version, media type, issue,
   connection type, and `source_switches = switches_0` where relevant.

For automatic reports, create a separate free-form exploration filtered to
Event name = `stream_playback_report`. Put Provider in Rows, Playback health in
Columns, and Event count in Values. Filter on media type, app version, network
type and source switches. Inspect startup, buffering and watch metrics alongside
the labels. Keep automatic and survey events separate in counts and rates.

Useful investigations:

- Bad-rating share per provider, with response counts alongside percentages.
- `wrong_content` by TMDB ID and season/episode to identify bad source matches.
- `failed_to_start` and `did_not_play` by provider and app version.
- Buffering complaints alongside rebuffer ratio and connection type.
- Shown versus submitted/dismissed counts to measure survey response rate.

The SDK collects events asynchronously; logging is not a server acknowledgement.
Collection settings/consent still apply. Nothing enables collection against an
existing disabled Analytics setting. Analytics failures never block Back.

## Verify before release

On Android:

```sh
adb shell setprop debug.firebase.analytics.app dev.beamlak.flixquest_v2
```

Use Firebase Analytics **DebugView** with a debug app build. Normal sampling
and the survey cooldown apply in debug builds too. Verify movie, episode and live playback, failed starts,
provider/channel switches, exit ads, remote Back/Select, and network changes.
For automatic reports, watch content for at least five minutes, then exit or
advance to another episode. Each qualifying session should produce one
`stream_playback_report`; exit followed by dispose must not duplicate it.
A watch shorter than five minutes (including a failed start) must not send an
automatic report, even in debug builds. Hot restart after changing build/debug settings.

Automated tests check default sampling and cooldown behavior in debug test
builds, alongside explicit deterministic overrides and minimum watch time.
Injected writers prevent tests from sending live Analytics events.

Disable debug mode after testing:

```sh
adb shell setprop debug.firebase.analytics.app .none.
```

References:
- https://firebase.google.com/docs/analytics/flutter/events
- https://support.google.com/analytics/answer/14239696
- https://firebase.google.com/docs/analytics/debugview
