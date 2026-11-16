# Job Tracker — Session Handoff

Read this file first at the start of every session, then read `TASKS.md`.
Update it before ending every session.

---

## Current State

- **Current phase:** Phase 4 — Job Application Management (complete; awaiting review)
- **Current task group:** 4.10 — complete.
- **Next task:** Phase 5.1 after review — verify the already-wired statuses and
  default `Interested`, then implement the initial history record and status
  transitions.
- **Overall status:** Phase 4 complete and verified; Phase 5 not started.
- **Last commit:** Phase 4.10: Implement application-tag associations (final
  Phase 4 commit; see `git log`).

## Last Session Summary

Phase 4 (Job Application Management) is complete. The app now has protected
LiveViews for application listing, creation, editing, details, and deletion, plus
a standalone tag management page. Navigation exposes Applications and Tags.

The list shows position, company, current status, creation date, and tags,
newest first. Phase 6 filters, search, sorting, and pagination are intentionally
not implemented yet. The shared `ApplicationForm` provides company/recruiter
`datalist` suggestions from the current user's values, existing-tag multi-select,
and comma-separated inline tag creation. Creation and editing with tags are
transactional: unknown or other-user tag IDs roll back all changes, and an inline
name reuses an existing tag case-insensitively while preserving its casing.

Application details render all fields, a validated external job-posting link,
tags, timestamps, and read-only status history. Status changes and history
creation remain Phase 5. Deletion requires confirmation and is a hard delete;
database cascades remove history and tag links. Tag deletion removes links only.
Cross-user records behave as not found: contexts return/raise as before, and
LiveViews redirect to the list with an error flash.

Phase 3 remains as previously recorded: five domain schemas, 13 seeded statuses,
scoped contexts, database constraints/indexes, cascades, and cross-user domain
isolation tests. Phase 4 added 67 tests; the suite is 189 tests and
`mix precommit` passes.

## Assumptions Made

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

## Blockers and Open Questions

- Phase 5 tasks 5.1 (wire seeded statuses) and 5.2 (default `Interested`) are
  already implemented in Phase 3. Phase 5 should verify and mark them rather than
  duplicate the work, then start with the initial history record (5.3).

## Deviations from PRODUCT.md

None. If this file and PRODUCT.md conflict, PRODUCT.md wins; list the conflict here and ask.

## Next Actions

1. Await Phase 4 review.
2. After review, verify Phase 5.1/5.2 (already wired in Phase 3: status foreign
   key and default `Interested`) and mark them complete.
3. Implement the initial `Interested` history record and transactional status
   transitions with optional notes (5.3–5.7), rejecting same-status changes.
4. Add the status-change UI and chronological timeline (5.8), then status
   history tests (5.9). Keep all reads/writes scoped and history append-only.

---

## Session Log

Add one entry per session, newest first, in this format:

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
