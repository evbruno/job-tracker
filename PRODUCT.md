# Job Tracker — Product Requirements

## 1. Overview

Job Tracker is a multi-user platform for managing and tracking job applications across different companies, positions, and recruiters.

It provides a centralized place to organize job opportunities, record application details, track recruitment progress, and maintain a historical record of every application status change.

## 2. Target Users

People actively looking for employment opportunities, including:
- Software engineers and developers.
- Technical and non-technical professionals.
- Freelancers and contractors.
- Professionals exploring different industries.

## 3. Core Features

### 3.1 Authentication and Users

Users authenticate using email and password.

Requirements:
- Public registration is disabled.
- Users are created through a custom Mix task.
- Users can log in and log out.
- Passwords must be securely hashed.
- Each user can only access their own data.
- Ownership must be enforced server-side.
- Email addresses are unique (case-insensitive).
- Sessions use the standard expiry provided by the Phoenix authentication generator; no custom session policy is required.
- Login rate limiting is out of scope for the initial version.

There is no administrative panel.

### 3.2 Job Applications

A job application represents an opportunity at a particular company.

Fields:
- Position/title (required, max 255 characters).
- Job description (max 20,000 characters).
- Job posting URL (must be a valid `http`/`https` URL when present).
- Company reference (required).
- Optional recruiter reference.
- Current application status.
- Relevant tags.
- Creation timestamp.
- Last updated timestamp.

Users can:
- Create applications.
- Edit application details.
- View application details.
- List and filter applications.
- Delete applications.
- Change application status.

New applications automatically receive the `Interested` status.

#### Application Deletion

Applications are hard-deleted. Deleting an application also deletes its status history and its tag associations (cascade). Companies, recruiters, and tags are never deleted as a side effect. The UI must ask for confirmation before deleting.

#### Last Updated Semantics

`updated_at` changes when:
- Application fields are edited.
- The status changes.
- Tags are added to or removed from the application.

### 3.3 Application Status

Statuses are predefined and shared by all users.

Initial statuses:

- Interested
- Applied
- Screening
- Interview
- Technical Interview
- Final Interview
- Offer
- Accepted
- Declined
- Rejected
- Withdrawn
- Failed
- On Hold

Users cannot create or customize statuses.

Implementation: statuses are stored in a `statuses` table, populated by a migration (data seeded in the migration itself so that every environment, including production and test, has them). Each status has a stable `slug` (e.g. `technical_interview`), a display `name`, and a `position` for display ordering. Applications and history records reference statuses by foreign key.

The current status must always be available directly from the application record.

#### Status Transitions

Any status can transition to any other status. There is no state machine. Changing to the same status the application already has is rejected with a validation error.

#### Status History

Every status change generates a historical record.

Each record contains:
- Previous status (nullable for initial status).
- New status.
- Change timestamp.
- Optional notes (max 2,000 characters).

Requirements:
- The initial `Interested` status generates a history record.
- Every subsequent status change generates another record.
- Historical records are append-only: they are never updated or edited through the application. They are removed only when their parent application is deleted.
- Status updates and history creation must be atomic.
- History must be displayed chronologically (oldest first).
- Users can add context to a status change through optional notes.

### 3.4 Companies

Companies represent organizations offering job opportunities.

Fields:
- Name (required, max 255 characters).
- Website URL (valid `http`/`https` URL when present).
- General contact email (valid email format when present).
- Additional notes (max 5,000 characters).
- Creation timestamp.
- Deletion timestamp (nullable).

Requirements:
- A company can be associated with multiple applications belonging to the same user.
- Users can create companies independently.
- Users can also create a company inline while creating or editing an application.
- Existing companies can be reused.
- Company names are unique per user, case-insensitive, among non-deleted companies. A user may create a new company with the same name as one of their soft-deleted companies. (Use a partial unique index on the name with `COLLATE NOCASE` where `deleted_at IS NULL`; SQLite supports both.)
- Companies have standalone pages: list, create, edit, and delete.

#### Company Deletion

Companies use soft deletion.

Deleting a company must not physically remove its database record or historical references.

Deleted companies must not appear in normal selection lists, but existing applications must retain their company association.

Additional rules:
- When viewing an application whose company is soft-deleted, the company is still displayed (marked as deleted).
- When editing such an application, the current (deleted) company remains selected and shown in the form. It is not offered as a choice for other applications. The user may switch to a different active company.
- Deleted companies can be restored from a "Deleted" view on the companies page. Restoring fails with a validation error if an active company with the same name already exists.

### 3.5 Recruiters

Recruiters represent people involved in recruitment.

