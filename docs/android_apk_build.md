# Android APK build

The GitHub Actions workflow at `.github/workflows/build-android.yml` builds optimized, installable **release APKs split by CPU architecture** for pushes to `main`, pull requests targeting `main`, and manual workflow runs.

## Download the smallest APK for your device

1. Open the repository's **Actions** tab.
2. Open the successful **Build Android APKs** run for the desired commit.
3. In **Artifacts**, download `7xPlay-release-split-apks-<commit-sha>`.
4. Extract the ZIP and install only one APK:
   - `app-prod-arm64-v8a-release.apk` — most modern Android phones; choose this first for most current devices.
   - `app-prod-armeabi-v7a-release.apk` — older 32-bit ARM phones.
   - `app-prod-x86_64-release.apk` — x86-64 Android devices/emulators.
5. Do not install multiple ABI APKs over one another. Choose the one matching the device CPU.

Each APK contains native libraries for only one ABI instead of bundling all CPU architectures in one universal APK. The release build also enables R8 code shrinking, resource shrinking, Flutter icon tree-shaking, and Dart obfuscation. Split Dart symbol files are archived separately for crash diagnosis.

## Build and signing notes

The workflow checks out the required `flixquest-betterplayer` path dependency at `claude/relaxed-dirac-tw37rj`, sets up Java 17 and Flutter 3.41.5, runs `flutter test test/provider_loader_test.dart`, and copies `.env.example` to `.env`. It uses `--android-skip-build-dependency-validation` because the Android project currently uses Gradle 8.7.

If `android/key.properties` and its referenced keystore are present, Gradle uses that release key. Otherwise, CI falls back to the local debug key so the optimized APK can be installed for testing. **Never publish a debug-key-signed APK as an official store release.** Configure a protected production keystore before publishing. Signing keys and passwords must never be committed.

The Android application ID is intentionally unchanged for now to preserve the existing Firebase registration and allow compatible upgrades from existing installations. The launcher label and visual brand are 7xPlay. Changing the application ID later would create a separate Android app identity and may prevent in-place upgrades.

APK size depends on the app's Flutter engine, video playback libraries, Firebase integrations, and native dependencies. ABI splitting removes the largest avoidable duplication for direct APK downloads; removing more dependencies requires usage audits and regression tests rather than blindly deleting features.
