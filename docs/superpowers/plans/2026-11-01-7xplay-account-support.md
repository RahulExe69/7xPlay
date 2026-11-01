# 7xPlay Account, Settings and Support Surfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Bring settings, profile/account flows, sync/status/update/about, 7xPlay Plus, wallet, Flix AI and supporting sheets into the same considered 7xPlay mobile design.

**Architecture:** Redesign the presentation layer of existing account, support and commerce flows. Keep authentication, account mutation, billing, sync, server checks, update logic and Flix AI request/controller behaviour unchanged. Use existing form/page patterns where appropriate; split oversized presentation widgets only when there is a concrete reuse or readability benefit.

**Tech Stack:** Flutter 3.35.7, Dart, Provider, easy_localization, existing auth/settings/billing/Flix AI controllers, Flutter widget/unit tests.

**Spec:** docs/superpowers/specs/2026-11-01-7xplay-mobile-redesign-design.md

## Global Constraints
- Target handheld presentation only; do not change lib/tv/**.
- Preserve settings keys/defaults, authentication/session semantics, billing product IDs, payment hand-offs, entitlement decisions, sync logic, status services, update logic and Flix AI request flow.
- Do not change API/backend contracts, account mutation semantics, analytics IDs, or deep-link formats.
- Preserve guest access wherever currently supported and keep destructive account actions explicitly confirmed.
- Preserve Dark, AMOLED, Light, custom/dynamic, seasonal, ambient and Arabic RTL; new translations go in en/es/ar/hi.
- Preserve ad contracts and existing accessibility/tap-target requirements.
- Use .fvm/flutter_sdk/bin/flutter test, .fvm/flutter_sdk/bin/dart format, and .fvm/flutter_sdk/bin/flutter analyze.

## Review Focus
1. Invalid form input: no action fires; the correct field error is accessible.
2. Pending/error account requests: buttons cannot submit twice; safe entered values remain when current flow supports it.
3. Destructive account action: cancellation never mutates the account; confirmation remains explicit.
4. Billing/Plus/payment failures: shown plan price and entitlement remain sourced from controllers, not hard-coded UI.
5. Offline support/status pages: do not fabricate success or current service health.

---

### Task 1: Redesign settings and preference controls

**Files**
- Modify: lib/screens/common/settings.dart, lib/screens/common/language_choose.dart, lib/mobile/widgets/settings_kit.dart.
- Review/modify: lib/mobile/widgets/account_form.dart.
- Test: test/settings_kit_test.dart, test/app_mode_settings_test.dart, test/ambient_theme_test.dart, test/seasonal_component_theme_test.dart.

**Interfaces**
- Consumes SettingsProvider, SettingPreferences, theme/language/default-home/playback preference callbacks and existing settings values.
- Produces an easier-to-scan settings hierarchy with identical persisted keys, defaults, callbacks and routes.

- [ ] Add/extend tests that theme, language, default-home, playback, privacy/ad and other current preferences update the same values. Verify Dark/AMOLED/Light/custom/seasonal/ambient options remain reachable.
- [ ] Run settings-kit and theme preference tests.
- [ ] Group preferences by user task with consistent labels, explanations, value/status affordances and touch targets. Do not change keys, defaults, provider APIs, or remove advanced settings to shorten the page.
- [ ] Add Arabic RTL and text-scale 1.3 assertions. Confirm the screen stays legible immediately after theme changes and does not retain stale palette colours.
- [ ] Run focused tests, format and analyze; commit.

**Task gate:** Every pre-existing setting remains available and persists to the same key/value; theme and settings tests pass.

### Task 2: Redesign profile and authentication screens without changing auth semantics

**Files**
- Modify: lib/screens/common/landing_screen.dart; lib/screens/user/edit_profile.dart, login_screen.dart, signup_screen.dart, forgot_password.dart, email_change.dart, password_change.dart, delete_account.dart.
- Review/modify: lib/mobile/widgets/account_form.dart.
- Test: test/presentation/auth_screens_test.dart, test/auth_navigation_service_test.dart, test/auth_state_router_test.dart, test/data/account_transition_provider_test.dart.

**Interfaces**
- Consumes existing auth/session providers, form validators, account mutation APIs and route callbacks.
- Produces a coherent 7xPlay account presentation preserving every auth transition, validation rule, request and destructive confirmation.

- [ ] Add UI tests for invalid input, pending submission, server error, success, password visibility, guest-to-signed-in transition, email/password change, and delete-account confirm/cancel. Assert invalid input never fires the submit callback.
- [ ] Run auth screen, navigation, router and account-transition tests.
- [ ] Apply common form/profile hierarchy for titles, labels, helper/error copy, password affordances, loading, primary/secondary actions and keyboard-safe spacing. Preserve input names, validators, controller lifetimes and service calls.
- [ ] Verify Delete Account remains explicit and confirmed; ensure supported guest routes remain available. Expose form errors to accessibility semantics.
- [ ] Run auth and translation tests, format and analyze; commit. Do not modify auth repositories or token/session persistence.

**Task gate:** Auth/account transitions and validation are unchanged; destructive actions remain explicitly confirmed.

### Task 3: Redesign sync, server status, update and about screens

**Files**
- Modify: lib/screens/common/sync_screen.dart, server_status_screen.dart, update_screen.dart, about.dart.
- Test: create test/mobile_support_screens_test.dart; run current sync/service/update/connectivity tests associated with touched flows.

**Interfaces**
- Consumes current sync coordinator, status service, update service/version metadata, About content and route callbacks.
- Produces a consistent support/status presentation with truthful idle/loading/success/partial-failure/error states.

- [ ] Add UI state tests for no data, loading, current/success, partial failure, retry and offline using fakes for current services. Assert that UI state text matches actual service state.
- [ ] Run the new support UI tests and existing sync, update, connectivity and server-status service tests discovered in the repository.
- [ ] Show concise current state first, supporting details second, and a valid next action. About surfaces product/version/legal/credits content cleanly. Keep update availability, install/open links and confirmations unchanged.
- [ ] Ensure offline/error state is explicit and retryable. Do not fabricate server health or completion. Confirm Back/deep links remain intact.
- [ ] Format, run focused tests and analyze; commit.

**Task gate:** Support states reflect real service results; sync/update behaviour and routes remain unchanged.

### Task 4: Redesign Plus, payment, wallet and Flix AI surfaces

**Files**
- Modify: lib/mobile/screens/plus_screen.dart, plus_payment_screen.dart, wallet_screen.dart, flix_ai_screen.dart.
- Review/modify only for mobile callers: lib/mobile/widgets/plus_card.dart, plus_sheets.dart, lib/widgets/plus/plus_visuals.dart, plus_format.dart, plus_celebration.dart.
- Test: test/plus_screens_test.dart, test/plus_ad_free_test.dart, test/flix_ai_screen_test.dart and relevant billing/controller tests.

**Interfaces**
- Consumes existing billing/Plus controllers, wallet data, payment navigation and Flix AI controller/repository.
- Produces clear commerce and AI surfaces preserving price values, plan details, payment hand-off, entitlements, credit balance and request states.

- [ ] Add tests that plan prices/benefits come from current data, payment selection sends the same plan/product ID, success/failure/cancel are distinct, ad-free entitlement remains controller-owned, and wallet balance/history are never fabricated.
- [ ] Run Plus, billing and Flix AI tests.
- [ ] Redesign Plus plan comparison, benefits and active entitlement; show wallet balance/history clearly. Do not invent discounts or hide price/cancellation terms.
- [ ] Redesign Flix AI prompt, progress, result and retry states using existing controller/repository. Do not change prompt submission, model routing or credit consumption.
- [ ] Run screen/controller tests, format and analyze; commit.

**Task gate:** Price/plan values, payment IDs, entitlements, wallet data and Flix AI calls are unchanged.

### Task 5: Unify supporting sheets, dialogs and state surfaces

**Files**
- Review/modify: lib/mobile/widgets/account_form.dart, continue_sheet.dart, device_limit_sheet.dart, genre_sheet.dart, title_sheet.dart, plus_sheets.dart, settings_kit.dart.
- Review/modify only where needed: lib/mobile/widgets/skeletons.dart, lib/design/skeleton.dart.
- Test: test/settings_kit_test.dart, test/pill_button_test.dart, test/telegram_channel_prompt_test.dart and owning screen tests.

**Interfaces**
- Consumes the shared mobile primitives and each sheet's existing data/callback contracts.
- Produces consistent, accessible supporting surfaces without changing action or dismissal semantics.

- [ ] Inventory each sheet's entry point, primary/destructive actions, and whether it is called from a detail page, root tab, player boundary or TV-shared caller. Do not apply a handheld-only style to a shared TV widget.
- [ ] Add tests that each sheet calls its existing callback once, supports cancel/back dismissal, requires confirmation for destructive action, and remains scrollable at compact height/text scale 1.3.
- [ ] Apply common typography, surfaces, button hierarchy, spacing and semantic labels selectively. Do not force every sheet into one identical composition.
- [ ] Run each changed sheet's owning-screen tests, translation validation, format and analyze. Confirm TV tests remain unchanged and passing.

**Task gate:** Sheets preserve callback/dismissal semantics, remain usable at compact heights, and do not leak handheld styles into TV.

## Workstream completion gate
- [ ] Settings/profile/auth/support/commerce/Flix AI surfaces have deliberate layouts.
- [ ] Existing values, validators, auth transitions, billing/payment and update semantics remain unchanged.
- [ ] Relevant tests pass and there are no new analyzer issues.
- [ ] Dark, AMOLED, Light, Arabic RTL and compact-height reviews are recorded.
