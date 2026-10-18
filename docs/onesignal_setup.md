# OneSignal setup for FlixQuest

Implementation: Flutter branch `codex/onesignal-messaging` plus the Laravel backend changes in this workspace. No OneSignal app credentials have been configured yet. Complete the steps below before expecting live delivery.

## 1. Create the OneSignal app and connect Android

1. Open the [OneSignal dashboard](https://dashboard.onesignal.com/) and create an app for FlixQuest. Use a separate app for staging when possible.
2. Enable **Google Android (FCM)** and select **Flutter** as the SDK.
3. Use the Firebase project matching the Android build's `google-services.json`. The current prod Android package is `dev.beamlak.flixquest_v2`, with Firebase project `flixquest-ac354`. Keep the existing Google Services file and retained Firebase SDKs.
4. In Firebase Project Settings, confirm **Cloud Messaging API V1** is enabled. Create/download a service-account JSON key, then upload it in OneSignal's Android platform settings. A dedicated account should have Firebase Cloud Messaging API Admin and Firebase Viewer permissions. Keep the JSON private and outside both repositories.
5. Open OneSignal **Settings → Keys & IDs**. Copy the public **App ID** and create/copy the app's **App API/REST API key**. These are different values. The App ID goes in both projects; the REST key goes only in Laravel's environment/secret store.

References: [Android credentials](https://documentation.onesignal.com/docs/en/android-firebase-credentials), [Keys & IDs](https://documentation.onesignal.com/docs/en/keys-and-ids).

## 2. Configure Laravel

In the backend's private `.env` or deployment secret store:

```dotenv
ONESIGNAL_ENABLED=true
ONESIGNAL_APP_ID=YOUR_PUBLIC_APP_UUID
ONESIGNAL_REST_API_KEY=YOUR_PRIVATE_APP_API_KEY
ONESIGNAL_BASE_URL=https://api.onesignal.com
QUEUE_CONNECTION=database
```

Use Redis instead of the database queue if staging already has it. Do not use the synchronous queue for scheduled delivery. Review pending migrations, back up deployed data, then run from the backend directory:

```sh
php artisan migrate --force
php artisan config:cache
php artisan queue:restart
php artisan queue:work --queue=push,default --tries=5 --timeout=30 --sleep=1
```

Keep the worker supervised in deployment. The queue reservation/`retry_after` must exceed 60 seconds; the current default is 90. All workers and web processes must share the same cache/locks. `queue:restart` requires a supervisor to restart stopped workers. Do not leave the worker running only in an interactive terminal on staging/production.

Open Filament **Communications → Push campaigns**. Only active administrators can manage or send campaigns. Do not send a test campaign to “All subscribed devices”; first choose a synthetic/test account.

## 3. Build Flutter with the public App ID

The SDK is already installed; no REST key or service-account JSON belongs in Flutter. From the Flutter repository:

```sh
flutter pub get
flutter run --flavor prod \
  --dart-define=LARAVEL_API_URL=https://YOUR_STAGING_BACKEND \
  --dart-define=ONESIGNAL_APP_ID=YOUR_PUBLIC_APP_UUID
```

For a release APK, use the same defines with `flutter build apk --release --flavor prod`. Changing a compile-time define requires a full restart/rebuild. Hot reload does not activate OneSignal.

Without `ONESIGNAL_APP_ID`, the existing FCM client remains selected. With a valid App ID, OneSignal handles push, and Laravel receives OneSignal **subscription IDs** rather than raw FCM tokens. A native initialization failure allows the app to start with the FCM adapter and retries OneSignal on the next full launch. It does not prove OneSignal is configured.

Allow notification permission using the app's existing prompt/system settings. Device registration waits until OneSignal has an opted-in subscription ID. On sign-in, token/subscription changes, cold boot and resume, the app reconciles registration. Physical Android TV devices get the `flixquest_platform=tv` tag; changing the app's visual layout does not change the physical platform tag.

[Official Flutter setup](https://documentation.onesignal.com/docs/en/flutter-sdk-setup).

## 4. Send individual or bulk messages

| Audience | Behavior |
|---|---|
| Selected Laravel users | Select one user for individual messaging or several for a batch. Targets that account's registered, valid-token subscriptions across devices. Users without eligible subscriptions receive no push. |
| All subscribed devices | OneSignal's `Subscribed Users` segment, including guests. |
| Platform audience | Android phone/tablet, iOS or Android TV, using the SDK's platform tag. This is a public audience filter, not an account permission. |

Create a draft with its content, optional HTTPS image/action link, and display style. Set an optional start (within 28 days) and expiry in the application's timezone. Save, review the audience, then choose **Queue send** and confirm. Content and audience become immutable once queued; make a new draft for a different message.

Foreground campaign pushes retain the native alert. Tapping it loads the message through Laravel and shows the existing in-app dialog/banner/bottom sheet. Background and cold-start taps use the same content path. The message must still be active and the API reachable. Legacy public announcements continue to poll separately. OneSignal's separate in-app-campaign feature is paused to keep one presentation system.

**Delivery details** shows each batch, attempt count, provider ID and safe error. `accepted` means OneSignal created a message; inspect OneSignal reports and the test device to confirm delivery. `no_audience` means no eligible local subscriptions or no provider message ID. `partial` means some batches failed. Retry only failed batches; the original UUID v4 key and payload are reused. Automatic retries handle transient failures, respect rate-limit backoff and stop after five attempts. Manual retries stop after 29 days to stay inside the provider's deduplication period.

Cancel stops unsent queued work and prevents the app opening campaign content. It cannot recall an already accepted OS notification. A worker already contacting the provider may finish its current request.

References: [Create Message](https://documentation.onesignal.com/reference/create-message), [Idempotency](https://documentation.onesignal.com/reference/idempotent-notification-requests).

## 5. Account privacy and lifecycle

Selected-user content lives in a separate Laravel table/API and never appears in `/messages/active`. Its lock-screen push says only “FlixQuest” / “You have a new message. Open FlixQuest to read it.” The private title, body and links stay out of the push payload.

The Flutter SDK used here does not implement verified JWT login, so this integration does not call `OneSignal.login()` or publish Laravel user IDs as aliases. Laravel associates an unguessable subscription UUID with the authenticated account and Sanctum token. Revoking/deleting that token, including successful logout/password change, deletes the association. A new account registration transfers the subscription. Turning off permission removes the current association when the app observes it. API authorization, client session checks and dismissal of open routes on account changes protect content even if a generic notification arrives late or logout happened offline.

Subscription association is not cryptographic proof of device ownership; keep IDs out of public logs. A leaked subscription ID could be rebound by another authenticated installation, so notification delivery must never be treated as account authentication. Actual private content always requires the selected Laravel account.

Dashboard-composed push messages are public device messages; use Laravel campaigns for account-private content. Bulk platform tags can be set by a client and must not protect private content. The legacy Filament **Send FCM push** button is hidden while `ONESIGNAL_ENABLED=true`; do not run a parallel FCM campaign for the same rollout. Older FCM-only installations need their own deliberate audience plan until upgraded.

[Identity verification support](https://documentation.onesignal.com/docs/en/identity-verification).

## 6. Verify before rollout

1. Install the staging build on an Android phone and Android TV device/emulator with Google Play services. Open it online and grant permission. Confirm each subscription appears as subscribed in the intended OneSignal app and has the right platform tag.
2. Sign into a test Laravel account on both devices; confirm two subscription records are associated with its valid tokens. Send an individual campaign. Check generic lock-screen text, foreground alert, background tap and cold-start tap; content should open once per account/installation.
3. Sign into a different account before tapping an old private notification. Its content must not open. Test logout, opt-out, disabled accounts and account deletion as well.
4. Create a small test cohort in a dedicated staging OneSignal app. Exercise selected-user bulk delivery, platform targeting, scheduling, expiry, provider reports, retries and cancellation. Guests receive public bulk pushes but cannot fetch private content.
5. Keep Laravel's runtime `config_source=firebase` for the current rollout. Verify Firebase Remote Config, Crashlytics and Analytics on phone/TV; OneSignal still uses FCM for Android transport.
6. Run the automated checks and F8 preflight in [the F8 playbook](f8_staging_playbook.md). Actual cloud delivery, Google console ingestion and MySQL staging parity remain separate gates.

This checkout has no iOS target. The Dart adapter recognizes iOS, but APNs credentials, native capabilities/notification extension, pods and physical-device verification must be completed in the actual iOS project using the official setup guide before claiming iOS support.

## Troubleshooting and rollback

- No subscription: verify App ID, matching Firebase project, permission, Google Play services and network access. App ID and REST key must belong to the same OneSignal app.
- Campaign stays queued: verify the worker consumes `push`, the start time has arrived, configuration was cached after setting secrets and workers were restarted.
- HTTP 401/403: check/rotate the app REST key in the backend, refresh config and restart workers. Do not paste keys into chat or logs.
- `no_audience`: open the app while signed in, grant permission, check subscription registration/token expiry, then inspect OneSignal subscription status. Reusing an accepted campaign does not create a second delivery; create a new draft for a new campaign.
- No private dialog after a tap: verify the current account, expiry and Laravel connectivity. Private content is not cached; an offline/unauthorized fetch does not mark the message shown.
- Revert delivery by disabling new sends, cancelling pending campaigns and rebuilding Flutter without `ONESIGNAL_APP_ID`. Setting only `ONESIGNAL_ENABLED=false` on the backend does not change already-built clients. Keep the new tables/history; do not drop them as a rollback. Existing accepted notifications cannot be recalled.
