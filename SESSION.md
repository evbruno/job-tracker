# Job Tracker — Session Handoff

Read this file first at the start of every session, then read `TASKS.md`.
Update it before ending every session.

---

## Current State

- **Current phase:** Phase 8 — Resume Management (complete; awaiting review).
- **Current task group:** 8.1–8.9 — complete. A presentation-only UI refresh
  (2026-11-18) is also complete and committed; it adds no product scope.
- **Next task:** Review Phase 8. Operator provisioning remains outstanding for
  Phase 7. No Phase 9 is defined.
- **Overall status:** Phases 1–8 complete and verified locally. The application
  is production-ready on the code side; real deployment requires operator-only
  DNS/TLS, volume, secrets, monitoring, and off-site backups.
- **Last commit:** `Phase 8.9: Add a resume creation Mix task` follows the UI
  refresh and Phase 8.8 commits.

## Last Session Summary

Phase 8 (Resume Management) adds many independent resumes per user. Each resume
has a title, body, email, optional full name, headline, phone, and location, plus
optional LinkedIn, GitHub, and portfolio URLs. New resumes prefill the email from
the signed-in user's account; the field stays editable. Resumes reuse the
existing per-user tags through a new `resume_tags` join table, and the tag page
now notes that deletion removes the tag from applications and resumes.

The `TrackMyJobEx.Resumes` context is scoped by `%Scope{}` throughout, uses
transactions for create/update with tags, validates ownership of submitted tag
ids, and returns "not found" for another user's resume. The UI adds a Resumes
list, details page, create/edit form, safe link rendering, and a
confirmation-gated delete, plus navigation and dashboard links. The
`mix resumes.create EMAIL [--title TITLE]` task creates a simple starting resume
for an existing user through the scoped context. Phase 8 added 47 tests (295
total) and `mix precommit` passes. `docs/SECURITY.md` now includes the resume and
`ResumeTag` isolation matrices.

Phase 7 (Production Readiness) is complete in the repository. Security hardening
sets `HttpOnly`, `Secure`, and `SameSite=Lax` on session and remember-me cookies
in production, enforces HTTPS with `force_ssl` and one-year HSTS, excludes
`/health` from redirects, and restricts job URL rendering to absolute
`http`/`https` URLs. Database files, sidecars, `.env*`, backups, and release
artifacts are gitignored, and the Docker image runs as `nobody` under `tini`.

Tenant isolation was reviewed end to end. Every user-owned query takes a
`%Scope{}` and filters by `current_scope.user.id`; there are no unscoped
application/tag getters. Tag association ids are re-fetched through the scope and
roll back atomically on failure. A resource × operation matrix with test
locations is in `docs/SECURITY.md`.

SQLite production settings are WAL, foreign keys, a 5-second busy timeout, pool
size 5, and tuned queue settings. A new migration adds composite and NOCASE
indexes, and `EXPLAIN QUERY PLAN` confirms index-backed listing, status/company/
recruiter filters, history, tag links, suggestions, and the tag AND filter.
Company/recruiter filters now use `COLLATE NOCASE` instead of `lower()`.

The production database path defaults to `/data/track_my_job_ex/
track_my_job_ex.db` (or `$DATA_DIR`), and its parent directory is created on
boot. A production release was built and booted; `/health` returned `200 ok`,
the root redirected to HTTPS, cookies included `Secure; HttpOnly; SameSite=Lax`,
and HSTS was present. Online backup/restore scripts use `sqlite3 .backup`; a
seeded backup was restored with matching counts, matching schema, and
`integrity_check: ok`. CI runs formatting, warnings-as-errors compilation, Credo
strict, and the full suite. A new end-to-end test covers login, create with tags,
status/history, filters, pagination, sorting, cross-user isolation, and delete
cascades through the real router and LiveViews.

The suite is 241 tests (up from 231) and `mix precommit` passes. The remaining
items are operator-only and are listed under Blockers and in
`docs/DEPLOYMENT.md`.

## Assumptions Made

- 2026-11-18 — Phase 8: "many versions of a resume" means many independent
  resume records, each identified by its own title. There is no parent/version
  chain, version comparison, or default/primary resume flag.
- 2026-11-18 — Phase 8: resumes reuse the existing user-owned `tags` table
  through a `resume_tags` join table rather than introducing a second tag
  vocabulary. A tag is shared across applications and resumes, and deleting it
  removes both kinds of links without deleting either record.
