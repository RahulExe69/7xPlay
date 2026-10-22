# TMDB connectivity simulation

These local stand-ins exercise the actual Flutter HTTP client and mobile/TV
search sources without sending requests to TMDB or the paid proxy. Direct
access returns an ISP-style HTML 451 block page. The proxy implements only the
configuration and catalog/search response shapes consumed by this app; other
routes return 501. Fixtures are derived from the existing URI wrapper and model
parsers. The owner's published mock search was skipped because the Postman CLI
is signed out. These fixtures do not validate the live services.

Run with Postman CLI 1.74 or later:

```sh
postman simulation run postman/simulations/tmdb-connectivity.sim.yaml --port 4917 --output ndjson
```

In another terminal:

```sh
TMDB_SIMULATION_URL=http://127.0.0.1:4917 .fvm/flutter_sdk/bin/flutter test --no-pub test/tmdb_proxy_search_test.dart
```

Inspect the simulation's request events: two failed direct configuration checks and one
successful proxied configuration check establish fallback, then the original search
requests succeed through the proxy. No logs or credentials belong in Git.
Stop the simulation with Ctrl-C.

`test/tmdb_connectivity_test.dart` additionally uses controllable loopback HTTP
servers for offline failures, timeouts, concurrent checks, network recovery,
manual-off races, API errors, no network, Wi-Fi without internet, and temporary
connection failures. The widget tests verify touch and TV remote
controls cannot enable proxy mode.
