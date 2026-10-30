# Bengali / Bangla provider audit

**Audit date:** 31 October 2026  
**Scope:** Identify Bengali-language movie and TV sources that can be integrated into 7xPlay through a documented, authorised playback API or an independently verified, redistributable media catalogue.

## Decision

**No new streaming provider is approved for integration yet.** The live scraper catalogue currently advertises 13 enabled providers, but none explicitly claims Bengali/Bangla audio coverage. The VidUp description labels Indian/Bollywood audio as unknown; that is not sufficient evidence of Bengali audio.

This is an intentional no-go, not an implementation omission. A provider must pass both the access/rights check and the playback verification check before it is added.

## Existing 7xPlay integration points

- `lib/video_providers/names.dart` supports direct providers and providers advertised by the scraper API.
- `lib/video_providers/scraper_api.dart` fetches the API's provider catalogue and parses stream audio labels from `audioLanguage`, `audio_language`, `language`, `lang`, and `hlsAudioLanguage`.
- `lib/video_providers/provider_loader.dart` already loads providers concurrently, exposes the first playable result early, expands the source list, and preserves audio-language metadata when combining sources.

The current gap is therefore upstream provider coverage and trustworthy language labelling, not a missing Flutter provider-selection control. The app can only display Bengali reliably when the source API supplies correct audio-track metadata or the stream is independently inspected.

## Candidate results

| Candidate | What was verified | Status |
| --- | --- | --- |
| **Hoichoi** | Official service is Bengali-first. Its public Partner API documentation describes partner onboarding, subscription creation/update/deletion and entitlement/status operations. Access requires an allowlisted IP range and a partner API key. The public document does not specify a movie/episode playback URL or a third-party player SDK. | **Partner enquiry only.** Ask for a content-distribution agreement and playback/DRM integration documentation. Do not treat the subscription API as a playback API. |
| **KLiKK** | Official service offers Bengali movies and series. Its published terms restrict copying/capturing content and unauthorised automated access/indexing. No public playback API contract was found. | **Do not scrape.** Written permission and a documented partner playback interface are prerequisites. |
| **Addatimes** | Official Bengali VOD service and terms describe subscriber access to content. A secondary technical case study is not an official developer contract. No public playback API contract was verified. | **Partner enquiry only.** Request current API/SDK docs and rights scope. |
| **Chorki** | Official service offers Bangla originals and dubbed content. Its terms restrict automated collection/scraping and unauthorised access or third-party playback. No public playback API contract was verified. | **Do not scrape or proxy.** Written authorisation and an official integration path are prerequisites. |
| **Bongo** | Official Bangla VOD service. Searches did not identify an official public developer/playback API contract. Third-party API listings are not proof of authorisation. | **Unverified.** Partner enquiry only. |
| **WAVES / Prasar Bharati** | Official public-service OTT platform carries Doordarshan and archival programming; DD Bangla is among the regional channels. No public third-party playback API/feed contract was found. Linear TV also needs a distinct integration surface rather than pretending it is a TMDB movie/episode provider. | **Potential authorised partnership.** Ask for a documented channel feed, VOD API or approved deep-link/embed arrangement. |
| **Wikimedia Commons / Indiancine.ma** | A Commons file page documents *Shesh Uttar* (1942) as a Bengali film and exposes a WebM media file. Its page describes public-domain status in India, but the underlying rights need jurisdiction-by-jurisdiction review; the page also warns that its Indiancine.ma metadata licence does not determine the film's copyright status. Indiancine.ma states that its archive is for non-commercial research, criticism, education and allied uses. | **Not approved for app playback.** Do not bulk-ingest from the archive. Revisit only after confirming the actual film rights, territory, licence, attribution obligations, and permitted use in 7xPlay. |

### Official references

