# Job Tracker beta — UI decisions

## Direction

A calm, light SaaS workspace for keeping a job search organized. Keep the existing data-first structure and one light theme; add visual confidence through clear hierarchy, generous spacing, durable surfaces, and the supplied beta identity. This is a presentation refresh, not new product functionality.

## Brand assets

- Use `priv/static/images/job-tracker-logo.png` for the wordmark in the shared header, login shell, and OAuth consent. It is cropped from the provided root artwork and keeps the supplied proportions, dark briefcase, wordmark, and blue BETA mark.
- Use `priv/static/images/job-tracker-icon.png` for the icon-only square and `priv/static/favicon.ico` for browser tab sizes.
- Preserve `new-logo.png` as the supplied source asset; never render its contact-sheet panels as a logo.
- Meaningful logo images use `alt="Job Tracker beta"`; decorative icons retain the existing Heroicons component family.

## Visual system

- Light-only surfaces: canvas `#f4f6fb`, white cards, ink `#151923`, muted text `#566174`, rule `#dce3ef`.
- Brand blue `#3154d5` is for primary actions, links, focus, and active navigation. Pair action labels with white; do not use color alone for status meaning.
- Keep the existing Inter/system sans and mono data labels. Use tabular/monospaced figures where already present.
- Use 12–14px card radii, fine borders, and restrained shadows. No decorative glass blur on content cards.
- Main workspace shares a wide `max-w-7xl` container, white sticky header, and responsive gutters. Navigation wraps/scrolls instead of shrinking into unreadable labels.
- Login and OAuth use a single centered white card, explicit heading and copy, and one prominent primary action. OAuth keeps the requested scope, redirect destination, approve, and deny visible.

## Interaction and accessibility

- Preserve semantic headings, visible input labels, autofill attributes, form IDs, CSRF, and all existing routes/actions.
- Keep visible focus rings and reduced-motion support. Primary actions are comfortably sized; denied/secondary actions remain visually subordinate.
- Small screens use a single-column card and wrapping consent actions; long OAuth client names and redirect URLs wrap rather than widening the page.
- Keep established application status colors and their text labels unchanged.

## Scope guardrails

- No dark mode, additional routes, authentication methods, dashboard metrics, or workflow changes.
- All authenticated product pages inherit the shared shell/tokens. OAuth is separately styled HTML and must stay visually aligned with the light theme and brand assets.
