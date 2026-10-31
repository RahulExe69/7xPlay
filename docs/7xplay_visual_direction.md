# 7xPlay visual direction

## Identity

7xPlay is part of the 7x product family and follows the 7xCinema product direction: amber/gold with a film-inspired character. The shared brand token is directional, so treat these values as the starting palette until the product artwork receives final visual approval.

| Role | Value | Use |
|---|---|---|
| Primary gold | `#FFC247` | Primary actions, selected/progress accents |
| Ember | `#E77916` | Secondary emphasis, used sparingly |
| Champagne | `#FFF0B5` | Highlights on dark gold surfaces |
| On gold | `#2B1D08` | Text/icons on gold controls |

The interface should feel like a premium cinema catalogue, not a reskinned template. Let posters, backdrops and title artwork supply colour. Keep the chrome quiet and let gold identify the important action or current selection.

## Visual principles

- **Artwork first.** Content imagery should be the most expressive part of each screen. Avoid decorative gradients behind ordinary lists or repeated glow effects.
- **Warm graphite, not pitch-black everywhere.** Keep the existing theme surface hierarchy and AMOLED option. Use restrained warm accents; do not tint every panel gold.
- **Strong typography.** Clear page titles, calm metadata, compact labels and consistent Figtree weights. Do not add display fonts or artificial text effects just to look cinematic.
- **Disciplined shapes.** Prefer compact card/button radii and consistent spacing. Avoid oversized rounded cards, nested pills and excessive glassmorphism.
- **Quiet interaction.** Use short, purposeful transitions and subtle selection markers. Respect reduced-motion settings and keep tap targets accessible.
- **Real contrast in both themes.** Gold may stay bright on dark surfaces; on light surfaces, derive a darker gold for text and icon use. Never use pale gold text on white.
- **One accent at a time.** Gold is the signature. Ember and champagne are supporting colours, not three competing highlights on the same screen.

## Implementation sequence

1. Establish brand tokens, accessible theme accent and selected-navigation treatment.
2. Redesign the navigation frame and Home hierarchy, including hero, continue-watching and editorial content rows.
3. Bring Discover, Search, New & Hot and Library into the same visual language without removing any destinations or filters.
4. Refine title details, episode lists, profile, settings and secondary pages.
5. Restyle player chrome only after the catalogue surfaces are stable; do not modify source selection, provider fallback, language aggregation or playback state while doing visual work.
6. Validate Dark, AMOLED, Light, custom/dynamic, seasonal and ambient themes; phone/tablet breakpoints; RTL; text scaling; and existing navigation/restoration/deep-link flows.

## Non-negotiable preservation rules

- Keep Android TV navigation and screen layouts stable while the handheld redesign proceeds.
- Preserve playback, unified audio selection, subtitles, provider diagnostics, downloads, sync, ads, deep links, analytics and state restoration.
- Do not remove the Discover destination or its filters as a shortcut to simplifying navigation.
- Keep all user-visible copy localized; do not hardcode English labels into redesigned controls.
- Do not change application IDs, backend identifiers, package names, API contracts or data models as part of visual redesign.
- A visual phase is complete only after its affected tests and device screenshots have been checked. Do not report a build or visual review that was not performed.
