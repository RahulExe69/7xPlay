<p align="center">
  <img alt="7xPlay" src="assets/images/7xplay_logo.svg" width="180">
</p>

<h1 align="center">7xPlay</h1>

<p align="center">
  <strong>A modern, open-source streaming application for Movies, TV Shows, and Live TV built with Flutter.</strong><br>
  Optimized for <strong>Android Mobile, Tablets</strong>, and <strong>Android TV (10-Foot UI)</strong>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Android%20TV-3DDC84?logo=android&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Version-4.3.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green" alt="License">
</p>

---

## ✨ Features

### 🎬 Extensive Movie & TV Show Catalog

- **Discovery Feeds**: Categorized home feeds with shimmer loading effects — Trending, Top 10 This Week, New Releases, Upcoming, and Popular.
- **Detailed Media Pages**: Media details featuring trailers, cast & crew filmographies, user reviews, and intelligent "More Like This" recommendations powered by TMDB.
- **Explore & Filter**: Filter content by genre, release year, streaming provider, country, or sort order, alongside a random discovery tool.
- **TV Seasons & Episodes**: Interactive episode browser with episode thumbnails, descriptions, air dates, and quick episode switcher sheets.

### 📺 Android TV (10-Foot UI Experience)

- **D-Pad Focus Navigation**: Native TV remote control navigation with directional keymaps and focus memory.
- **TV Home Shell & Rail**: TV navigation rail, catalog screens, and hero banners designed specifically for large screens.
- **TV Search & History**: Remote-friendly search interface with recent search query history.
- **Automatic Presentation Detection**: Automatically detects TV devices and adapts the interface between mobile touch and TV 10-foot layout.

### 📡 Free Live TV & Sports Streaming

- **Live TV Integration**: Integrated DaddyLive service providing 24/7 TV channels and scheduled live sports events.
- **Category Browsing & Search**: Search channels by name, filter by category, and view local time-formatted schedules.
- **Stream Recovery & Buffering**: Smart playback recovery (90-second window), auto-reconnect, and optimized live buffering.
- **Local Caching**: Fast SQLite caching for live channels and event schedules.

### 🚀 Multi-Source Video Providers & Scraper API v2

- **Dynamic Provider System**: Integrated with a separately hosted scraper/provider API for resolving high-quality streams.
- **Live Provider Health Status**: Real-time provider uptime monitoring (`/providers/status`) with in-app status indicators.
- **Direct Fallback Provider**: Built-in direct VixSrc provider fallback.
- **Custom Provider Prioritization**: Reorder and prioritize your preferred streaming providers in Settings.
- **Stream Formats**: Full support for HLS (.m3u8), DASH (.mpd), and direct MP4 streams with custom header support.

### 💬 Comprehensive Subtitle Management

- **Automatic External Subtitles**: Multi-language subtitle search and retrieval powered by Wyzie Subtitles API.
- **Local Subtitle Upload**: Pick and load local `.srt` or `.vtt` subtitle files directly from your device storage.
- **Subtitle Customization**: Adjust font size, text color, background color, and visual styling presets.
- **Encoding & HI Support**: Smart character encoding handling (UTF-8, Latin1, ASCII) and Hearing-Impaired (HI) tags.

### 📥 Offline Downloads

- **Background Downloads**: Download movies and TV episodes with background download management and progress notifications.
- **Aspect Ratio Normalization**: Built-in video exporter with square-pixel aspect ratio normalization.
- **Subtitle Bundling**: Automatically export and bundle subtitles with downloaded videos for offline viewing.
- **Offline Player**: Dedicated offline library and media player for downloaded files.

### 🎨 Modern UI, Ambient Glow & Seasonal Themes

