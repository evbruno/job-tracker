# Job Tracker — Implementation Tasks

## Current Project Status

**Current phase:** Phase 1 — Project Foundation

**Overall status:** Not started

**Current milestone:** Generate and configure the Phoenix application.

---

## Phase 1 — Project Foundation

### 1.1 Project Initialization

- [ ] Verify Elixir and Erlang/OTP versions.
- [ ] Verify Phoenix installation and version.
- [ ] Pin Elixir/Erlang versions (`.tool-versions` or equivalent).
- [ ] Generate Phoenix application with LiveView.
- [ ] Initialize Git repository.
- [ ] Create initial README.md.

### 1.2 Database

- [ ] Configure PostgreSQL connection.
- [ ] Configure development database.
- [ ] Configure test database.
- [ ] Verify Ecto connectivity.
- [ ] Verify migrations execute successfully.

### 1.3 Frontend and Layout

- [ ] Verify LiveView setup.
- [ ] Configure Tailwind CSS.
- [ ] Establish application layout.
- [ ] Create basic navigation.
- [ ] Create initial dashboard placeholder.

### 1.4 Development Standards

- [ ] Establish project coding conventions.
- [ ] Create AGENTS.md (point to PRODUCT.md, TASKS.md, SESSION.md and the development rules).
- [ ] Configure formatting.
- [ ] Configure Credo.
- [ ] Configure automated tests.
- [ ] Document local development setup.

### 1.5 Verification

- [ ] Application starts locally.
- [ ] Database connection works.
- [ ] Home page renders.
- [ ] LiveView interactions work.
- [ ] Tests execute successfully.
- [ ] Formatting checks pass.
- [ ] Initial Git commit created.

---

## Phase 2 — Authentication and User Isolation

- [ ] Implement authentication.
- [ ] Disable public registration.
- [ ] Remove password reset and email confirmation flows.
- [ ] Add a test proving no public registration route exists.
- [ ] Implement login and logout.
- [ ] Implement `mix users.create`.
- [ ] Add authenticated route protection.
- [ ] Define tenant isolation conventions.
- [ ] Add ownership authorization tests.

**Acceptance criteria:**
- Users can authenticate with email and password.
- Users can be provisioned through the Mix task.
- Public registration is unavailable.
- Password reset and email confirmation flows are unavailable.
- Unauthenticated users cannot access protected pages.
- Users cannot access or modify another user's records.

## Phase 3 — Core Domain

- [ ] Implement Company schema.
- [ ] Implement Recruiter schema.
- [ ] Implement JobApplication schema.
- [ ] Implement ApplicationStatusHistory schema.
- [ ] Implement Status schema and seed the 13 predefined statuses in a migration.
- [ ] Implement Tag schema.
- [ ] Implement ApplicationTag association.
- [ ] Add database constraints and indexes.
- [ ] Add uniqueness indexes: company names (case-insensitive, per user, non-deleted only) and tag names (case-insensitive, per user).
- [ ] Implement Phoenix contexts.
- [ ] Add domain tests.

**Acceptance criteria:**
- All entities can be created and retrieved.
- Associations work correctly.
- Ownership is enforced.
- Invalid records are rejected.
- Database constraints protect data integrity.

## Phase 4 — Company and Recruiter Management

- [ ] Implement company CRUD.
- [ ] Implement recruiter CRUD.
- [ ] Implement company soft deletion.
- [ ] Implement recruiter soft deletion.
- [ ] Preserve historical associations.
- [ ] Show soft-deleted company/recruiter on existing applications and keep it selected in the edit form.
- [ ] Implement restore of soft-deleted companies and recruiters ("Deleted" view).
- [ ] Add ownership and deletion tests.

**Acceptance criteria:**
- Users can manage their companies and recruiters.
- Companies and recruiters can be reused.
- Deleted records are retained in the database and can be restored.
- Existing applications preserve their associations.
- Deleted entities cannot be selected for new applications.

## Phase 5 — Job Application Management

- [ ] Implement application listing.
- [ ] Implement application creation.
- [ ] Implement application editing.
- [ ] Implement application details.
- [ ] Implement application deletion.
- [ ] Implement inline company creation.
- [ ] Implement inline recruiter creation.
- [ ] Implement inline tag creation from the application form.
- [ ] Implement standalone tag management page (list, rename, delete).
- [ ] Implement application-tag associations.

**Acceptance criteria:**
- Users can create and manage applications.
- New applications default to Interested.
- Companies and recruiters can be created inline.
- Applications support multiple tags.
- Application details display associated information.

## Phase 6 — Application Status and History

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

## Phase 7 — Search and Usability

- [ ] Implement search.
- [ ] Implement status filters.
- [ ] Implement company filters.
- [ ] Implement recruiter filters.
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

> The MVP is functionally complete after Phase 7.
> Phase 8 must be completed before release to real users.

## Phase 8 — Production Readiness

- [ ] Security review.
- [ ] Tenant isolation review.
- [ ] Query performance review.
- [ ] Configure production database.
- [ ] Configure HTTPS.
- [ ] Configure logging and monitoring.
- [ ] Configure backups.
- [ ] Configure deployment pipeline.
- [ ] Run end-to-end tests.
- [ ] Document deployment.

**Acceptance criteria:**
- Application deploys successfully.
- Production configuration is secure.
- Backups are configured.
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