- 2026-11-18 — Phase 8: the email is required. `new_resume_changeset/2` sets it
  from `current_scope.user.email`; a supplied value overrides the default and an
  explicit blank value fails validation, so clearing the field cannot silently
  restore the account email.
- 2026-11-18 — Phase 8: proposed extra fields are `full_name`, `headline`,
  `phone`, and `location` (all optional), because a usable CV needs a person's
  name and contact context beyond a single email. The body is required and
  limited to 50,000 characters; the title is limited to 255.
- 2026-11-18 — Phase 8: URL fields follow the existing job-posting rule —
  absolute `http`/`https` with a host when present, stored as `NULL` when blank,
  and rendered only through `Formatters.safe_http_url/1`.
- 2026-11-18 — Phase 8: the resume list is ordered by `updated_at` descending
  with an `id` tiebreaker. It has no filters, search, or pagination; deletion is
  available from the details page through the existing confirmation modal.
- 2026-11-18 — Phase 8: linking resumes to applications, file uploads, PDF
  generation, version comparison, and default resumes are deliberately out of
  scope and recorded in `PRODUCT.md`.
- 2026-11-18 — Phase 8: `mix resumes.create EMAIL [--title TITLE]` targets an
  existing user resolved by email and creates one untagged resume with the
  default title `Simple resume` and a short editable body outline. Tags, body
  overrides, and bulk creation stay in the web interface or a future task.
- 2026-11-18 — UI refresh: the app ships one light theme. The generator's theme
  toggle, `dark` theme styles, and the inline theme script were removed. No dark
  mode or other themes were added.
- 2026-11-18 — Native `data-confirm` dialogs were replaced by server-rendered
  confirmation modals. The flows are two-step (open, then confirm) and the
  LiveView tests assert that sequence.
- 2026-11-18 — Tag filters and the application form's tag picker use checkbox
  chips. The container ids `#filter-tags` and `#application-tag-ids` are
  unchanged; checked state is asserted with `input[checked]` instead of
  `option[selected]`.
- 2026-11-18 — Status names are always rendered as text; the five colour families
  are a secondary cue only. Unknown status slugs fall back to the neutral "early"
  family.
- 2026-11-18 — The dashboard change is copy and layout only: links to
  Applications and Tags. No counts, aggregates, or new queries were added.
- 2026-11-18 — The list filter bar stays visible at every width instead of being
  collapsed behind a disclosure. This keeps filter state in the DOM and avoids
  the disclosure reopening on LiveView patches.
- 2026-11-18 — Presentation-only refactor: contexts, schemas, migrations, query
  contracts, ownership rules, and flash strings were not changed.
- 2026-11-16 — Task 7.1: Cookies use `Secure` only when `Mix.env() == :prod` so
  local development and tests can keep using HTTP.
- 2026-11-16 — Task 7.1: HSTS is one year. `/health` and localhost are excluded
  from HTTPS redirects for private health checks; the proxy must forward
  `X-Forwarded-Proto: https`.
- 2026-11-16 — Task 7.2: SQLite keeps WAL and foreign keys and adds a 5-second
  busy timeout, pool size 5, and `queue_target: 50`/`queue_interval: 1000`.
  Production runs one writer instance per database file.
- 2026-11-16 — Task 7.2: Company/recruiter filters changed from
  `lower(column) = ?` to `column = ? COLLATE NOCASE`; behavior remains an exact,
  case-insensitive match while becoming index-backed.
- 2026-11-16 — Task 7.3: `DATABASE_PATH` defaults to
  `${DATA_DIR:-/data}/track_my_job_ex/track_my_job_ex.db`. The parent directory
  is created on boot, but migrations are an explicit `bin/migrate` deploy step,
  not an automatic boot action.
- 2026-11-16 — Task 7.3: `/health` is an unauthenticated database-only check
  (`SELECT 1`). No APM dependency was added; external monitoring is documented
  as an operator integration.
- 2026-11-16 — Task 7.4: Backups use `sqlite3 .backup` scripts rather than
  Litestream, avoiding a new dependency and a sidecar process. Scheduling,
  encryption, and off-site storage are operator-only.
- 2026-11-16 — Task 7.5: The repository provides a production release, hardened
  Dockerfile, and GitHub Actions CI. It does not contain cloud credentials or an
  actual deploy target, so publishing/deploying remains operator-only.
