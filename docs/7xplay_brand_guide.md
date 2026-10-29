# 7xPlay brand guide

## Identity

- Product name: **7xPlay**
- Descriptor: movies, TV, live channels, and playback across Android phone, tablet, and Android TV.
- Mark: a sharp 7, an interlocking x, and a mint play triangle.
- Keep the product name as “7xPlay” in UI copy and translations.

## Colours

| Token | Hex | Primary use |
|---|---|---|
| Night | `#0B1020` | App icon, launch background, dark surfaces |
| Electric cyan | `#55D6FF` | Primary highlight and 7 mark |
| Soft violet | `#B9A2FF` | Secondary accent and x mark |
| Mint | `#63F2C2` | Play cue and positive accent |
| Cloud | `#F8FAFC` | Wordmark and high-emphasis text |

## Assets

- `assets/images/7xplay_mark.svg`: square mark for app UI and generation.
- `assets/images/7xplay_logo.svg`: horizontal wordmark for README and project pages.
- `android/app/src/main/res/drawable/ic_7xplay_app_icon.xml`: vector Android launcher icon.
- `android/app/src/main/res/drawable/ic_7xplay_tv_banner.xml`: Android TV banner drawable.
- `assets/images/7xplay_splash.png` is generated from the SVG by the Android workflow before native-splash generation; do not commit generated binaries.

## Identity migration boundary

The user-facing name, brand mark, launcher icon, TV banner, launch screen, About page, and localized app copy are rebranded. The internal Dart package import name and Android application ID remain unchanged for compatibility in this pass. The Android ID is tied to the currently bundled Firebase registration (`dev.beamlak.flixquest_v2`) and verified `flix.quest` links. A package migration must be a separate coordinated change with a new Firebase Android app, signing plan, deep-link/assetlinks updates, and a migration plan for existing installs.

The scraper/provider backend remains externally hosted and is not renamed or represented as 7xPlay-owned. The legacy `FLIXQUEST_API_URL` config key remains until the backend and deployment configuration are migrated together.
