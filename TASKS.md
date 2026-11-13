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
- [ ] Create AGENTS.md.
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
- [ ] Implement login and logout.
- [ ] Implement `mix users.create`.
- [ ] Add authenticated route protection.
- [ ] Define tenant isolation conventions.
- [ ] Add ownership authorization tests.

## Phase 3 — Core Domain

- [ ] Implement Company schema.
- [ ] Implement Recruiter schema.
- [ ] Implement JobApplication schema.
- [ ] Implement ApplicationStatusHistory schema.
- [ ] Implement Tag schema.
- [ ] Implement ApplicationTag association.
- [ ] Add database constraints and indexes.
- [ ] Implement Phoenix contexts.
- [ ] Add domain tests.

## Phase 4 — Company and Recruiter Management

- [ ] Implement company CRUD.
- [ ] Implement recruiter CRUD.
- [ ] Implement company soft deletion.
- [ ] Implement recruiter soft deletion.
- [ ] Preserve historical associations.
- [ ] Add ownership and deletion tests.

## Phase 5 — Job Application Management

- [ ] Implement application listing.
- [ ] Implement application creation.
- [ ] Implement application editing.
- [ ] Implement application details.
- [ ] Implement application deletion.
- [ ] Implement inline company creation.
- [ ] Implement inline recruiter creation.
- [ ] Implement tag management.
- [ ] Implement application-tag associations.

## Phase 6 — Application Status and History

- [ ] Define predefined statuses.
- [ ] Set Interested as the default status.
- [ ] Create initial history record.
- [ ] Implement status transitions.
- [ ] Implement optional status notes.
- [ ] Implement transactional status updates.
- [ ] Display application timeline.
- [ ] Add status history tests.

## Phase 7 — Search and Usability

- [ ] Implement search.
- [ ] Implement status filters.
- [ ] Implement company filters.
- [ ] Implement recruiter filters.
- [ ] Implement tag filters.
- [ ] Implement sorting.
- [ ] Improve empty states.
- [ ] Improve responsive UI.
- [ ] Add pagination if necessary.

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

---

## Development Rules

1. Work on one task at a time.
2. Do not mark tasks complete without implementation and verification.
3. Update this file whenever task progress changes.
4. Keep ROADMAP.md synchronized with milestone progress.
5. Update SESSION.md before ending a development session.
6. Commit meaningful, verified changes to Git.
7. Do not introduce features outside PRODUCT.md without explicit approval.
8. Report blockers and assumptions instead of silently making significant product decisions.