- 2026-11-16 — Task 7.7: Operator-only items are annotated in `TASKS.md` and
  documented as blockers rather than marked as fully provisioned.
- 2026-11-16 — Task 6.1–6.7: The URL contract uses status slugs (`status=applied`)
  rather than status ids, and tag ids for tags (`tags[]=1&tags[]=2`). Invalid or
  unknown values fall back to the defaults instead of producing an error page.
- 2026-11-16 — Task 6.5: Tag ids that do not belong to the current user are
  dropped before filtering, so another user's ids never filter and never widen
  the result set.
- 2026-11-16 — Task 6.6: Sort fields are `created` (`inserted_at`) and `updated`
  (`updated_at`); the `id` tiebreaker follows the primary direction so
  pagination stays deterministic.
- 2026-11-16 — Task 6.8: Any filter or sort change resets pagination to page 1.
- 2026-11-16 — Task 6.9: The empty-state distinction is based on whether filters
  are active. With zero applications and active filters, the no-matches state is
  shown; clearing the filters reveals the "no applications yet" state.
- 2026-11-16 — Task 6.11: A page number beyond the last page is clamped to the
  last page. The requested page may remain in the URL until the next navigation.
- 2026-11-14 — Task 2.1: Used the Phoenix authentication generator with LiveView
  and the default `bcrypt` hashing library on this platform.
- 2026-11-14 — Task 2.3: Because email is out of scope for the initial version,
  the notifier, mailer, Swoosh dependency, and dev mailbox were removed rather
  than left as dead plumbing. `confirmed_at` and `sent_to` were dropped through
  a reversible migration.
- 2026-11-14 — Task 2.3: Password rules are the generator defaults: minimum 12
  characters, maximum 72 bytes for bcrypt.
- 2026-11-14 — Task 2.5: Logout is a protected controller route and redirects to
  the login page. Sessions use the generator's standard 14-day token lifetime;
  no custom session policy or remember-me UI was added.
- 2026-11-14 — Task 2.6: The Mix task accepts `--password` for non-interactive
  use and otherwise prompts twice with `:io.get_password/1` (hidden where the
  terminal supports it). Failures raise `Mix.Error`, producing a non-zero exit.
- 2026-11-14 — Task 2.9: Record-level isolation tests were deferred to Phase 3
  because applications and tags did not exist yet.
- 2026-11-14 — Task 3.1: The `statuses` table is created in the
  `create_job_applications` migration because `job_applications.status_id`
  references it and SQLite cannot add foreign keys later. The `Status` schema and
  the migration that seeds the 13 rows landed in Task 3.3.
- 2026-11-14 — Task 3.3: Statuses have no timestamps. They are global, read-only,
  and seeded by migration so dev/test/prod all receive them.
- 2026-11-14 — Task 3.4/3.7: Tag names are trimmed, limited to 50 characters,
  and unique per user via `tags_user_id_name_index`:
  `(user_id, name COLLATE NOCASE)`, created with raw SQL. Original casing is
  preserved. Tags are listed by name ascending; tie-breaking is by id.
- 2026-11-14 — Task 3.5: `ApplicationTag` has no timestamps. The association
  helpers live in `TrackMyJobEx.JobApplications`; `TrackMyJobEx.Tags` owns tag
  CRUD.
- 2026-11-14 — Task 3.9: `create_application/2` always sets `user_id` from the
  scope and `status_id` to the seeded `Interested` status, ignoring any
  client-supplied values. `job_posting_url` is trimmed and a blank value is
  stored as `NULL`. Position is also trimmed for consistency.
- 2026-11-14 — Task 3.9: URL validation uses `URI.new/1` and requires an
  `http`/`https` scheme plus a host. Invalid URLs produce a changeset error.
- 2026-11-14 — Task 3.9: `add_tag_to_application/3` rejects duplicate links with
  a changeset error (the unique join index is authoritative). Removing a missing
  link returns `{:error, :not_found}`. Both helpers return transaction tuples and
  touch the application's `updated_at`.
- 2026-11-14 — Task 3.9: `list_status_history/2` is scoped and preloads
  previous/new statuses; history is ordered by `changed_at` then id. No history
  create/update/delete API exists until Phase 5.
