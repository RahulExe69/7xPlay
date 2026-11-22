<p align="center">
  <img src="assets/images/7xplay_wordmark.png" alt="7xPlay" width="280">
</p>

<h1 align="center">7xPlay</h1>

<p align="center">
  <strong>Movies, series and live entertainment — with a familiar video-app feel and the streaming DNA of FlixQuest.</strong><br>
  Built with Flutter for Android phones, tablets and Android TV.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.50.0-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Android-Mobile%20%7C%20TV-3DDC84?logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Version-4.3.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-green" alt="GPL-3.0">
</p>

---

## About

**7xPlay** is the 7x-branded evolution of the FlixQuest-based streaming app. It brings together a familiar, feed-first browsing experience and the movie, series, episode, provider and playback workflows that make an OTT app useful.

The interface takes inspiration from the clarity and navigation patterns of modern video platforms without turning the product into a YouTube clone. Movies and series remain the centre of the experience: browse poster shelves, explore collections, open cinematic title pages, choose seasons and episodes, select a provider, and watch.

The application is developed in this repository. **The upstream FlixQuest scraper/API service is not developed or hosted by this project**; 7xPlay continues to use the existing FlixQuest service and its established endpoints.

## Highlights

### Browse and discover
- A redesigned Home experience with Trending, New Movies, New Series, Continue Watching and curated catalogue shelves.
- Consistent horizontal poster rows for catalogue sections.
- Explore, New & Hot, Search and My 7xPlay destinations.
- Search results with richer video-style cards, title metadata and quick actions.
- Movie and series details, recommendations, seasons, episodes and episode information.

### Watch
- Multiple streaming providers with provider prioritisation and fallback handling.
- HLS, DASH and direct video playback through the existing player integration.
- Audio and subtitle selection, playback recovery and resume progress.
- Download management and an offline library.
- Live TV browsing and playback where an upstream source is available.

### Mobile, tablet and TV
- Touch-first Android phone and tablet layouts.
- Android TV presentation with remote/D-pad navigation and focus handling.
- Responsive navigation and restored navigation state.
- Light and dark appearance options, including the app's dark cinematic styling.

