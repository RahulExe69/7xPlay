# 7xPlay visual direction

## Approved identity

The approved 7X artwork is the visual source of truth: a luminous amber/orange 7X mark, red-orange energy, selective electric magenta, and deep burgundy-black cinema space with film-strip imagery.

| Role | Token | Value | Use |
|---|---|---|---|
| Primary | `cinemaGold` | `#FFB91D` | Main Play/action controls and selected states |
| Supporting | `ember` | `#FF482E` | Secondary emphasis, small markers |
| Signature | `magenta` | `#EF2495` | Rare accent in editorial details and active moments |
| Background | `wine` | `#16070D` | Dark-mode page background |
| Surface | `wineSurface` | `#211019` | Subtle raised panels |
| Raised | `wineRaised` | `#2C1421` | Menus, cards and overlays where needed |

## Visual principles

- **Premium cinema, not neon overload.** Keep the canvas deep wine/black and quiet. Do not put gradients, glow, or saturated borders on every card.
- **Amber leads.** Gold is the primary action colour. Use deep ink on gold controls for readable contrast.
- **Red-orange supports.** Ember is for small secondary emphasis, not competing primary buttons.
- **Magenta is the signature spark.** Use it selectively in tiny editorial marks, progress details or rare highlights. Avoid magenta body text and large filled panels.
- **Artwork first.** Posters, backdrops and title art provide the visual energy. UI chrome should stay disciplined.
- **Strong typography.** Keep clear page titles, calm metadata, compact labels and consistent Figtree weights.
- **Disciplined shapes.** Prefer compact card/button radii and consistent spacing. Avoid oversized pills and excessive glassmorphism.
- **Contrast in every theme.** Gold may stay bright on dark surfaces; on light surfaces, derive a darker accent for small text and icons. Preserve the user's chosen/dynamic theme colours.
- **Quiet interaction.** Use short, purposeful transitions and respect reduced-motion settings.

## Implementation sequence

1. Establish brand tokens, accessible theme accent and selected-navigation treatment. (In progress.)
2. Refine Home spotlight, content shelves, cards and editorial hierarchy.
3. Bring Discover, Search, New & Hot and Library into the same visual language without removing destinations or filters.
4. Refine title details, episode lists, profile, settings and secondary pages.
5. Restyle player chrome only after catalogue surfaces are stable; do not modify source selection, provider fallback, language aggregation or playback state.
6. Validate Dark, AMOLED, Light, custom/dynamic, seasonal and ambient themes; phone/tablet breakpoints; RTL; text scaling; and existing navigation/restoration/deep-link flows.

## Preservation rules

- Keep Android TV layouts stable while handheld redesign proceeds.
- Preserve playback, unified audio selection, subtitles, provider diagnostics, downloads, sync, ads, deep links, analytics and state restoration.
- Do not remove the Discover destination or its filters as a shortcut.
- Keep all user-visible copy localized.
- Do not change application IDs, backend identifiers, package names, API contracts or data models as part of visual redesign.
- A visual phase is complete only after affected tests and device screenshots have been checked.