- 2026-11-14 — Task 3.9: Deleting a user cascades to their applications and tags
  at the database level. There is no user-deletion UI in the product.
- 2026-11-14 — Task 3.10: Cross-user access through `get_*` returns `nil`;
  through `get_*!`, `update_*`, `delete_*`, and association helpers it raises
  `Ecto.NoResultsError`, which callers must translate into "not found".
- 2026-11-16 — Task 4.2/4.8: Inline tag input is comma-separated. Existing tags
  are matched case-insensitively and reused with their original casing. Tag
  names containing commas cannot be created through this input.
- 2026-11-16 — Task 4.4: Application details show read-only status history.
  Status changes, notes, and the interactive timeline are deliberately deferred
  to Phase 5.
- 2026-11-16 — Task 4.7: Company/recruiter suggestions are de-duplicated
  case-insensitively, sorted case-insensitively, and preserve the first
  encountered casing. They are computed in the context from the current scope's
  applications only.
- 2026-11-16 — Task 4.9: The standalone tag page lists, renames, and deletes
  tags. It does not create tags standalone because PRODUCT.md only requires
  inline creation plus list/rename/delete.
- 2026-11-16 — Task 4.10: LiveViews redirect to the application list with an
  error flash when another user's application is requested, rather than exposing
  a 404 page. Context functions still return `nil`/raise as documented.
- 2026-11-16 — Task 4.10: `create_application_with_tags/4`,
  `update_application_with_tags/5`, and `set_application_tags/3` use
  `Repo.transaction/1` (not `Ecto.Multi`) to keep creation/update and tag links
  atomic.
- 2026-11-16 — Task 5.1/5.2: Verified that Phase 3 already wired statuses to
  applications/history and defaulted new applications to `Interested`, including
  ignoring client-supplied status ids. No Phase 5 changes were needed.
- 2026-11-16 — Task 5.3: `create_application/2` and
  `create_application_with_tags/4` now use `Ecto.Multi`, so the application and
  its initial `Interested` history row are committed together. The initial
  history timestamp is the application's `inserted_at`.
- 2026-11-16 — Task 5.4–5.7: Status change input is validated through a
  form-only `StatusChange` embedded schema (`status_id`, `notes`). It is not
  persisted; the context maps it onto the application update and a new history
  row inside one `Ecto.Multi` transaction.
- 2026-11-16 — Task 5.6: Status notes are trimmed and blank notes become `NULL`.
  The 2,000-character limit is enforced in the status-change and history
  changesets.
- 2026-11-16 — Task 5.9: Transactional rollback is covered both by invalid-tag
  creation failures (application, initial history, and links all roll back) and
  by a SQLite test trigger that forces a history insert failure and proves the
  application status update rolls back.
- 2026-11-16 — Task 5.9: History remains append-only; the context exposes no
  update or delete functions for individual history rows, and a test asserts that
  API surface stays closed.

## Blockers and Open Questions

Operator-only blockers (no code blocker):

- Real domain/DNS and a TLS certificate, plus load-balancer/proxy configuration.
- Provisioning the persistent volume, setting ownership to UID 65534, and
  confirming local-filesystem semantics (no NFS).
- Storing `SECRET_KEY_BASE` and other credentials in a secret manager.
- External monitoring/alerting and log aggregation.
- Scheduled, encrypted, off-site backups with retention and periodic restore
  drills.
- The actual image publish and deploy step; CI currently verifies only.

Open question: the target hosting platform is not specified, so the deployment
guide describes generic release/Docker steps and leaves platform-specific wiring
to the operator.

## Deviations from PRODUCT.md

None. If this file and PRODUCT.md conflict, PRODUCT.md wins; list the conflict here and ask.

## Next Actions

1. Await Phase 8 review.
2. Operator: provision DNS/TLS, the persistent volume, and production secrets.
3. Operator: connect monitoring/log aggregation and schedule encrypted off-site
   backups; run a restore drill.
4. On the real host, run `bin/migrate`, verify `/health` returns `200`, and
   confirm the HTTPS redirect, HSTS, and `Secure` cookies through the proxy.
5. Deploy and keep one application instance per SQLite database file. Do not
   scale horizontally against a shared volume.
6. Re-run `mix precommit` after any change. Do not release until the operator
   checklist in `docs/DEPLOYMENT.md` is complete.

---

## Session Log

