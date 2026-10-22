# DLHD loader transport check

This local fixture follows the catalog contract in `openapi.json` and the token
and media wrapper code observed in channel 110's browser embed on 2026-10-21.
No published owner mock was consulted: these are third-party browser endpoints
without a supplied API contract. The video packets are synthetic. A pass proves
HTTP routing, token acquisition, playlist rewriting and segment unwrapping; it
does not prove video decoding or availability of the live CDN.

Run from the repository root in separate terminals:

```sh
postman simulation run postman/simulations/dlhd-loader.sim.yaml --port 4931 --no-history --output ndjson
```

```sh
DLHD_SMOKE_MOCK_SLUG=dlhd .fvm/flutter_sdk/bin/dart run tool/dlhd_live_smoke.dart http://127.0.0.1:4931 110
```

The simulation log must show the catalog, watch page, embed, token endpoint,
signed manifest and all three segments. Stop the simulation with Ctrl-C.
Use `DLHD_SIM_ORIGIN` on the simulation process if choosing another port.

The watch page advertises three players. The smoke check asserts that only
Player 1 was requested during initial resolution. After reading its three media
segments, it supplies the content-progress signal used by the shared mobile/TV
player and waits for the deferred backups. Player 2 is deliberately slower than
Player 3; successful results are published individually and displayed in their
advertised order. This signal tests discovery sequencing, not native rendering
or the UI event delivery on a physical phone or TV.

The same smoke command without `DLHD_SMOKE_MOCK_SLUG`, using
`https://scraper.flix.quest` as the base URL, tests the real production resolver.
`test/dlhd_playback_proxy_test.dart` additionally checks 403 token renewal,
relative variant/key/map URLs, shared sessions, PNG/WebP/gzip/raw TS wrappers,
and rejection of invalid media and unknown loopback resource URLs.