Fields:
- Name (required, max 255 characters).
- Email (valid email format when present).
- LinkedIn URL (valid `http`/`https` URL when present).
- Other relevant URL (valid `http`/`https` URL when present).
- Additional notes (max 5,000 characters).
- Creation timestamp.
- Deletion timestamp (nullable).

Requirements:
- Recruiters can be associated with multiple applications belonging to the same user.
- Recruiter association is optional.
- Users can create recruiters independently.
- Users can create recruiters inline while creating or editing an application.
- Existing recruiters can be reused.
- Recruiter names are not required to be unique (different people can share a name).
- Recruiters have standalone pages: list, create, edit, and delete.

#### Recruiter Deletion

Recruiters use soft deletion.

Deleted recruiters must retain their historical references and must not appear in normal selection lists.

The same rules as company deletion apply: deleted recruiters remain visible on existing applications and in the edit form of those applications, and can be restored from a "Deleted" view.

### 3.6 Tags

Tags categorize job applications.

Examples:
- PHP
- Laravel
- Elixir
- Scala
- Backend
- Frontend
- Remote
- Contract
- Full-time
- Startup
- Senior
- Staff

Fields:
- Name (required, max 50 characters, trimmed).
- Creation timestamp.

Requirements:
- Users can create tags.
- Applications can have multiple tags.
- Tags can be reused across applications.
- Tags are isolated between users.
- Tag names are unique per user, case-insensitive. The original casing entered by the user is preserved for display. (Use a unique index on `user_id` and the name with `COLLATE NOCASE`.)
- Users can filter applications by tag.
- Tags can be created inline from the application form.
- Tags have a simple standalone management page: list, rename, and delete. Deleting a tag removes it from all applications (hard delete of the tag and its join rows; applications are unaffected).

### 3.7 Application Listing

The main application page provides a centralized view.

Requirements:
- Display position, company, current status and creation date.
- Filter by status.
- Filter by company.
- Filter by recruiter.
- Filter by tags.
- Search by position or company.
- Sort by creation date and last update.

Behavior:
- Default sort: most recently created first.
- Sort direction can be toggled (ascending/descending) for each sort field.
- Search is case-insensitive and matches partial text in position title or company name. SQLite has no `ILIKE`: use `LIKE` or `lower()`. Case-insensitivity is only guaranteed for ASCII characters, which is acceptable for the initial version.
- Multiple filters combine with AND (e.g. status AND company AND tag).
- Filtering by multiple tags uses AND: only applications having all selected tags are shown.
- Filter and search state is reflected in the URL query string so it survives refresh and can be bookmarked.
- The list is paginated (25 per page).
- Applications whose company is soft-deleted still appear in the list and in company filtering.
- The empty state (no applications, or no matches) has a clear message.

### 3.8 Application Details

The details page displays:
- Position and job description.
- Job posting URL.
- Company information.
- Recruiter information.
- Current status.
- Tags.
- Complete status history.

Users can edit application details and change status from this page.

## 4. Data Ownership and Privacy

The platform is multi-tenant.

Every user operates within an isolated data scope.

