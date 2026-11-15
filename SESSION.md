# Job Tracker — Session Handoff

Read this file first at the start of every session, then read `TASKS.md`.
Update it before ending every session.

---

## Current State

- **Current phase:** Phase 4 — Job Application Management
- **Current task group:** 4.1 — not started
- **Next task:** Implement application listing (Phase 4.1), reading applications
  through `TrackMyJobEx.JobApplications.list_applications/1` with
  `current_scope`.
- **Overall status:** Phase 3 complete and verified; ready to start Phase 4.
- **Last commit:** Phase 3.10: Add domain tests (final Phase 3 commit)

## Last Session Summary

Phase 3 (Core Domain) is complete. The domain now has five schemas:
`TrackMyJobEx.JobApplications.JobApplication`, `.Status`,
`.ApplicationStatusHistory`, `.ApplicationTag`, and `TrackMyJobEx.Tags.Tag`.

The `statuses` table is populated by a data migration with the 13 predefined
statuses in display order. Statuses are global read-only data; applications
reference a status by foreign key and default to `Interested` when created.
Status transitions and status history creation remain deliberately unimplemented
for Phase 5; this phase only exposes status reads and history reads.

Applications are user-owned. `TrackMyJobEx.JobApplications` exposes scoped
create/get/list/update/delete functions plus tag association helpers. Tags are
user-owned through `TrackMyJobEx.Tags`. Every user-owned function takes a
`%TrackMyJobEx.Accounts.Scope{}` first and re-fetches records through the scope;
another user's id is treated as not found. Client-supplied `user_id`, `status_id`,
and ownership fields are never cast.

Database integrity is enforced by not-null columns, foreign keys, a unique
`(application_id, tag_id)` join index, a `(user_id, name COLLATE NOCASE)` unique
tag index (raw SQL; case preserved), and a `(user_id, company_name)` index.
Application deletion cascades to status history and tag links; tag deletion
cascades to tag links only. Tagging and untagging an application update its
`updated_at` in the same short transaction.

Domain tests cover validation limits, URL rules, trimming, blank-to-NULL
normalization, the default status, status ordering, case-insensitive per-user tag
uniqueness, association linking/unlinking and timestamp touches, database
cascades, and cross-user isolation for applications and tags (read, list, update,
delete, and association attempts).

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

## Blockers and Open Questions

None.

## Deviations from PRODUCT.md

None. If this file and PRODUCT.md conflict, PRODUCT.md wins; list the conflict here and ask.

## Next Actions

1. Start Phase 4.1: implement application listing using the scoped
   `TrackMyJobEx.JobApplications` context and the existing layout.
2. Build application create/edit/details/delete LiveViews on top of the existing
   context functions.
3. Add company/recruiter `datalist` suggestions from the current user's values
   only, inline tag creation, and standalone tag management.
4. Keep LiveViews thin; all persistence goes through the contexts.

---

## Session Log

Add one entry per session, newest first, in this format:

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
