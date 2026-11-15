# Job Tracker — Implementation Tasks

## Current Project Status

**Current phase:** Phase 4 — Job Application Management

**Overall status:** Phase 3 complete — ready for Phase 4

**Current milestone:** Phase 3 verified; next implement application listing.

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
- [ ] Implement inline tag creation from the application form.
- [ ] Implement standalone tag management page (list, rename, delete).
- [ ] Implement application-tag associations.

**Acceptance criteria:**
- Users can create and manage applications.
- New applications default to Interested.
- Company and recruiter are plain text fields with suggestions from the user's earlier entries.
- Applications support multiple tags.
- Application details display associated information.

## Phase 5 — Application Status and History

- [ ] Wire the seeded statuses (Phase 3) to applications and history.
- [ ] Set Interested as the default status.
- [ ] Create initial history record.
- [ ] Implement status transitions (any status to any other).
- [ ] Reject a change to the same status.
- [ ] Implement optional status notes.
- [ ] Implement transactional status updates.
- [ ] Display application timeline.
- [ ] Add status history tests.

**Acceptance criteria:**
- Every application has a current status.
- Every status change generates a history record.
- History records are append-only and removed only when their application is deleted.
- Status and history updates are atomic.
- Users can review the complete recruitment timeline.

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
