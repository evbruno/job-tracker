# Job Tracker — Implementation Tasks

## Current Project Status

**Current phase:** Phase 5 — Application Status and History (complete; awaiting review)

**Overall status:** Phase 5 complete — ready for Phase 6 after review

**Current milestone:** Phase 5 verified; next implement search and usability (Phase 6).

---

## Phase 1 — Project Foundation

### 1.1 Project Initialization

- [x] Verify Elixir and Erlang/OTP versions.
- [x] Verify Phoenix installation and version.
- [x] Pin Elixir/Erlang versions (`.tool-versions` or equivalent).
- [x] Generate Phoenix application with LiveView and SQLite3 (`--database sqlite3`).
- [x] Initialize Git repository.
- [x] Create initial README.md.

### 1.2 Database

- [x] Configure SQLite3 database files and confirm they are gitignored.
- [x] Configure development database.
- [x] Configure test database.
- [x] Verify Ecto connectivity.
- [x] Verify migrations execute successfully.
- [x] Verify foreign key enforcement and WAL mode are enabled.
- [x] Add a throwaway test confirming that `COLLATE NOCASE` partial unique indexes and `LIKE` search behave as expected, then remove it.

### 1.3 Frontend and Layout

- [x] Verify LiveView setup.
- [x] Configure Tailwind CSS.
- [x] Establish application layout.
- [x] Create basic navigation.
- [x] Create initial dashboard placeholder.

### 1.4 Development Standards

- [x] Establish project coding conventions.
- [x] Create AGENTS.md (point to PRODUCT.md, TASKS.md, SESSION.md and the development rules).
- [x] Configure formatting.
- [x] Configure Credo.
- [x] Configure automated tests.
- [x] Document local development setup.

### 1.5 Verification

- [x] Application starts locally.
- [x] Database connection works.
- [x] Home page renders.
- [x] LiveView interactions work.
- [x] Tests execute successfully.
- [x] Formatting checks pass.
- [x] Initial Git commit created.

---

## Phase 2 — Authentication and User Isolation

- [x] Implement authentication.
- [x] Disable public registration.
- [x] Remove password reset and email confirmation flows.
- [x] Add a test proving no public registration route exists.
- [x] Implement login and logout.
- [x] Implement `mix users.create`.
- [x] Add authenticated route protection.
- [x] Define tenant isolation conventions.
- [x] Add ownership authorization tests.

**Acceptance criteria:**
- Users can authenticate with email and password.
- Users can be provisioned through the Mix task.
- Public registration is unavailable.
- Password reset and email confirmation flows are unavailable.
- Unauthenticated users cannot access protected pages.
- Users cannot access or modify another user's records.

**Phase 2 completion notes:**
- Authentication is password-only via `bcrypt_elixir`. The generated
  registration, password reset, email confirmation, magic-link, and account
  settings flows were removed together with their routes, modules, tests, and
  mailer plumbing.
- `mix users.create EMAIL [--password PASSWORD]` is the only provisioning path.
  Email uniqueness is case-insensitive through `COLLATE NOCASE` in SQLite.
- Session tokens expire after 14 days using the generator's standard policy.
- Isolation tests cover independent sessions, scope conventions, login/logout,
  and protected routes. Record-level isolation tests for applications, tags,
  status history, and tag associations are deferred to Phase 3 because those
  resources do not exist yet.

## Phase 3 — Core Domain

- [x] Implement JobApplication schema (including plain-text `company_name` and optional `recruiter_name` columns).
- [x] Implement ApplicationStatusHistory schema.
- [x] Implement Status schema and seed the 13 predefined statuses in a migration.
- [x] Implement Tag schema.
- [x] Implement ApplicationTag association.
- [x] Add database constraints and indexes.
- [x] Add uniqueness index for tag names (case-insensitive, per user), using `COLLATE NOCASE` (SQLite has no `citext`).
- [x] Add an index on `(user_id, company_name)` for filtering.
- [x] Implement Phoenix contexts.
- [x] Add domain tests.

