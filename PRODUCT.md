# Job Tracker — Product Requirements

## 1. Overview

Job Tracker is a multi-user platform for managing and tracking job applications across different companies, positions, and recruiters.

It provides a centralized place to organize job opportunities, record application details, track recruitment progress, maintain a historical record of every application status change, and keep multiple resume versions ready for each application.

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
- Company name (required, plain text, max 255 characters).
- Recruiter name (optional, plain text, max 255 characters).
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

#### Company and Recruiter Fields

Company and recruiter are plain text columns on the application. There are no separate company or recruiter records, pages, or deletion rules.

- Values are trimmed. A blank recruiter is stored as `NULL`.
- The form suggests values the user has previously entered (for example with an HTML `datalist`), so names can be reused without retyping. Suggestions come only from the current user's own applications.
- Changing the value on one application does not affect any other application.

#### Application Deletion

Applications are hard-deleted. Deleting an application also deletes its status history and its tag associations (cascade). Tags are never deleted as a side effect. The UI must ask for confirmation before deleting.

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

### 3.4 Tags

Tags categorize job applications and resumes.

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
- Applications and resumes can have multiple tags.
- Tags can be reused across applications and resumes.
- Tags are isolated between users.
- Tag names are unique per user, case-insensitive. The original casing entered by the user is preserved for display. (Use a unique index on `user_id` and the name with `COLLATE NOCASE`.)
- Users can filter applications by tag.
- Tags can be created inline from the application form and the resume form.
- Tags have a simple standalone management page: list, rename, and delete. Deleting a tag removes it from all applications and resumes (hard delete of the tag and its join rows; applications and resumes are unaffected).

### 3.5 Application Listing

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
- The company and recruiter filters are dropdowns populated with the distinct values from the user's own applications. They match case-insensitively.
- The empty state (no applications, or no matches) has a clear message.

### 3.6 Application Details

The details page displays:
- Position and job description.
- Job posting URL.
- Company name.
- Recruiter name (if any).
- Current status.
- Tags.
- Complete status history.

Users can edit application details and change status from this page.

### 3.7 Resumes

A resume is a user-owned CV version. Users keep many resumes at once. Each resume is an independent record identified by its title; there is no parent/version chain, version comparison, or default resume flag.

Fields:
- Title (required, max 255 characters), for example `Backend — 2026`.
- Body (required, plain text, max 50,000 characters). Line breaks are preserved when displayed.
- Email (required, valid email address, max 255 characters). Prefilled with the signed-in user's email when a resume is created; the user may change it.
- Full name (optional, max 255 characters).
- Headline (optional, max 255 characters), for example `Senior backend engineer`.
- Phone (optional, max 50 characters).
- Location (optional, max 255 characters).
- LinkedIn URL (optional, absolute `http`/`https` URL).
- GitHub URL (optional, absolute `http`/`https` URL).
- Portfolio URL (optional, absolute `http`/`https` URL).
- Relevant tags.
- Creation timestamp.
- Last updated timestamp.

Users can:
- Create resumes. The create form prefills the email from the current user's account.
- Edit resume details.
- View resume details.
- List their own resumes, most recently updated first.
- Delete resumes. The UI must ask for confirmation before deleting.

#### Resume Tags

Resumes share the existing user-owned tag vocabulary with applications. Tags can be selected from the user's existing tags or created inline with a comma-separated input, reusing an existing name case-insensitively. A tag created from a resume is available to applications and vice versa. Deleting a tag removes it from resumes and applications without deleting either.

#### Resume Validation and Storage

- Text values are trimmed. Optional blank text fields and blank URLs are stored as `NULL`.
- The email must contain an `@` sign, have no spaces, commas, or semicolons, and be at most 255 characters.
- URL fields must be absolute `http`/`https` URLs with a host when present.
- URLs are rendered only through the safe URL helper. The body is escaped and displayed with its line breaks preserved.
- `updated_at` changes when resume fields are edited or tags are added or removed.

#### Resume Deletion

Resumes are hard-deleted together with their tag links (cascade). Tags are never deleted as a side effect.

Linking resumes to applications, file uploads or attachments, PDF generation, version comparison, and default/primary resumes are out of scope for this version.

### 3.8 MCP Access

The application exposes its application and resume functionality as a Model
Context Protocol (MCP) server so other agents can use it.

- Endpoint: Streamable HTTP at `/mcp`, served by the same Phoenix endpoint.
- Authentication: per-user personal access tokens sent as
  `Authorization: Bearer tmj_<prefix>_<secret>`. Tokens are created, listed, and
  revoked with `mix mcp.tokens.create|list|revoke`. Only a SHA-256 hash and a
  public prefix are stored; the plaintext is shown once.
- Transport: Streamable HTTP only (no stdio). Origin validation rejects
  browser-based DNS-rebinding attempts.
- Tool surface: full CRUD for applications and resumes, plus read-only
  `account_get`, `tags_list`, and `statuses_list`. Each tool acts only on the
  token owner's records; another user's identifiers behave as not found.
- Ownership rules from section 4 apply unchanged: every tool derives the
  `%Scope{}` from the authenticated token, re-fetches records through scoped
  context functions, validates submitted tag ids against the owner, and never
  trusts a client-supplied `user_id`.
- Destructive tools (`applications_delete`, `resumes_delete`) are marked
  `destructiveHint` and require an explicit record id; there are no bulk
  operations.