- **Phosphor Icons**: Clean, consistent icon set using Phosphor Flutter icons across the entire app.
- **Ambient Mode**: Dynamic color palette extraction from movie/show posters and backdrops for an immersive ambient background glow.
- **Occasional & Seasonal Themes**: Dynamic holiday themes (Christmas, New Year, Halloween, Valentine's Day, Easter, Eid, Diwali, Ethiopian New Year, etc.) with animated vector particle overlays (snow, fireworks, bats, hearts, adey flowers, confetti, stars, sparkles). Configurable via Firebase Remote Config.
- **Themes**: Light, Dark, AMOLED Pure Black, and Material 3 Dynamic Color palettes.

### Advertising

- Centrally configured Adsterra WebView banners replace Start.io across existing phone, tablet, and Android TV slots.
- Firebase Remote Config controls network/TV switches, banner codes, six supported sizes, and per-placement overrides with width fallbacks.
- Hosted `/ads` announcements can stack above network banners or take priority. TV ads remain display-only.
- Setup: [Remote Config advertising guide](docs/firebase_remote_config.md#activate-adsterra-banners) and [configured banner catalog](docs/adsterra_banners.json), with a [blank template](docs/adsterra_banners.example.json) for other accounts.

### 🔐 User Profiles & Cloud Synchronization

- **Firebase Authentication**: User accounts with email/password authentication, profile management, and account deletion.
- **Cross-Device Bookmark Sync**: Dual-layer bookmark synchronization between local SQLite and Cloud Firestore.
- **Recently Watched & Resume**: Track watch progress across movies and episodes with quick resume playback.

### 🌍 Multi-Language Localization

- Complete internationalization powered by `easy_localization` supporting multiple languages including English, Spanish, Arabic, Hindi, and more.

---

## 📱 Screenshots

Fresh mobile, tablet, player, and Android TV screenshots will be added after the 7xPlay-branded build has been visually checked on-device. The previous upstream screenshots are intentionally not shown here so the repository does not advertise the old app identity.

---

---

## ⚙️ Environment Variables & API Keys

7xPlay uses `flutter_dotenv` to load environment variables. Create a `.env` file in the root directory of the project:

```env
# Required: TMDB API Key for movie and TV show metadata
TMDB_API_KEY="your_tmdb_api_key"

# Required: URL of the separately hosted provider scraper API
FLIXQUEST_API_URL="https://your-provider-api-instance.com"

# Optional: Mixpanel project token for general analytics
MIXPANEL_API_KEY="your_mixpanel_api_key"
```

### Obtaining API Keys

- **TMDB API Key**: Register at [The Movie Database (TMDB)](https://developer.themoviedb.org/v3/reference/intro/authentication#api-key-quick-start) to get your free API key.
- **7xPlay Scraper API**: The provider scraper is a separately hosted upstream service. Its base URL remains configurable through the legacy `FLIXQUEST_API_URL` environment variable for backward compatibility; the 7xPlay client does not include that backend.
- **Mixpanel Token** _(Optional)_: Create a free account at [Mixpanel](https://mixpanel.com).

---

## 🕷️ External scraper API integration

The app can use a separately hosted scraper/provider API to resolve streams. The backend is not included in this repository and is not represented as a 7xPlay-owned service. Configure its URL using the existing `FLIXQUEST_API_URL` environment variable; that legacy key is retained for compatibility until the backend and any deployed configuration are migrated together.

The client-side API contract and payload schemas are documented in [`openapi.json`](openapi.json).

Key endpoints consumed by the app:

- `GET /providers`: discovers available and enabled video providers.
- `GET /providers/status`: fetches provider health, latency, and uptime.
- `GET /stream-movie`: resolves movie streams using a TMDB ID.
- `GET /stream-tv`: resolves TV episode streams using a TMDB ID, season, and episode number.
- `GET /subtitles/search`: searches subtitle providers and combines results.
- `GET /subtitles/{provider}/{id}`: retrieves a subtitle file through the configured API.
- `POST /stream-size`: estimates the byte size behind a stream token.
- `GET /api/v2/intro`: retrieves the configured intro-video settings.

---

---

## 🔥 Firebase Configuration

7xPlay uses Firebase for several services:

| Service                       | Purpose                                                                                                                                                                                                                             |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Firebase Authentication**   | User authentication, profile management, and session handling.                                                                                                                                                                      |
| **Cloud Firestore**           | Cloud bookmark synchronization across multiple devices.                                                                                                                                                                             |
| **Firebase Remote Config**    | Dynamic configuration for feature toggles (Watch now, Download, Live TV), app logos, seasonal themes, and vector animation effects. See [`docs/firebase_remote_config.md`](docs/firebase_remote_config.md) for full schema details. |
| **Firebase Cloud Messaging**  | Background notifications and alerts.                                                                                                                                                                                                |
| **Firebase In-App Messaging** | Dynamic in-app banners and update notices.                                                                                                                                                                                          |
| **Firebase Analytics**        | Usage and performance analytics.                                                                                                                                                                                                    |

> **Note**: To connect to your own Firebase project, place your `google-services.json` inside `android/app/`.

---

## ▶️ Custom `better_player` Package

This repository uses the customized `better_player_plus` package from the upstream dependency repository [BeamlakAschalew/flixquest-betterplayer](https://github.com/BeamlakAschalew/flixquest-betterplayer). Its upstream repository name is retained here as a dependency reference.

You can configure it in `pubspec.yaml` using a local path or git URL:

```yaml
better_player_plus:
  git:
    url: https://github.com/BeamlakAschalew/flixquest-betterplayer.git
```

Or reference a local sibling directory:

```yaml
better_player_plus:
  path: ../flixquest-betterplayer
```

---

## 🛠️ Getting Started & Build Instructions

### Prerequisites

- **Flutter SDK**: `>=3.0.0 <4.0.0`
- **Dart SDK**: `^3.0.0`
- **Android SDK / NDK**: Android SDK 34+, Java 17

### Installation Steps

1. **Clone the repository**:

   ```bash
   git clone https://github.com/RahulExe69/7xPlay.git
   cd 7xPlay
   ```

2. **Clone the custom better_player repository** (if using local path):

   ```bash
   cd ..
   git clone https://github.com/RahulExe69/7xPlay-betterplayer.git
   cd 7xPlay
   ```

3. **Configure Environment Variables**:
   Create a `.env` file in the project root:

   ```bash
   cp .env.example .env # or create a new .env file with your keys
   ```

4. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

5. **Run the Application**:
   - For Android Mobile / Tablet:

     ```bash
     flutter run
     ```

   - For Android TV (Emulator or connected TV device):

     ```bash
     flutter run -d <tv-device-id>
     ```

   The app detects TV or mobile mode automatically by default. If a custom ROM
   reports the wrong device type, choose **Settings → Appearance → App mode →
   TV** or **Mobile**. The interface switches immediately and the choice is saved
   across launches. Choose **Automatic** to return to device detection.

   Android has two flavors: `prod` (the default) and `dev`. To test real banner
   ads using Firebase's `banner_ad_network_test` selector, run the dev flavor:

   ```bash
   flutter run --flavor dev
   flutter run --flavor dev --release
   ```

   The test selector works in dev debug/profile/release builds. Prod ignores it
   in every build mode. See [banner testing setup](docs/firebase_remote_config.md#test-real-banners-in-development).
   Both flavors reuse the existing Android package and Firebase registration;
   they share an install slot. The dev launcher label is **7xPlay Dev**.

6. **Build Release APK**:

   ```bash
   flutter build apk --release
   ```

   This uses the default `prod` flavor and outputs
   `build/app/outputs/flutter-apk/app-prod-release.apk`. You can also specify
   `--flavor prod` explicitly. A development release APK is built with
   `flutter build apk --flavor dev --release`.

   For smaller per-device downloads, also build split APKs:

   ```bash
   flutter build apk --release --split-per-abi
   ```

   The update screen downloads the APK matching the device's CPU. Publish each
   split APK's link in Remote Config under `app_download_url_arm64_v8a`,
   `app_download_url_armeabi_v7a` and `app_download_url_x86_64`, and keep the
   universal APK in `app_download_url`. A device whose ABI can't be read, or
   whose key is empty, downloads the universal APK.

---

## 🤝 Contributing

Contributions, feature suggestions, design ideas, and translations are always welcome!

- **Pull Requests**: Please ensure your code passes static analysis and is properly formatted:

  ```bash
  dart format .
  flutter test
  ```

- **Issue Reports**: Please follow the provided issue templates when opening bugs or feature requests.

---

## ⚠️ Disclaimer

- The developers of this application have no affiliation with content providers like TMDB, DaddyLive, or any third-party streaming websites.
- 7xPlay **does not host or upload any video content**. All media is retrieved via public scrapers and third-party APIs.
- In case of copyright infringement, please contact the responsible hosting services or source providers directly.

---

### 🙏 Credits & Integrations

- **TMDB API**: Media metadata, cast, crew, and artwork.
- **Phosphor Icons**: Beautiful, consistent icon pack (`phosphor_flutter`).
- **Matinee Flutter**: Initial UI inspiration and base architecture (`bimsina/Matinee-Flutter`).

---

<p align="center">
  <i>GNU, but for Entertainment</i><br><br>
  <strong>7xPlay is a rebranded open-source client; retain the original licence and upstream notices in LICENSE.</strong>
</p>