Add one entry per session, newest first, in this format:

### 2026-11-18

- **Done:** Phase 8, task groups 8.1–8.9. Added many independent resumes per
  user with a title, body, required email (prefilled from the signed-in user),
  optional full name, headline, phone, and location, and optional LinkedIn,
  GitHub, and portfolio URLs. Added the `resumes` and `resume_tags` tables with
  cascades and indexes, the `Resume`/`ResumeTag` schemas, and the scoped
  `TrackMyJobEx.Resumes` context with transactional create/update-with-tags and
  ownership checks. Added `ResumeLive.Index/New/Edit/Show`, the shared
  `ResumeForm`, nav and dashboard links, and updated the tag deletion copy.
  Added `mix resumes.create EMAIL [--title TITLE]` for creating a simple
  starting resume for an existing user. Updated `docs/SECURITY.md` with the
  resume and `ResumeTag` isolation matrices. Phase 8 added 47 tests (295 total);
  `mix precommit` passes.
- **Commits:** `Phase 8.9: Add a resume creation Mix task` (this commit; see
  `git log`), following `Phase 8.8: Add resume versions with tags`.
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None. Operator-only infrastructure items are unchanged.
- **Next:** Await review of Phase 8; the operator checklist remains the only
  path to release.

### 2026-11-18

- **Done:** Presentation-only UI refresh across the whole app. Added design
  tokens in `assets/css/app.css` (ink `#101720`, ink-muted `#5A6675`, canvas
  `#F1F4F7`, surface `#FFFFFF`, rule `#CBD3DC`, cobalt `#1F4FD8`; system sans for
  UI and system mono for timestamps/counts), a single light daisyUI theme, five
  status colour families, a vertical history timeline, a modal entrance
  animation, and a `prefers-reduced-motion` block. Added
  `TrackMyJobExWeb.UI` (`status_badge/1`, `status_marker/1`, `tag_chip/1`,
  `empty_state/1`, `confirm_modal/1` with a colocated `.Modal` hook for focus,
  Tab trapping, Escape, and focus restore). Reworked the app shell (sticky
  header, wrapping nav, `active` section highlight, mono email), restyled the
  shared input/header/flash primitives, and rewrote the list, details, create,
  edit, tags, login, and dashboard screens. Deleted the native `data-confirm`
  flows in favour of real modals and changed tag pickers to checkbox chips.
  Updated the LiveView and end-to-end tests for the two-step delete flow and
  chip state. `mix precommit` passes with 248 tests. Validated every screen at a
  390px-wide viewport: no horizontal overflow, the modal becomes a bottom sheet,
  and the status history timeline is vertical. (A daisyUI `.timeline` class
  collision initially forced the history items horizontal; the styles were
  renamed to `.history-*`.)
- **Screens:** login (centered panel, no nav when signed out); dashboard (copy +
  links to Applications and Tags); application list (dense ledger rows with a
  3px status edge, always-visible filter bar with a 2-column mobile grid,
  removable filter chips, direction toggle, both empty states, pagination,
  confirmation modal); application details (status badge in the header, status
  change panel with "current status since", two-column body, full-width
  oldest-first timeline, confirmation modal); create/edit (sectioned form with
  datalists, checkbox tag chips, comma-separated new tags, sticky action row);
  tags (ledger rows, inline rename, confirmation modal); login.
- **Deliberately not done:** no dark mode or theme switch, no new dashboard
  stats/queries, no new product features, no changes to contexts, schemas,
  migrations, URL contracts, ownership logic, or flash strings. The temporary
  demo seed files (`lib/mix/tasks/demo.seed.ex`,
  `test/mix/tasks/demo_seed_test.exs`) remain untracked from the earlier session.
- **Mobile check:** at 390px the header wraps the nav onto a second line, the
  list/filter/tag rows stack without clipping, the timeline is vertical, and
  the delete modal is a full-width bottom sheet. Text contrast is at least
  5.3:1 for muted text and 6.3:1 or better for status text.
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None for the UI refresh. Operator-only infrastructure items are
  unchanged.
- **Next:** Await review of the UI refresh; the operator checklist in
  `docs/DEPLOYMENT.md` remains the only path to release.

### 2026-11-16