- Hoichoi: https://hoichoi.tv/about-us
- Hoichoi Partner API documentation: https://github.com/hoichoitech/PartnerAPI
- KLiKK: https://www.klikk.tv/
- KLiKK terms: https://klikk.tv/terms.html
- Addatimes: https://www.addatimes.com/
- Addatimes terms: https://www.addatimes.com/terms
- Chorki: https://www.chorki.com/
- Chorki terms: https://www.chorki.com/terms-of-use
- Bongo: https://bongobd.com/
- WAVES: https://wavespb.com/
- Doordarshan: https://prasarbharati.gov.in/
- Commons file reviewed: https://commons.wikimedia.org/wiki/File:%E0%A6%B6%E0%A7%87%E0%A6%B7_%E0%A6%89%E0%A6%A4%E0%A7%8D%E0%A6%A4%E0%A6%B0_-_%E0%A6%AC%E0%A6%BE%E0%A6%82%E0%A6%B2%E0%A6%BE_%E0%A6%9A%E0%A6%B2%E0%A6%9A%E0%A6%BF%E0%A6%A4%E0%A7%8D%E0%A6%B0_(%E0%A7%A7%E0%A7%AF%E0%A7%A4%E0%A7%A2).webm
- Indiancine.ma usage/copyright policy: https://indiancine.ma/copyrights

## CinePro assessment

CinePro Core is technically interesting: it has an OMSS-style HTTP API, modular provider discovery, parallel source resolution, Docker deployment and Redis-backed caching. Its current provider directory contains generic third-party sources, not a Bengali-specific provider.

It is **not suitable to vendor or host as 7xPlay's production backend in its current form**:

- The repository is licensed under **PolyForm Noncommercial 1.0.0**.
- Its own documentation limits intended use to personal, home and educational use, and says it is not designed or supported as a commercial or hosted streaming service.
- Its documentation says it is not secure for public hosting by default.
- No Bengali-specific provider or verified Bangla-audio catalogue was found in its current provider directory.

Reference: https://github.com/cinepro-org/core  
Documentation: https://docs.cinepro.cc/introduction  
License: https://github.com/cinepro-org/core/blob/main/LICENSE

**Recommendation:** Do not embed, deploy or copy CinePro Core into 7xPlay. We can independently adopt generic architectural ideas—such as a provider registry, a standard source model and parallel health checks—while implementing them from scratch around sources for which 7xPlay has explicit rights and technical documentation.

## Provider acceptance gate

A candidate is not "verified" because its website lists Bengali titles or because a scraper returns a URL. It must pass all of these checks:

1. **Permission:** official API/SDK/feed, an explicit partner agreement, or a clearly redistributable licence covering the intended use and territories.
2. **Identity:** stable content matching to the requested title, season and episode; no accidental title-only or subtitle-only matches.
3. **Language:** language code/label identifies the actual audio track as Bengali (`bn`), not merely Bengali subtitles, page language, title language or inferred country.
4. **Playback:** response is reachable and playable by the supported player; verify MIME/playlist format, range requests, required headers, seek, start time and playback continuity.
5. **Track handling:** inspect HLS master audio groups or media track metadata where available; preserve language labels and distinguish multiple audio tracks from separate provider sources.
6. **Reliability:** test a small fixed matrix of known titles and episodes, record latency and failure modes, and confirm provider failures do not reset a currently progressing stream.
7. **Operations:** confirm rate limits, token expiry, allowed caching/proxying, attribution, territory restrictions, user authentication requirements and takedown/contact process.

Only providers that pass the gate should be advertised to 7xPlay. An unknown audio language must remain **Unknown**; it must never be promoted to Bengali based only on a title, subtitle or provider description.

## Next integration sequence

1. Contact Hoichoi first for partner playback access; in parallel, ask WAVES/Prasar Bharati about approved DD Bangla/VOD feeds.
2. Ask Addatimes, KLiKK, Chorki and Bongo for current partner API/SDK documentation and written integration permission.
3. If a partner supplies a test tenant or approved sample feed, verify movie, series and episode playback before writing an adapter.
4. Keep any approved live TV source in a separate live-TV catalogue; do not force it through the existing TMDB movie/TV stream endpoints.
5. If no partner interface is made available, leave these providers out rather than shipping an unauthorised or unreliable scraper.

## Audit notes

- The live 7xPlay scraper catalogue was checked on 31 October 2026. It returned 13 enabled providers; none described Bengali/Bangla audio coverage.
- No provider code, scraping bypass, credential handling or playback proxy was added by this audit.
- This document records the verification result and the evidence required to continue. A future source/API contract should be re-audited before implementation because provider coverage and terms can change.
