# Job Tracker beta — UI decisions v2

## Direction

A focused, calm job-search workspace with clearer hierarchy and a more organic color identity. V2 changes the presentation only: preserve product structure, workflows, and status meaning.

## Brand assets

- The supplied wordmark remains unchanged in the shared header, login, and OAuth consent. Its blue BETA mark is an asset detail; the application palette is evergreen.
- Use `priv/static/images/job-tracker-icon.png` for the icon-only square and `priv/static/favicon.ico` for browser tab sizes.
- Preserve `new-logo.png` as the supplied source asset.
- Meaningful logo images use `alt="Job Tracker beta"`; interface icons use Heroicons.

## Visual system

- Evergreen palette: canvas `#f3f8f6`, white surfaces, ink `#14332f`, muted text `#506660`, border `#d6e5df`.
- Primary/interactive color is evergreen `#0f766e`; white text on it meets WCAG AA (5.47:1). Links, focus, selected navigation, and actions share this token.
- Amber `#b45309` is the secondary color (5.02:1 with white); highlight accent `#d97706` uses dark ink `#1c1917` (5.49:1). Do not use amber as small white-on-color text.
- Keep established application status colors and their text labels unchanged.
- Keep Inter/system sans and mono data labels, 12–14px card radii, fine borders, restrained shadows, and the shared `max-w-7xl` shell.
- OAuth consent uses the same evergreen surfaces, focus, and primary action despite being standalone HTML.

## Icon theme

- Heroicons use the solid 24px set by default for a bolder, consistent interface.
- Keep `-outline`, `-mini`, and `-micro` suffixes available for explicit variants.
- Existing semantic icon names and labels remain; icons supplement visible text and never carry status meaning alone.

## Interaction and accessibility

- Preserve semantic headings, visible input labels, form IDs, CSRF, routes, and actions.
- Maintain visible focus rings, reduced-motion support, readable contrast, and the existing responsive behavior.
- Small screens keep all controls reachable without page-level horizontal overflow; OAuth client names and redirect URLs wrap.

## Scope guardrails

- Light theme only. No dark-mode toggle, new routes, authentication methods, or workflow changes.
- Existing application data, status colors, and behavior are unchanged.