**Acceptance criteria:**
- All entities can be created and retrieved.
- Associations work correctly.
- Ownership is enforced.
- Invalid records are rejected.
- Database constraints protect data integrity.

**Phase 3 completion notes:**
- Schemas: `JobApplications.JobApplication`, `JobApplications.Status`,
  `JobApplications.ApplicationStatusHistory`, `JobApplications.ApplicationTag`,
  and `Tags.Tag`.
- Contexts: `TrackMyJobEx.JobApplications` (applications, global status reads,
  history reads, tag associations) and `TrackMyJobEx.Tags`.
- Statuses are seeded by migration and shared globally. Applications default to
  `Interested`; status transitions and history creation remain for Phase 5.
- Database cascades: application deletion removes history and tag links; tag
  deletion removes tag links only.
- Domain tests cover validation, trimming, defaults, ordering, association
  linking/unlinking with `updated_at` touches, cascades, case-insensitive tag
  uniqueness, and cross-user isolation for applications and tags.

## Phase 4 — Job Application Management

- [x] Implement application listing.
- [x] Implement application creation.
- [x] Implement application editing.
- [x] Implement application details.
- [x] Implement application deletion.
- [x] Implement company and recruiter text fields (trimmed; blank recruiter stored as `NULL`).
- [x] Suggest previously used company and recruiter values in the form (`datalist`, current user's values only).
- [x] Implement inline tag creation from the application form.
- [x] Implement standalone tag management page (list, rename, delete).
- [x] Implement application-tag associations.

**Acceptance criteria:**
- Users can create and manage applications.
- New applications default to Interested.
- Company and recruiter are plain text fields with suggestions from the user's earlier entries.
- Applications support multiple tags.
- Application details display associated information.

**Phase 4 completion notes:**
- LiveViews: `ApplicationLive.Index`, `ApplicationLive.New`,
  `ApplicationLive.Edit`, `ApplicationLive.Show`, and `TagLive.Index`, all under
  the existing protected `live_session`. Navigation links for Applications and
  Tags are enabled.
- The list shows position, company, current status, creation date, and tags,
  newest first. Phase 6 filters, search, sorting, and pagination are not
  implemented yet.
- The shared `ApplicationForm` handles create/edit, company and recruiter
  `datalist` suggestions, existing-tag multi-select, and comma-separated inline
  tag creation. Suggestions and tag IDs are scoped to the current user.
- Context additions: `list_company_suggestions/1`,
  `list_recruiter_suggestions/1`, `new_application_changeset/2`,
  `create_application_with_tags/4`, `update_application_with_tags/5`,
  `set_application_tags/3`, and `Tags.get_tag_by_name/2`,
  `Tags.get_or_create_tag/2`, `Tags.change_tag/3`.
- Application creation/editing with tags is transactional. Unknown or
  other-user tag IDs roll back field and tag changes. Inline names reuse an
  existing tag case-insensitively and preserve its original casing.
- Details display all application fields, a safe external job-posting link,
  tags, timestamps, and read-only status history. Status changes remain Phase 5.
- Deletion requires confirmation, is a hard delete, and relies on database
  cascades for history and tag links. Tag deletion removes links only.
- Cross-user records behave as not found: contexts return/raise as before and
  LiveViews redirect to the list with an error flash.
- Phase 4 added 67 tests; the suite is 189 tests. `mix precommit` passes.

## Phase 5 — Application Status and History

- [x] Wire the seeded statuses (Phase 3) to applications and history (verified existing from Phase 3).
- [x] Set Interested as the default status (verified existing from Phase 3).
- [x] Create initial history record.
- [x] Implement status transitions (any status to any other).
- [x] Reject a change to the same status.
- [x] Implement optional status notes.
- [x] Implement transactional status updates.
- [x] Display application timeline.
- [x] Add status history tests.

**Acceptance criteria:**
- Every application has a current status.
- Every status change generates a history record.
- History records are append-only and removed only when their application is deleted.
- Status and history updates are atomic.
- Users can review the complete recruitment timeline.

**Phase 5 completion notes:**
- Tasks 5.1 and 5.2 were verified as already implemented in Phase 3: applications
  reference the seeded `statuses` table by foreign key, `new_application_changeset/2`
  assigns `Interested`, and client-supplied `status_id` values are ignored. No
  Phase 5 changes were needed for them.
- Application creation now inserts the application and its initial `Interested`
  history row (`previous_status_id` nil) in one `Ecto.Multi` transaction. The
  same applies to `create_application_with_tags/4`; an invalid tag rolls back
  the application, its initial history, and any tag links.
- `change_status/4` validates through `StatusChange` and then updates the
  application status and appends a history row in one `Ecto.Multi` transaction.
  Any status may follow any other. Same-status changes and unknown or missing
  statuses are rejected with changeset errors.
- Notes are optional, trimmed, blank values become `NULL`, and the maximum is
  2,000 characters. History is append-only: the context exposes reads only, with
  no create/update/delete API for individual rows.
- The application details page now includes a status-change form with an
  optional note and a chronological timeline showing each new status, the
  previous status when present, the change timestamp, and notes. `updated_at`
  changes on every status change.
- All reads and writes are scoped. Another user's application behaves as not
  found, including through the status-change form changeset and context
  function.
- Phase 5 added 14 tests (203 total), covering initial history creation,
  any-to-any transitions, same-status rejection, notes trimming and limits,
  ordering, `updated_at`, transactional rollback (including a forced history
  insert failure), append-only API checks, cross-user isolation, and LiveView
  status changes and timeline rendering. `mix precommit` passes.

## Phase 6 — Search and Usability

- [ ] Implement search (use `LIKE` or `lower()`; SQLite has no `ILIKE`).
- [ ] Implement status filters.
- [ ] Implement company filter (dropdown of the user's existing values, case-insensitive match).
- [ ] Implement recruiter filter (same approach).
- [ ] Implement tag filters.
- [ ] Implement sorting (created date and last update, ascending/descending).
- [ ] Combine filters with AND; multiple selected tags use AND.
- [ ] Keep search, filter, and sort state in the URL query string.
- [ ] Improve empty states.
- [ ] Improve responsive UI.
- [ ] Paginate the application list (25 per page).

**Acceptance criteria:**
- Users can quickly locate applications.
- Multiple filters can be combined.
- The application remains usable with many records.

> The MVP is functionally complete after Phase 6.
> Phase 7 must be completed before release to real users.

## Phase 7 — Production Readiness

- [ ] Security review.
- [ ] Tenant isolation review.
- [ ] Query performance and SQLite concurrency review (busy timeout, pool size).
- [ ] Configure the production SQLite database file on a persistent volume.
- [ ] Configure HTTPS.
- [ ] Configure logging and monitoring.
- [ ] Configure backups (SQLite online backup or Litestream) and test a restore.
- [ ] Configure deployment pipeline.
- [ ] Run end-to-end tests.
- [ ] Document deployment.

**Acceptance criteria:**
- Application deploys successfully.
- Production configuration is secure.
- Backups are configured and a restore has been tested.
- Critical workflows work in production.
- Tenant isolation tests pass.

---

## Development Rules

1. Work on one task at a time.
2. Do not mark tasks complete without implementation and verification.
3. A task is verified only when `mix format --check-formatted` and `mix test` pass (plus `mix credo` once configured).
4. Update this file whenever task progress changes.
5. Commit locally when a task group (for example 1.2 Database) is complete and verified. Use the message format `Phase N.M: <short description>`. The commit must include the TASKS.md update.
6. Never push to a remote. Never amend or rewrite earlier commits; fix problems with a new commit.
7. Never commit with failing tests. Do not leave uncommitted work at the end of a session.
8. When a phase is complete, verify its acceptance criteria, update SESSION.md, commit, and stop for review before starting the next phase.
9. Update SESSION.md before ending any session: what was done, assumptions made, blockers, and the exact next task.
10. Do not introduce features outside PRODUCT.md without explicit approval.
11. Report blockers and assumptions instead of silently making significant product decisions.
12. If the working tree has uncommitted changes you did not make, stop and ask.
