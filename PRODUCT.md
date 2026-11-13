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

There is no administrative panel.

### 3.2 Job Applications

A job application represents an opportunity at a particular company.

Fields:
- Position/title (required).
- Job description.
- Job posting URL.
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

The current status must always be available directly from the application record.

#### Status History

Every status change generates a historical record.

Each record contains:
- Previous status (nullable for initial status).
- New status.
- Change timestamp.
- Optional notes.

Requirements:
- The initial `Interested` status generates a history record.
- Every subsequent status change generates another record.
- Historical records must never be overwritten.
- Status updates and history creation must be atomic.
- History must be displayed chronologically.
- Users can add context to a status change through optional notes.

### 3.4 Companies

Companies represent organizations offering job opportunities.

Fields:
- Name (required).
- Website URL.
- General contact email.
- Additional notes.
- Creation timestamp.
- Deletion timestamp (nullable).

Requirements:
- A company can be associated with multiple applications belonging to the same user.
- Users can create companies independently.
- Users can also create a company inline while creating or editing an application.
- Existing companies can be reused.

#### Company Deletion

Companies use soft deletion.

Deleting a company must not physically remove its database record or historical references.

Deleted companies must not appear in normal selection lists, but existing applications must retain their company association.

### 3.5 Recruiters

Recruiters represent people involved in recruitment.

Fields:
- Name (required).
- Email.
- LinkedIn URL.
- Other relevant URL.
- Additional notes.
- Creation timestamp.
- Deletion timestamp (nullable).

Requirements:
- Recruiters can be associated with multiple applications belonging to the same user.
- Recruiter association is optional.
- Users can create recruiters independently.
- Users can create recruiters inline while creating or editing an application.
- Existing recruiters can be reused.

#### Recruiter Deletion

Recruiters use soft deletion.

Deleted recruiters must retain their historical references and must not appear in normal selection lists.

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

Requirements:
- Users can create tags.
- Applications can have multiple tags.
- Tags can be reused across applications.
- Tags are isolated between users.
- Users can filter applications by tag.

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
- Associations must validate ownership.
- All queries and mutations must enforce ownership server-side.
- LiveView events must never trust client-provided record identifiers without authorization checks.

## 5. Technical Stack

### Backend
- Elixir
- Phoenix Framework
- Phoenix LiveView
- Ecto

### Database
- PostgreSQL

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
- Custom Mix task for creating users.
- No public registration endpoint.

## 6. Architecture Guidelines

- Follow Phoenix conventions.
- Use Phoenix contexts to organize business logic.
- Keep business logic out of LiveView modules.
- Use Ecto changesets for validation.
- Use database constraints where appropriate.
- Enforce user ownership at the context/query level.
- Use transactions for status changes and history creation.
- Preserve historical associations through soft deletion.
- Keep migrations version-controlled.
- Prefer straightforward solutions over unnecessary abstractions.

## 7. Out of Scope — Initial Version

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

## 8. Success Criteria

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

## 9. Confirmed Product Decisions

| Decision | Resolution |
|---|---|
| Application statuses | Predefined |
| Company creation | Inline and standalone |
| Recruiter creation | Inline and standalone |
| Status history | Optional notes |
| Initial status | Interested |
| Company deletion | Soft delete |
| Recruiter deletion | Soft delete |
| User provisioning | Custom Mix task |
| Public registration | Disabled |
| Admin panel | Not required |
