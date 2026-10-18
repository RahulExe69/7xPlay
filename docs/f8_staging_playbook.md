# F8 validation and staging playbook

F8 implementation now includes an opt-in Flutter-to-Laravel rehearsal, a backend deployment preflight, and a repeatable OneSignal failure simulation. Local verification supports a staging decision; it is not a production cutover approval.

## Run the checks

From Flutter, using the project SDK (verified with Flutter 3.35.7 / Dart 3.9.2):

```sh
flutter analyze
flutter test
flutter build apk --release --flavor prod \
  --dart-define=LARAVEL_API_URL=https://YOUR_STAGING_BACKEND \
  --dart-define=ONESIGNAL_APP_ID=YOUR_PUBLIC_APP_UUID
```

From Laravel:

```sh
php artisan test --compact
vendor/bin/phpstan analyse --memory-limit=1G
php artisan flixquest:migration-preflight --strict --require-onesignal --config-source=firebase --json
```

Preflight exits nonzero for missing hard prerequisites; `--strict` also rejects development deployment settings. It checks encryption key, environment/debug/HTTPS, MySQL, Redis cache, persistent queue/reservation time, pending migrations, active administrator, runtime config owner, conditional Scrypt configuration, cache connectivity, and OneSignal configuration. It does not contact OneSignal, send notifications or change the runtime config source. It does not prove a worker is running, locks are shared, or credentials authenticate successfully.

## Disposable end-to-end rehearsal

`test/integration/laravel_migration_e2e_test.dart` uses the real app repositories over HTTP. It creates a unique synthetic account, signs in as two devices, checks bookmark union, recent-history LWW, actual 25-hour skew rejection/recovery, 451 wellness sessions across uploads/pages, bootstrap/ads ETags, OneSignal subscription registration, token-scoped logout and account deletion. It deletes its synthetic account on cleanup. It skips in normal test runs unless both defines below are supplied.

Use an isolated local backend or disposable staging database, never production. Disable on-demand Firebase account lookup for this synthetic rehearsal. For an isolated SQLite local run, set `DB_CONNECTION=sqlite`, `DB_DATABASE` to a newly created absolute temporary file, `CACHE_STORE=array`, `QUEUE_CONNECTION=database`, and `FIREBASE_MIGRATION_ENABLED=false` for both migrations and the server. Run `php artisan migrate --force`, then `php artisan serve --host=127.0.0.1 --port=8018 --no-reload`. **The `--no-reload` option is necessary:** Laravel's reload mode otherwise drops most inherited environment overrides before launching its HTTP child process.

From Flutter:

```sh
flutter test test/integration/laravel_migration_e2e_test.dart \
  --dart-define=FLIXQUEST_E2E_API_URL=http://127.0.0.1:8018/api/v1/ \
  --dart-define=FLIXQUEST_E2E_ALLOW_WRITES=true
```

Replace the URL only with a disposable staging environment. The test does not accept a real user's credentials and sends no real push. For MySQL parity, run this against the planned MySQL/Redis staging deployment as well; a local SQLite pass cannot establish MySQL concurrency behavior.

## OneSignal failure simulation

A local Postman mock implements the provider contract subset this application uses, based on the official Create Message/idempotency documentation. No Postman account or real OneSignal key is needed. Owner-published mock discovery was unavailable because the CLI was signed out; the free API-discovery endpoint also returned 403. This is a locally maintained contract subset, not a provider certification or a complete OneSignal emulator.

From Laravel, in one terminal:

```sh
postman simulation run postman/simulations/onesignal.sim.yaml --port 4900 --output ndjson
```

In another:

```sh
ONESIGNAL_SIMULATION_URL=http://127.0.0.1:4900/onesignal \
  php artisan test --compact tests/Feature/OneSignalSimulationTest.php
```

The tests run Laravel's real HTTP transport and queue job against success, 429, 503, 403, empty audience and acceptance followed by connection loss. Retries use identical payloads/keys. The mock's `/__control` and `/__requests` routes are local test controls only; never point production at this simulator or publish its controls publicly.

## Local verification record — 2026-10-18

