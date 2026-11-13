# Job Tracker — Development Roadmap

## Development Principles

- Deliver working functionality incrementally.
- Keep milestones independently testable.
- Prioritize core workflows.
- Maintain automated tests.
- Enforce tenant isolation from the beginning.
- Avoid unnecessary abstractions.

---

## Phase 1 — Project Foundation

Goal: Establish the Phoenix application and development environment.

- [ ] Generate Phoenix project with LiveView.
- [ ] Configure PostgreSQL.
- [ ] Configure Ecto.
- [ ] Configure Tailwind CSS.
- [ ] Initialize Git repository.
- [ ] Establish project structure and conventions.
- [ ] Configure environment variables.
- [ ] Configure automated testing.
- [ ] Create initial application layout.
- [ ] Verify development and test environments.

Acceptance criteria:
- Application starts locally.
- Database connection works.
- Migrations execute successfully.
- Basic LiveView page renders.
- Automated tests run successfully.

## Phase 2 — Authentication and User Isolation

Goal: Implement secure authentication and multi-user data ownership.

- [ ] Implement email/password authentication.
- [ ] Implement login and logout.
- [ ] Implement secure password hashing.
- [ ] Disable public registration.
- [ ] Implement `mix users.create` task.
- [ ] Define user ownership conventions.
- [ ] Implement ownership enforcement in contexts.
- [ ] Protect authenticated LiveView routes.
- [ ] Add authentication tests.
- [ ] Add cross-user authorization tests.

Acceptance criteria:
- Users can authenticate.
- Users can be provisioned through the Mix task.
- Public registration is unavailable.
- Unauthenticated users cannot access protected pages.
- Users cannot access or modify another user's records.

## Phase 3 — Core Domain and Database

Goal: Establish the main data model.

- [ ] Create Companies schema and migration.
- [ ] Create Recruiters schema and migration.
- [ ] Create Job Applications schema and migration.
- [ ] Create Application Status History schema and migration.
- [ ] Create Tags schema and migration.
- [ ] Create Application Tags association.
- [ ] Define Ecto associations.
- [ ] Add ownership constraints.
- [ ] Add database indexes and foreign keys.
- [ ] Implement changesets and validations.
- [ ] Implement Phoenix contexts.
- [ ] Add context-level tests.

Acceptance criteria:
- All entities can be created and retrieved.
- Associations work correctly.
- Ownership is enforced.
- Invalid records are rejected.
- Database constraints protect data integrity.

## Phase 4 — Company and Recruiter Management

Goal: Allow users to manage reusable companies and recruiters.

- [ ] Implement company listing.
- [ ] Implement company creation and editing.
- [ ] Implement company soft deletion.
- [ ] Implement recruiter listing.
- [ ] Implement recruiter creation and editing.
- [ ] Implement recruiter soft deletion.
- [ ] Hide deleted records from normal selection lists.
- [ ] Preserve references from existing applications.
- [ ] Validate ownership of associated records.
- [ ] Add tests for soft deletion and ownership.

Acceptance criteria:
- Users can manage their companies and recruiters.
- Companies and recruiters can be reused.
- Deleted records are retained in the database.
- Existing applications preserve their associations.
- Deleted entities cannot be selected for new applications.

## Phase 5 — Job Application Management

Goal: Implement the primary application workflow.

- [ ] Create application listing.
- [ ] Create application form.
- [ ] Implement application creation.
- [ ] Implement application editing.
- [ ] Implement application details page.
- [ ] Implement application deletion.
- [ ] Associate applications with companies.
- [ ] Associate applications with recruiters.
- [ ] Implement inline company creation.
- [ ] Implement inline recruiter creation.
- [ ] Implement tag creation and management.
- [ ] Implement application-tag associations.

Acceptance criteria:
- Users can create and manage applications.
- New applications default to Interested.
- Companies and recruiters can be created inline.
- Applications support multiple tags.
- Application details display associated information.

## Phase 6 — Application Status and History

Goal: Track recruitment progress and preserve status history.

- [ ] Define predefined application statuses.
- [ ] Implement initial Interested status assignment.
- [ ] Automatically create initial history record.
- [ ] Implement status transitions.
- [ ] Record previous and new statuses.
- [ ] Record timestamps.
- [ ] Support optional status change notes.
- [ ] Display chronological status history.
- [ ] Implement atomic status/history updates.
- [ ] Add tests for all status transitions.

Acceptance criteria:
- Every application has a current status.
- Every status change generates a history record.
- Historical records are immutable through normal application workflows.
- Status and history updates are atomic.
- Users can review the complete recruitment timeline.

## Phase 7 — Search, Filtering and Usability

Goal: Make managing multiple applications efficient.

- [ ] Implement application search.
- [ ] Filter by status.
- [ ] Filter by company.
- [ ] Filter by recruiter.
- [ ] Filter by tags.
- [ ] Implement sorting.
- [ ] Improve empty states.
- [ ] Improve form validation feedback.
- [ ] Add pagination if necessary.
- [ ] Improve responsive layouts.

Acceptance criteria:
- Users can quickly locate applications.
- Multiple filters can be combined.
- The application remains usable with many records.

## Phase 8 — Production Readiness

Goal: Prepare the platform for production deployment.

- [ ] Review authentication security.
- [ ] Review authorization and tenant isolation.
- [ ] Review database indexes and query performance.
- [ ] Configure production environment variables.
- [ ] Configure production database.
- [ ] Configure HTTPS.
- [ ] Add structured logging.
- [ ] Add error monitoring.
- [ ] Configure database backups.
- [ ] Configure deployment pipeline.
- [ ] Perform end-to-end testing.
- [ ] Document deployment and operational procedures.

Acceptance criteria:
- Application deploys successfully.
- Production configuration is secure.
- Backups are configured.
- Critical workflows work in production.
- Tenant isolation tests pass.

---

## MVP Definition

The MVP is functionally complete after Phase 7.

Phase 8 must be completed before production release to real users.

## Future Possibilities

These are not MVP commitments:

- Application statistics and analytics.
- Kanban-style application board.
- Custom application statuses.
- Resume and cover letter management.
- Email integration.
- Automatic status updates.
- Job posting import from URLs.
- Interview scheduling and reminders.
- Salary and compensation tracking.
- AI-assisted job description analysis.
- CSV export.

## Progress Tracking

- `ROADMAP.md`: milestone-level progress.
- `TASKS.md`: implementation-level progress.
- `SESSION.md`: session handoff and next actions.

Update this roadmap when milestone scope or completion changes.
