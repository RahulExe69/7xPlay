# Android APK build

The GitHub Actions workflow at `.github/workflows/build-android.yml` builds an installable **debug APK** for pushes to `main`, pull requests targeting `main`, and manual workflow runs.

## Download the APK

1. Open the repository's **Actions** tab.
2. Open the successful **Build Android APK** run for the desired commit or pull request.
3. In **Artifacts**, download `7xPlay-debug-apk-<commit-sha>`.
4. Extract the ZIP to get `app-prod-debug.apk`, then install it on an Android device.

The workflow checks out the required `flixquest-betterplayer` path dependency beside the app repository, sets up Java 17 and stable Flutter, resolves packages, and builds the `prod` flavor. It uses Flutter's `--android-skip-build-dependency-validation` option because the current Android project uses Gradle 8.7 while newer stable Flutter releases demand Gradle 8.14; the Android Gradle Plugin remains pinned to the project's existing version.

This is a debug-signed testing APK, not a production release. A release build should only be published after the app's environment configuration, signing key, and playback/authentication flows have been validated.