### 7x identity
- 7xPlay product wordmark and product artwork.
- Shared 7x monochrome mark sourced from the [7x Brand Hub](https://github.com/RahulExe69/7x).
- Product-specific visual styling, separate from the launcher artwork.

## Upstream services and API ownership

7xPlay does **not** claim ownership of the FlixQuest scraper API and does not provide a replacement scraper API in this repository. The existing upstream service remains the default for provider discovery and stream resolution.

| Service | Used for | Source |
|---|---|---|
| FlixQuest Scraper API v2 | Provider discovery, stream resolution and supported subtitle/stream helper endpoints | [scraper.flix.quest](https://scraper.flix.quest) |
| FlixQuest API specification | Existing client-side request and response contract | [OpenAPI specification in this repository](openapi.json) |
| FlixQuest BetterPlayer fork | Existing Flutter video-player integration | [flixquest-betterplayer](https://github.com/BeamlakAschalew/flixquest-betterplayer) |
| TMDB | Movie and TV metadata, artwork and related catalogue information | [TMDB API documentation](https://developer.themoviedb.org/docs) |

The scraper API is maintained separately by its upstream provider. Availability, provider catalogue, stream resolution and API behaviour therefore depend on that service and its providers. Do not interpret the 7xPlay app repository as an API deployment or API support endpoint.

### Existing FlixQuest scraper routes

The app's current integration includes the established FlixQuest API routes for:
- `GET /providers` — provider discovery.
- `GET /providers/status` — provider status information.
- `GET /stream-movie` — movie stream discovery.
- `GET /stream-tv` — episode stream discovery.
- `GET /subtitles/search` — subtitle search.
- `GET /subtitles/{provider}/{id}` — subtitle retrieval.
- `POST /stream-size` — stream-size estimation.
- `GET /api/v2/intro` — intro configuration.

These are upstream FlixQuest API routes, not endpoints implemented by 7xPlay. Refer to the upstream service and the checked-in [OpenAPI document](openapi.json) for the contract used by this client.

## Configuration

The app reads local configuration from ` .env ` through `flutter_dotenv`. Start with the example file:

```bash
cp .env.example .env
```

At minimum, configure the TMDB key used by your build:

```env
TMDB_API_KEY=your_tmdb_api_key
FLIXQUEST_API_URL=https://scraper.flix.quest
```

The example file also documents optional integrations and existing configuration keys, including subtitle/provider URLs, analytics, the configurable Laravel backend URL and notification settings. Leave unused optional values empty. Never commit private credentials, signing keys or service secrets.

### API and backend notes

- `FLIXQUEST_API_URL` defaults to the original FlixQuest scraper host, `https://scraper.flix.quest`.
- `FLIXHQ_NEW_URL`, `FLIXAPI_URL` and `CONSUMET_URL` are existing optional provider/service configuration values in `.env.example`.
- `LARAVEL_API_URL` is an existing configurable backend base URL used by the app's backend integration. Its default emulator address is for local development; configure a reachable instance when that integration is required.
- Firebase Remote Config can supply runtime configuration used by existing app features. Firebase configuration and optional service integrations are separate from the FlixQuest scraper API.

For the exact current variable list, see [`.env.example`](.env.example). For the existing Remote Config contract, see [Firebase Remote Config documentation](docs/firebase_remote_config.md).

## Development setup

### Requirements

- Flutter SDK compatible with the project's Dart constraints. The CI workflow currently uses Flutter **3.50.0**.
- Android SDK with **API 36** available.
- Java **17**.
- Android Studio or another Flutter-compatible editor.
- Access to the existing FlixQuest BetterPlayer dependency and the upstream services required by the feature being tested.

The Android build currently uses Gradle **9.9.2**, Android Gradle Plugin **9.3.1** and Kotlin Gradle Plugin **2.4.20**.

### Get the source

```bash
git clone https://github.com/RahulExe69/7xPlay.git
cd 7xPlay
```

The app uses the FlixQuest BetterPlayer fork as a local sibling dependency in the development setup. Clone it beside the app repository:

```bash
cd ..
git clone https://github.com/BeamlakAschalew/flixquest-betterplayer.git
cd 7xPlay
```

Create and configure `.env`, then resolve packages:

```bash
cp .env.example .env
flutter pub get
```

Run on a connected Android phone:

```bash
flutter run --flavor prod
```

Run on an Android TV device or emulator:

```bash
flutter run --flavor prod -d <tv-device-id>
```

### Build APKs

Universal production APK:

```bash
flutter build apk --release --flavor prod
```

Smaller per-architecture APKs:

```bash
flutter build apk --release --flavor prod --split-per-abi
```

For an ARM64-only release build:

```bash
flutter build apk --release --flavor prod --target-platform android-arm64
```

The CI workflow also creates an optimized ARM64 release preview for pull requests. Release builds and debug builds are not directly comparable in file size: debug APKs include development/runtime overhead that is removed or reduced by release optimizations.

## Project structure

- `lib/` — Flutter application, screens, navigation, state and service integrations.
- `assets/` — images, translations, fonts and bundled resources.
- `android/` — Android application, flavors and platform configuration.
- `docs/` — implementation notes, configuration references and screenshots.
- `test/` — automated Flutter tests.
- `openapi.json` — checked-in contract reference for the upstream FlixQuest scraper API.

## Testing and quality

Run the automated Flutter tests:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

Format Dart code before submitting changes:

```bash
dart format .
```

Pull requests should describe user-visible changes, note any upstream API assumptions, and include test/build results. Do not claim that a physical device has been tested unless it has actually been tested.

## Screenshots

The repository includes screenshots of the current catalogue and playback flows:

| Home | Movie details | Series details |
|---|---|---|
| ![Home](docs/screenshots/movies-home.jpg) | ![Movie details](docs/screenshots/movie-detail.jpg) | ![Series details](docs/screenshots/series-detail.jpg) |

| Episodes | Downloads | Player |
|---|---|---|
| ![Episodes](docs/screenshots/episodes.jpg) | ![Downloads](docs/screenshots/downloads.jpg) | ![Player](docs/screenshots/player.jpg) |

## Credits and acknowledgements

- **FlixQuest** — upstream foundation, scraper API and related streaming integrations.
- **FlixQuest BetterPlayer** — video-player integration.
- **TMDB** — movie and television metadata and artwork.
- **7x Brand Hub** — shared 7x brand identity and official product assets.
- **Flutter and Dart** — application framework and language.
- **Phosphor Icons** — application icon set.

## Disclaimer

7xPlay does not host, upload or store the movies, series, channels or streams surfaced by third-party providers. Metadata, artwork, provider discovery and stream availability are supplied by their respective services. Users are responsible for complying with the laws and terms applicable in their region.

7xPlay is an independent project and is not affiliated with, endorsed by or operated by TMDB, FlixQuest or any streaming service mentioned above.

## License

This project is distributed under the [GNU General Public License v3.0](LICENSE).
