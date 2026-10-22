# Do not disturb while streaming

Player settings offers an opt-in switch on Android phones/tablets running
Android 10 (API 29) or later. It applies to `PlayerOne` and `LivePlayer`,
including portrait playback and their full-screen routes. It is off by default.
Android TV and other platforms do not expose the switch.

The first enable opens an explanation, then Android's Do Not Disturb access
settings. The preference is enabled only after the user returns with access
granted. Declining access leaves it off. Revoked access never prevents playback.

Each mobile player acquires a session ID. While at least one enabled session
exists and MainActivity is resumed, a dedicated "FlixQuest streaming" automatic
zen rule suppresses notification sounds, call/repeat-caller notifications,
heads-up banners, and notification full-screen intents. Media and alarms are
allowed by this rule. Existing user modes can impose stricter restrictions.

The rule becomes inactive when the last session closes, the switch is disabled,
the activity pauses (including leaving for picture-in-picture), or the Flutter
engine is cleaned up. Returning to the foreground reactivates it only if a
player session still exists. Overlapping player replacements release their
own session IDs independently. Global DND settings and other rules are never
rewritten; this also follows the Android 15+ app-owned rule model.

The rule ID is retained for reuse. Activity initialization releases a leftover
rule after a process restart. The condition provider reports the process-local
session state when Android reconnects or subscribes, defaulting to inactive in
a fresh process. No notification contents or call records are accessed.

This uses system DND, not call rejection or control of other apps' activities.
Emergency alerts, OEM exceptions, and independent calling-app screens can
still interrupt. Physical-device verification should include an incoming phone
call and a VoIP call on each supported device family.

Manual verification:

1. Grant access from the switch; confirm decline/cancel leaves it off.
2. Open each mobile player and trigger an ordinary notification and phone call.
   Check media remains audible and banners are suppressed.
3. Exit playback, press Home, enter PiP, and return. Check the streaming rule's
   state follows foreground player ownership.
4. Start with an existing DND mode, enter and leave playback, and verify that
   mode and any changes made to it during playback are preserved.
5. Revoke access or remove/disable the app's rule in Android settings. Verify
   playback and navigation remain usable; disabled rules respect system control.

Automated tests cover permission UI, preference persistence, player session
overlap, and native policy/lifecycle behavior on API 29 and 35 (plus an API 28
unsupported-device check). Robolectric records condition-update calls; it does
not simulate real incoming call UIs or OEM notification behavior.