- **Done:** Phase 7, task groups 7.1–7.7. Hardened production cookies
  (`HttpOnly`, `Secure`, `SameSite=Lax`), enabled `force_ssl` with one-year HSTS
  and `/health` exclusion, added safe-URL regression tests, and ignored database
  sidecars, `.env*`, backups, and release artifacts. Reviewed tenant isolation
  end to end, added cross-user tag-association and filter-option tests, and
  documented the resource × operation matrix. Added SQLite production settings
  (WAL, foreign keys, 5-second busy timeout, pool 5, tuned queues), a composite/
  NOCASE index migration, and changed company/recruiter filters to
  `COLLATE NOCASE`; confirmed index-backed plans with `EXPLAIN QUERY PLAN`. Added
  `DATABASE_PATH`/`DATA_DIR` handling, a database-backed `/health` endpoint, and
  verified a production release boot. Added online `sqlite3 .backup` backup and
  restore scripts and verified a restore with matching counts/schema and
  `integrity_check: ok`. Added release scaffolding, a hardened non-root Docker
  image using `tini`, GitHub Actions CI, and a full end-to-end test. Wrote
  `docs/DEPLOYMENT.md` and `docs/SECURITY.md`. The suite is 241 tests (up from
  231) and `mix precommit` passes.
- **Commits:**
  - `2a0861a` Phase 7.1: Harden production cookies, transport security, and URL rendering
  - `a6c4413` Phase 7.2: Add tenant isolation coverage and production query indexes
  - `0dc6205` Phase 7.3: Add health endpoint and production runtime configuration
  - `11c2c44` Phase 7.4: Add SQLite backup and restore tooling
  - `6d66063` Phase 7.5: Add release, Docker, and CI deployment pipeline
  - `077ccfd` Phase 7.6: Add end-to-end workflow test
  - Phase 7.7: Document Phase 7 and update handoff (this commit; see `git log`)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** Operator-only: DNS/TLS, persistent volume, production secrets,
  external monitoring/logging, scheduled encrypted off-site backups, and the
  actual deploy step.
- **Next:** Await Phase 7 review; complete the operator checklist and deploy.

### 2026-11-16

- **Done:** Phase 6, task groups 6.1–6.11. Added
  `JobApplications.list_applications_filtered/2` plus `normalize_filters/2`,
  `filter_options/1`, and `page_size/0` for case-insensitive partial search,
  status/company/recruiter/tag filters with AND semantics, whitelisted sorting
  by creation or update date in both directions, and 25-per-page pagination.
  Rewrote `ApplicationLive.Index` to keep search, filter, sort, and page state
  in the URL query string using `handle_params/3` and `push_patch`, with
  dropdowns from the user's own values, separate no-applications and no-matches
  empty states, and responsive Tailwind layout. Added 28 tests (231 total),
  including wildcard escaping, tag AND semantics, sorting, pagination, invalid
  parameters, URL restoration, and cross-user isolation; `mix precommit` passes.
- **Commits:**
  - `f0d4eea` Phase 6.1: Implement search, filters, and sorting queries
  - Phase 6.11: Add listing UI, LiveView tests, and document phase (final Phase 6
    commit; see `git log`)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None.
- **Next:** Await Phase 6 review, then start Phase 7.1 security review.

### 2026-11-16

- **Done:** Phase 5, task groups 5.1–5.9. Verified the Phase 3 status wiring
  and default `Interested` status (5.1–5.2, no code changes). Application
  creation now writes the application and its initial history row atomically.
  Added `StatusChange` form validation and scoped
  `change_status_changeset/3`/`change_status/4` context functions using
  `Ecto.Multi` for status + history updates, same-status and unknown-status
  rejection, trimmed optional notes with a 2,000-character limit, and
  append-only history reads. The details page now has a status-change form and
  a chronological timeline with previous status, new status, timestamp, and
  notes. Added 14 tests (203 total), including transactional rollback and
  cross-user isolation; `mix precommit` passes.
- **Commits:**
  - `628577c` Phase 5.3: Create initial history and status change context
  - `999b6b9` Phase 5.8: Display application timeline and status change form
  - Phase 5.9: Add status history tests and document phase (final Phase 5
    commit; see `git log`)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None.
- **Next:** Await Phase 5 review, then Phase 6.1 search.

### 2026-11-16

