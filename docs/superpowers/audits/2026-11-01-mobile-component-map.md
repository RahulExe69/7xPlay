# 7xPlay Mobile Component Map — Pass 1

**Date:** 2026-11-02  
**Scope:** Shared mobile foundation review for Core Browse Task 1  
**Status:** Partial inventory; remaining call-site review is tracked in the core-browse plan.

## Principles

- Theme-derived semantic roles belong in `AppPalette`; screens should not invent their own foreground/surface contrast logic.
- Brand colours in `AppBrand` are signature colours, not defaults for every border or divider.
- Reusable components should make common interactions coherent without making unrelated screens look identical.
- Screen-specific composition wins over repeated generic headers, cards, rails, and decorative accents.

## Reviewed foundations

| Component | Responsibility | Decision |
|---|---|---|
| `AppPalette` | Theme-derived page, surface, raised surface, text, divider, selected/resting control and scrim roles. Its accent is contrast-adjusted against the page. | Retain as the semantic colour source. Keep testing Dark, AMOLED, Light and ambient page variants. |
| `AppBrand` | 7xPlay signature amber, ember, magenta and deep-wine values, including on-colour/container pairs. | Retain. Use amber for primary emphasis; keep ember/magenta signatures selective. |
| `AppSpace`, `AppRadii`, `AppBreakpoints`, `AppType` | Shared spacing, shape, responsive thresholds and Figtree type hierarchy. | Retain and extend only when multiple planned screens need the same token. |
| `PageAppBar` | Shared title bar for pushed mobile pages, optional kicker/actions/bottom content and tablet content-width alignment. | Retain the API. Remove its automatic brand stripe so the header is not decorated identically on every screen. |
| `BrandAccentRule` | Small 7X gradient signature. | Keep available for intentional, screen-specific use; never insert by default in generic page chrome. |
| `SearchPill` | Search input with controller, query callbacks, clear/loading states and accessible clear tooltip. | Retain the interaction contract. Review density and visual treatment with the Search composition. |
| `SegmentSwitch` | Two/three-way same-page view selection. | Retain for true segment changes; avoid using it as a generic filter chip. |
| `TogglePill` | Selectable filter/choice control with selected state and haptic feedback. | Retain for filter choices; keep theme-derived selected fill and foreground pairing. |
| `KickerHeading` / section heading primitives | Secondary section labels and optional trailing count/action. | Retain selectively. Vary hierarchy and spacing by page rather than using an identical header for every module. |
| `PillButton` | Primary/secondary action with icon direction and disabled/destructive states. | Retain its public API and RTL behaviour; review individual actions per screen. |
| `MediaArt`, `PosterCard`, `PosterRow`, `TopTenRow`, `ContinueRow` | Artwork rendering, catalogue cards, ranked rows and continue-watching progress. | Keep data/callback contracts and stable artwork fallbacks. Recompose how each page uses them; do not force every module into the same poster rail. |

## Change made in this pass

`PageAppBar` no longer adds `BrandAccentRule` to every title. The gradient widget itself remains available for deliberate use. A widget test covers this shared-header contract.

## Remaining review

The component call-site inventory and theme-contrast coverage still need completion before Core Browse Task 1 can be marked done. In particular, review dynamic/custom and seasonal theme coverage, tablet/RTL call sites, and each browse page's actual content composition. This document does not mark those checks as complete.