| Check | Result |
|---|---|
| Flutter analyzer | 0 issues |
| Full Flutter suite | 1,553 passed, 4 skipped (including opt-in live rehearsal) |
| Laravel suite | 313 passed, 6 skipped (the opt-in provider simulation) |
| Laravel static analysis | 0 errors, with a 1 GB analyzer memory limit |
| Provider simulation over real HTTP | All 6 scenarios passed separately |
| Real Flutter/Laravel rehearsal | Passed against the isolated SQLite server; synthetic account removed |
| Signed prod release APK | 85,264,648 bytes, all three Android ABIs; OneSignal native code and all five retained Firebase plugin integrations present |
| Release launch smoke | Separate read-only phone and TV emulators reached signed-out landing and guest Home shells. This build omits the OneSignal App ID and exercises the FCM fallback; live OneSignal receipt remains untested |
| Local preflight | Only missing OneSignal credentials remain a hard failure; strict deployment checks still fail development-only settings |

TMDB/device-catalog troubleshooting is deferred at the user's request. Default
emulator DNS could not resolve TMDB or Firebase hostnames, while a host-side
TMDB request returned HTTP 200. No catalog-readiness or remote Google-ingestion
claim is made. The initial TV process received SIGKILL without a Flutter/Java
crash trace; relaunch and D-pad guest entry worked, but its cause is not established.
Real OneSignal delivery and controlled/physical-device checks remain pending.

Logs and screenshots are under `/tmp/flixquest-f8-*` and
`/tmp/flixquest-onesignal-*` on the implementation host. These are local evidence,
not committed secret-bearing operational logs.

## Remaining staging gates

| Gate | Required evidence |
|---|---|
| Historical credentials | First login with a real exported Firebase Scrypt sample upgrades to Bcrypt; second login works. Keep private credential files outside Git and use existing verifier options. |
| Google accounts | Existing linked login, provider collision/409 messaging, actual release SHA/client IDs and Android TV flow. |
| Import rehearsal | Run existing import commands with the approved export formats on backed-up MySQL staging; run `flixquest:verify-migration` with source files and a private known-credentials sample; compare per-user counts and repeat import safely. |
| Phone/TV parity | Guest-to-register merge on a second device, real library/wellness sync, offline cold boot/cache, config switching and source-owned offline cache, ad counters in Filament, logout/delete. |
| OneSignal | Create/configure the app, actual phone/TV receipt/taps, permission denial, account changes, small-cohort bulk, schedule/expiry and provider reports. |
| Google reporting | Crashlytics test report and Analytics DebugView/consent on phone/TV, without Laravel telemetry mirroring. |
| Production configuration | HTTPS/MySQL/Redis, supervised workers, backups/restore, health checks and successful strict preflight. |
| iOS | Actual project/native target is absent here; native build/APNs/SDK verification cannot be signed off. |

The local preflight initially found the pending Firebase migration-fields migration.
Its two nullable user fields and the new push tables have now been applied locally;
a private SQLite backup was taken first. No existing source changes were overwritten.
Local hard checks now fail only for the unconfigured OneSignal app credentials;
development deployment settings remain warnings and fail in strict mode.

Keep production `config_source=firebase`. Laravel's current bootstrap still lacks modern network-ad/popup/Telegram fields needed for a complete Laravel-config cutover. Automated tests establish client mapping/source selection, but switching production to the incomplete backend payload would lose feature configuration. Correct that contract and revalidate both sources before changing the operator selection.

## Cutover and recovery

1. Capture a restorable MySQL backup, source export manifest/counts, release identifiers and the current runtime config owner. Rehearse restoration on staging first.
2. Confirm every gate above. Plan phone and TV releases together; this work does not change the public version or publish a build.
3. During the agreed window, stop writes only to migrated Firestore account/library paths. Keep Remote Config publishing, Crashlytics/Analytics and FCM operational. Review the actual Firestore rules; do not use a blanket public-read rule.
4. Export/import the final delta with existing migration commands and rerun source/credential parity verification. Run strict preflight, API/Filament health checks and the synthetic rehearsal on the deployed staging/release candidate.
5. Release the verified build with the correct HTTPS API URL and public OneSignal App ID. Monitor API login/sync/queue failures, ad counters, OneSignal delivery reports and the existing Google consoles over the agreed 24–48-hour window.
6. If a new build fails, stop new campaign sends, retain delivery history, and restore the previously verified client/backend artifacts together. An older Firebase client may require a deliberate data/write-rule recovery plan after Laravel has accepted newer library writes; do not blindly reopen old Firestore writes or discard newer MySQL data. Restore data only from an approved, reconciled checkpoint.
7. Only after cutover sign-off, archive retired Firebase Auth/Firestore export/hash material and remove development-only rollout flag parsing. Keep both production config providers until a separate, verified config decision retires one.
