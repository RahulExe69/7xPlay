# Android APK build

The GitHub Actions workflow at `.github/workflows/build-android.yml` builds optimized **release APKs split by CPU architecture** for pull requests targeting `main`, pushes to `main`, and manual workflow runs.

## Download the right APK

1. Open the repository's **Actions** tab.
2. Open the successful **Build optimized Android APKs** run for the commit or pull request.
3. Download the artifact matching the device:
   - `7xPlay-arm64-v8a-release-<commit-sha>` — recommended for most modern Android phones and Android TV devices.
   - `7xPlay-armeabi-v7a-release-<commit-sha>` — older 32-bit ARM devices.
   - `7xPlay-x86_64-release-<commit-sha>` — x86_64 emulators and compatible Intel devices.
4. Extract the ZIP, then install the APK inside it. Do not install one of the other ABI variants just because its filename looks shorter.

## Size optimizations

- A **release** build, not a debug build.
- `--split-per-abi` packages only the native Flutter engine for each CPU architecture instead of combining all supported ABIs into one file.
- Android R8 minification and resource shrinking are enabled in the release build.
- `--tree-shake-icons` excludes unused icon glyphs.
- `--obfuscate --split-debug-info=build/symbols` obfuscates Dart symbols and stores symbol maps separately from the APK.
- CI prints the exact size of each generated APK in the build log. Use those measurements before making further dependency cuts.

The output is intentionally **not a universal APK**. The per-device files should be substantially smaller than the previous universal debug build. The app still includes Flutter, Firebase, video-player/Media3, download, and other functionality; reducing the APK further would require measured, feature-by-feature dependency analysis and tests.

## Signing

CI reads these optional repository secrets to sign with a stable distribution key:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded Android keystore.
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

Without all the signing values, CI falls back to the runner's debug signing key so the artifacts remain installable for testing. **Do not publish that fallback build as an official update**, because the runner key is not a stable production signing identity. Existing installs can upgrade only when signatures and versioning are compatible.

## Build environment

The workflow checks out the required external `flixquest-betterplayer` path dependency at `claude/relaxed-dirac-tw37rj`, which includes the configured hold-speed gesture options. It uses Java 17 and Flutter 3.41.5; newer Flutter versions currently hit an `IconData` compatibility issue with `phosphor_flutter` 2.1.0. CI copies `.env.example` to `.env`, rasterizes the SVG splash source, generates native splash assets, runs `flutter test test/provider_loader_test.dart`, and then builds the APKs.

## Publishing for the in-app updater

GitHub Actions artifacts are temporary downloads for build/test use, not permanent direct-download URLs. For public updates, publish the correct per-ABI APKs to a stable GitHub Release or another controlled HTTPS host, then set Remote Config's `app_download_url_arm64_v8a`, `app_download_url_armeabi_v7a`, and `app_download_url_x86_64` keys to the matching APK URLs. Keep `app_download_url` as the universal fallback URL only if a universal APK is deliberately built and hosted. Do not point those fields at an artifact ZIP; the updater expects an APK.