- Tokens can also be managed in the web UI at `/mcp-tokens`: list the signed-in
  user's tokens, create one (the plaintext is shown once), and revoke one with
  confirmation. The plaintext is never retrievable afterwards.

## 4. Data Ownership and Privacy

The platform is multi-tenant.

Every user operates within an isolated data scope.

Requirements:
- Users cannot access another user's applications.
- Users cannot access another user's tags.
- Users cannot access another user's resumes.
- Users cannot modify or delete another user's records.
- Associations must validate ownership (e.g. an application or resume cannot be linked to another user's tag, even if the ID is submitted).
- All queries and mutations must enforce ownership server-side.
- LiveView events must never trust client-provided record identifiers without authorization checks.
- Context functions take the current user (or scope) as an explicit argument; there are no unscoped "get by id" functions for user-owned records.
- MCP personal access tokens are user-owned: another user's token cannot be listed, revoked, or used to access that user's data. Token verification is an authentication lookup that derives a `%Scope{}`; it is never used as a domain ownership check.
- Accessing another user's record behaves as "not found" (no information leak about existence).

## 5. Technical Stack

### Backend
- Elixir
- Phoenix Framework
- Phoenix LiveView
- Ecto
- Phantom MCP (`phantom_mcp`) for the MCP Streamable HTTP transport.

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
- Personal access tokens for MCP clients: SHA-256 hashed, revocable, expirable, created through `mix mcp.tokens.*`.

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
- Keep migrations version-controlled.
- Prefer straightforward solutions over unnecessary abstractions.

## 7. Testing Requirements

- Every context has tests covering its main operations.
- Ownership isolation tests are mandatory: for each user-owned resource (applications, tags, and resumes), tests must prove that user B cannot read, list, update, delete, or associate user A's records.
- Status change tests must verify that the application's status and the history record are created atomically (including rollback on failure).
- Company and recruiter tests must verify that values are trimmed, a blank recruiter is stored as `NULL`, suggestions and filters only use the current user's values, and filters match case-insensitively.
- Listing tests cover each filter, search, sorting, and pagination.
- Resume tests cover the email prefill, validation (title, body, email, URLs), tag creation and reuse, ordering, deletion cascades, and cross-user isolation.
- MCP tests cover token creation, hashing, expiry, revocation, cross-user token isolation, authentication challenges, tool CRUD for applications and resumes, tag ownership validation, status history, and the predefined status list.
- Add LiveView tests for the main flows: login, create application (with company, recruiter, and inline tag creation), change status with notes, create and edit a resume with tags, and filter the list.
- `mix test` must pass before any task is considered complete.
- If tests fail with "database is locked/busy" errors, run database tests with `async: false`.

## 8. Out of Scope — Initial Version

- Public user registration.
- Administrative dashboard.
- Email integration.
- Automated job scraping.
- Automated application submissions.
- Notifications and reminders.
- AI-powered job matching.
- External recruiter/company synchronization.
- Mobile applications.
- Custom user-defined statuses.
- Separate company and recruiter records, pages, and soft deletion (they are plain fields on the application).
- Login rate limiting.
- Per-user timezone settings.
- Editing or deleting individual status history entries.
- Resume file uploads, PDF generation, version comparison, and linking resumes to applications.
- Password reset and email confirmation flows (users are provisioned by the Mix task; remove or disable these generator-provided flows).
- OAuth 2.1 authorization, dynamic client registration, and stdio transport for the MCP endpoint (personal access tokens and Streamable HTTP only).

## 9. Success Criteria

The MVP is successful when a user can:

1. Log in securely.
2. Create job applications with a company and an optional recruiter.
3. Create and reuse tags.
4. Change application statuses.
5. Add optional notes to status changes.
6. Review the complete status history.
7. Search, filter and sort applications.
8. Create, edit, and delete multiple resume versions with tags.
9. Be confident that other users cannot access their information.
10. Manage applications and resumes through the MCP endpoint with a personal access token, without affecting other users' data.

## 10. Confirmed Product Decisions

| Decision | Resolution |
|---|---|
| Application statuses | Predefined, stored in a seeded `statuses` table |
| Status transitions | Any status to any other; same-status change rejected |
| Status history | Optional notes, append-only |
| Initial status | Interested |
| Company and recruiter | Plain text columns on the application; no separate tables |
| Company/recruiter filters | Dropdown of the user's existing values, case-insensitive |
| Application deletion | Hard delete, cascades to history and tag links |
| Tag name uniqueness | Per user, case-insensitive |
| Tag filtering | AND across selected tags |
| Filter combination | AND |
| Search | Case-insensitive partial match on position and company name |
| Default sort | Created date, newest first |
| Pagination | Yes, 25 per page |
| Resume versions | Many independent resumes per user; no version chain or default resume |
| Resume email | Prefilled from the signed-in user's email; editable and required |
| Resume tags | Shared with applications; inline creation supported |
| Resume deletion | Hard delete, cascades to tag links |
| Resume listing | Most recently updated first; no filters or pagination in this version |
| Resume extras | Full name, headline, phone, and location are optional fields |
| Resume scope | Text only; no file uploads, PDF generation, or application links |
| MCP endpoint | Streamable HTTP at `/mcp` |
| MCP authentication | Per-user personal access tokens, SHA-256 hashed, revocable and expirable |
| MCP transport library | Phantom MCP (`phantom_mcp`) |
| MCP deletes | Hard delete, explicit single id, marked destructive |
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