- **Done:** Phase 4, task groups 4.1–4.10. Added protected LiveViews for
  application list/create/edit/details/delete and tag list/rename/delete;
  enabled Applications/Tags navigation; added company/recruiter suggestions,
  existing-tag multi-select, comma-separated inline tag creation, safe job URL
  rendering, read-only history display, and confirmation-gated hard deletes.
  Added scoped context functions for suggestions, create/update with tags, tag
  sync, and tag get/reuse/change. Tag/application writes are transactional and
  validate ownership. Added 67 tests (189 total). `mix precommit` passes.
- **Commits:**
  - `cd44643` Phase 4.1: Implement application listing
  - `8871e4e` Phase 4.2: Implement application creation
  - `ddad5de` Phase 4.3: Implement application editing
  - `3719a00` Phase 4.4: Implement application details
  - `5a9d631` Phase 4.5: Implement application deletion
  - `99a264e` Phase 4.6: Implement company and recruiter fields
  - `d4e7a33` Phase 4.7: Suggest company and recruiter values
  - `5c97eba` Phase 4.8: Implement inline tag creation
  - `888a781` Phase 4.9: Implement standalone tag management
  - Phase 4.10: Implement application-tag associations (final Phase 4 commit;
    see `git log`)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None. Phase 5.1/5.2 overlap already-completed Phase 3 work; Phase
  5 should verify and mark them instead of reimplementing.
- **Next:** Await Phase 4 review, then Phase 5.1–5.9.

### 2026-11-14

- **Done:** Phase 3, task groups 3.1–3.10. Added the JobApplication,
  ApplicationStatusHistory, Status, Tag, and ApplicationTag schemas; created and
  seeded the 13 global statuses in a migration; added foreign keys, not-null
  constraints, join uniqueness, the case-insensitive per-user tag index, and the
  `(user_id, company_name)` index; implemented the scoped
  `TrackMyJobEx.JobApplications` and `TrackMyJobEx.Tags` contexts with
  association helpers that touch `updated_at`; added fixtures and 39 domain
  tests covering validation, trimming, URL rules, defaults, ordering, cascades,
  case-insensitive tag uniqueness, and cross-user isolation. All checks pass via
  `mix precommit`; full suite is 122 tests.
- **Commits:**
  - `81f9420` Phase 3.1: Implement JobApplication schema
  - `99ea923` Phase 3.2: Implement ApplicationStatusHistory schema
  - `c5d90de` Phase 3.3: Implement Status schema and seed statuses
  - `0615da5` Phase 3.4: Implement Tag schema
  - `c83d3a1` Phase 3.5: Implement ApplicationTag association
  - `388074b` Phase 3.6: Add database constraints and indexes
  - `4c5de07` Phase 3.7: Add case-insensitive tag uniqueness index
  - `e4ed9a6` Phase 3.8: Add user company name index
  - `4cb92e3` Phase 3.9: Implement Phoenix contexts
  - Phase 3.10: Add domain tests (final Phase 3 commit; see `git log`)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None.
- **Next:** Phase 4.1 — implement application listing.

### 2026-11-14

- **Done:** Phase 2, task groups 2.1–2.9. Generated password authentication with
  bcrypt; disabled registration and removed reset/confirmation/magic-link/
  settings/mailer flows and the Swoosh dependency; added regression tests for
  removed routes; implemented password login/logout and navigation; added
  `mix users.create` with tests for success, duplicate/case-insensitive email,
  invalid email, short password, and bad arguments; protected the dashboard and
  logout route with both plug and LiveView `on_mount` hooks; documented tenant
  isolation conventions; added scope, session-isolation, protected-route, and
  helper tests. All checks pass via `mix precommit`.
- **Commits:**
  - `19122e4` Phase 2.1: Implement authentication
  - `ffc2d65` Phase 2.2: Disable public registration
  - `30c5b6a` Phase 2.3: Remove password reset and confirmation flows
  - `1bc563e` Phase 2.4: Add no-public-registration test
  - `72e2986` Phase 2.5: Implement login and logout
  - `518996a` Phase 2.6: Implement mix users.create
  - `69cb10c` Phase 2.7: Add authenticated route protection
  - `2f48670` Phase 2.8: Define tenant isolation conventions
  - `fa0aa7a` Phase 2.9: Add ownership authorization tests
  - `4a5b83a` Phase 2.3: Remove remaining mailer configuration (follow-up)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None.
- **Next:** Implement the `JobApplication` schema (Phase 3).