Requirements:
- Users cannot access another user's applications.
- Users cannot access another user's companies or recruiters.
- Users cannot access another user's tags.
- Users cannot modify or delete another user's records.
- Associations must validate ownership (e.g. an application cannot be linked to another user's company, recruiter, or tag, even if the ID is submitted).
- All queries and mutations must enforce ownership server-side.
- LiveView events must never trust client-provided record identifiers without authorization checks.
- Context functions take the current user (or scope) as an explicit argument; there are no unscoped "get by id" functions for user-owned records.
- Accessing another user's record behaves as "not found" (no information leak about existence).

## 5. Technical Stack

### Backend
- Elixir
- Phoenix Framework
- Phoenix LiveView
- Ecto

Use the latest stable versions of Elixir, Phoenix, and LiveView available at project start, and pin them in the repository (`.tool-versions` or equivalent).

### Database
- SQLite3 via the `ecto_sqlite3` adapter (`mix phx.new --database sqlite3`).
- The database file is never committed to Git. In production it lives on a persistent volume.
- Foreign key enforcement and WAL journal mode must be on (verify the adapter defaults in the config).
- SQLite allows one writer at a time. Keep transactions short.

### Frontend
- Phoenix LiveView
- HEEx templates
- Tailwind CSS
- Phoenix components

### Authentication
- Phoenix authentication generator or equivalent established solution.
- Email/password authentication.
- Secure password hashing.
- Session-based authentication.

### User Provisioning
- Custom Mix task for creating users (`mix users.create EMAIL`), which prompts for or accepts a password and fails clearly on duplicate emails or invalid input.
- No public registration endpoint.

### Display Conventions
- Timestamps are stored in UTC.
- Timestamps are displayed in UTC for the initial version (no per-user timezone setting).

## 6. Architecture Guidelines

- Follow Phoenix conventions.
- Use Phoenix contexts to organize business logic.
- Keep business logic out of LiveView modules.
- Use Ecto changesets for validation.
- Use database constraints where appropriate (foreign keys, unique indexes, not-null).
- Use only SQLite-compatible database features: no `ILIKE`, `citext`, arrays, or `jsonb`.
- SQLite has limited `ALTER TABLE` support, so get table definitions right before building on them.
- Enforce user ownership at the context/query level.
- Use transactions (`Ecto.Multi`) for status changes and history creation.
- Preserve historical associations through soft deletion.
- Keep migrations version-controlled.
- Prefer straightforward solutions over unnecessary abstractions.

## 7. Testing Requirements

- Every context has tests covering its main operations.
- Ownership isolation tests are mandatory: for each user-owned resource (applications, companies, recruiters, tags), tests must prove that user B cannot read, list, update, delete, or associate user A's records.
- Status change tests must verify that the application's status and the history record are created atomically (including rollback on failure).
- Soft-deletion tests must verify that deleted companies/recruiters are hidden from selection lists but remain attached to existing applications.
- Listing tests cover each filter, search, sorting, and pagination.
- Add LiveView tests for the main flows: login, create application (with inline company/recruiter/tag creation), change status with notes, and filter the list.
- `mix test` must pass before any task is considered complete.
- If tests fail with "database is locked/busy" errors, run database tests with `async: false`.

## 8. Out of Scope — Initial Version

- Public user registration.
- Administrative dashboard.
- Email integration.
- Automated job scraping.
- Resume management.
- Automated application submissions.
- Notifications and reminders.
- AI-powered job matching.
- External recruiter/company synchronization.
- Mobile applications.
- Custom user-defined statuses.
- Login rate limiting.
- Per-user timezone settings.
- Editing or deleting individual status history entries.
- Password reset and email confirmation flows (users are provisioned by the Mix task; remove or disable these generator-provided flows).

## 9. Success Criteria

The MVP is successful when a user can:

1. Log in securely.
2. Create companies and recruiters.
3. Create job applications.
4. Associate applications with companies and recruiters.
5. Create and reuse tags.
6. Change application statuses.
7. Add optional notes to status changes.
8. Review the complete status history.
9. Search, filter and sort applications.
10. Soft-delete companies and recruiters without breaking historical references.
11. Be confident that other users cannot access their information.

## 10. Confirmed Product Decisions

| Decision | Resolution |
|---|---|
| Application statuses | Predefined, stored in a seeded `statuses` table |
| Status transitions | Any status to any other; same-status change rejected |
| Company creation | Inline and standalone |
| Recruiter creation | Inline and standalone |
| Status history | Optional notes, append-only |
| Initial status | Interested |
| Company deletion | Soft delete, restorable |
| Recruiter deletion | Soft delete, restorable |
| Application deletion | Hard delete, cascades to history and tag links |
| Deleted company/recruiter on existing application | Still shown and kept selected when editing |
| Company name uniqueness | Per user, case-insensitive, among non-deleted |
| Recruiter name uniqueness | Not unique |
| Tag name uniqueness | Per user, case-insensitive |
| Tag filtering | AND across selected tags |
| Filter combination | AND |
| Search | Case-insensitive partial match on position and company name |
| Default sort | Created date, newest first |
| Pagination | Yes, 25 per page |
| `updated_at` changes on | Field edits, status changes, tag changes |
| Timestamps | Stored and displayed in UTC |
| Database | SQLite3 (`ecto_sqlite3`) |
| User provisioning | Custom Mix task |
| Public registration | Disabled |
| Admin panel | Not required |

## 11. Project Workflow

PRODUCT.md defines what to build. It does not define the order or the progress.

- `TASKS.md`: phases, task checklist, acceptance criteria, and development rules.
- `SESSION.md`: session handoff and next actions.

At the start of every session, read `SESSION.md`, then `TASKS.md`. Continue from the current task. Do not redo completed work.

## 12. Guidance for the AI Agent

- Do not add features that are not listed in this document. If something seems missing, ask instead of inventing it.
- Do not build ahead of the current phase.
- Prefer the simplest solution that satisfies the requirement. Any new dependency must be justified in a sentence.
- Keep LiveView modules thin; business logic lives in contexts.
- Never use an unscoped query for user-owned data.
- When a requirement is ambiguous, state the assumption before implementing it and record it in `SESSION.md`.
- If this document conflicts with TASKS.md, this document wins. Report the conflict instead of choosing silently.
