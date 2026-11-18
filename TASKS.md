# Job Tracker — Implementation Tasks

## Current Project Status

**Current phase:** Phase 11 — Application Budget Range (complete; awaiting review)

**Overall status:** Phases 1–11 complete in the repository. Phase 11 adds an
optional budget range (minimum and maximum in whole units) to job applications.

**Current milestone:** Phase 11 verified — budget range on applications.

**Current task group:** Phase 11, complete.

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

- [x] Implement search (use `LIKE` or `lower()`; SQLite has no `ILIKE`).
- [x] Implement status filters.
- [x] Implement company filter (dropdown of the user's existing values, case-insensitive match).
- [x] Implement recruiter filter (same approach).
- [x] Implement tag filters.
- [x] Implement sorting (created date and last update, ascending/descending).
- [x] Combine filters with AND; multiple selected tags use AND.
- [x] Keep search, filter, and sort state in the URL query string.
- [x] Improve empty states.
- [x] Improve responsive UI.
- [x] Paginate the application list (25 per page).

**Acceptance criteria:**
- Users can quickly locate applications.
- Multiple filters can be combined.
- The application remains usable with many records.

> The MVP is functionally complete after Phase 6.
> Phase 7 must be completed before release to real users.

**Phase 6 completion notes:**
- `TrackMyJobEx.JobApplications` owns the listing query through
  `list_applications_filtered/2`, which returns `:entries`, `:total_count`,
  `:page`, `:total_pages`, `:page_size`, `:filters`, and `:filtered?`.
  `normalize_filters/2` and `filter_options/1` support the LiveView without
  duplicating filtering rules, and `page_size/0` exposes the 25-per-page
  constant.
- URL parameter contract: `q` (search), `status` (status slug), `company`,
  `recruiter`, `tags[]` (tag ids), `sort` (`created` or `updated`),
  `direction` (`asc` or `desc`), and `page`. Defaults (`created`, `desc`, page 1)
  and blank values are omitted from generated URLs. Unknown values fall back to
  the defaults, and malformed pages clamp to the valid range.
- Search uses `lower(...) LIKE ? ESCAPE '\'` against position and company name.
  `%`, `_`, and `\` in the search term are escaped so they match literally.
  Status filtering uses the status slug; company and recruiter filters match
  the dropdown value case-insensitively and exactly.
- Multiple filters combine with `AND`. Multiple tags also use `AND`: the query
  groups tag links by application and requires the link count to equal the
  number of selected tags. Tag ids are filtered through the current user's tags
  first, so another user's ids are ignored rather than widening results.
- Sorting is whitelisted (created date or last update, ascending or descending)
  with an `id` tiebreaker for deterministic pagination. Pagination uses
  `limit`/`offset` with 25 per page, and a page beyond the last page resolves to
  the last page.
- `ApplicationLive.Index` stays thin: `handle_params/3` loads the current query
  state, filter changes and sort-direction toggles `push_patch` to canonical
  URLs, and the template uses `<.link patch={...}>` for pagination and clearing
  filters. Company/recruiter/status/tag options come from the context and are
  limited to the current user.
- Empty states are distinct: `#applications-empty` (no applications yet, with a
  create call to action) and `#applications-no-matches` (filters are active but
  nothing matches, with a clear-filters action). The filter bar is hidden when
  the user has no applications at all.
- The filter bar, list rows, summary, and pagination use responsive Tailwind
  classes (single column on small screens, multi-column on larger ones). No new
  dependencies or Tailwind configuration were added.
- Phase 6 added 28 tests (231 total): context tests for search, wildcard
  escaping, each filter, combined filters, tag AND semantics, dropdown values,
  sorting in both directions and both fields, pagination boundaries and
  clamping, invalid parameter handling, and cross-user isolation; LiveView tests
  for searching, each filter, tag AND filtering, sorting toggles, pagination
  navigation, URL-restored state, deletion under active filters, and both empty
  states. `mix precommit` passes.

## Phase 7 — Production Readiness

- [x] Security review. Findings and accepted risks are recorded in
  `docs/SECURITY.md`; cookie flags, HSTS, URL safety, and dependency audit were
  verified.
- [x] Tenant isolation review. Every user-owned context function takes a
  `%Scope{}` and the resource × operation matrix is in `docs/SECURITY.md`.
- [x] Query performance and SQLite concurrency review (busy timeout, pool size).
  `EXPLAIN QUERY PLAN` confirms index-backed listing, filter, history, and tag
  queries; production WAL/foreign-key/busy-timeout/pool settings are documented.
- [x] Configure the production SQLite database file on a persistent volume.
  `DATABASE_PATH`/`DATA_DIR`, parent-directory creation, and WAL sidecar
  handling are implemented and verified against a temporary production path.
  Physical volume provisioning and permissions remain operator-only.
- [x] Configure HTTPS. `force_ssl`, HSTS, proxy-header handling, and secure
  cookies are configured and verified on a production release. DNS and the TLS
  certificate remain operator-only.
- [x] Configure logging and monitoring. Production logging is `:info` with
  request ids and no SQL parameters; `GET /health` returns `200 ok` or
  `503 unavailable`. External log aggregation and alerting remain operator-only.
- [x] Configure backups (SQLite online backup) and test a restore.
  `scripts/backup_sqlite.sh` and `scripts/restore_sqlite.sh` use `sqlite3
  .backup`; a seeded backup was restored with matching counts, matching schema,
  and `integrity_check: ok`. Scheduling, encryption, and off-site copies remain
  operator-only.
- [x] Configure deployment pipeline. A hardened multi-stage Dockerfile, release
  scripts, and GitHub Actions CI (format, warnings-as-errors, Credo, tests) are
  in place. Publishing and deploying to a real environment remain operator-only.
- [x] Run end-to-end tests. `test/track_my_job_ex_web/end_to_end_test.exs` drives
  login, create with tags, status/history, filters, pagination, sorting,
  cross-user isolation, and delete cascades through the real router/LiveViews.
- [x] Document deployment. `docs/DEPLOYMENT.md` covers prerequisites,
  environment variables, release/Docker builds, migrations, persistent storage,
  HTTPS, health, logging, backups with verified restore output, rollback, CI,
  and the operator checklist.

**Acceptance criteria:**
- Application deploys successfully. (Verified locally as a production release
  boot; a real environment deploy requires operator credentials and DNS.)
- Production configuration is secure. (Cookie flags, force_ssl, HSTS, secrets
  handling, and non-root container verified.)
- Backups are configured and a restore has been tested. (Scripted and verified
  locally; scheduling/off-site storage is operator-only.)
- Critical workflows work in production. (End-to-end test plus production
  release boot.)
- Tenant isolation tests pass. (Cross-user read/list/update/delete/associate
  tests pass for applications, tags, history, and tag links.)

**Phase 7 completion notes:**
- Security: production session and remember-me cookies set `HttpOnly`,
  `Secure`, and `SameSite=Lax`; `force_ssl` uses `X-Forwarded-Proto`, one-year
  HSTS, and excludes `/health` and localhost. Job URLs render only through
  `Formatters.safe_http_url/1`. Database files, sidecars, `.env*`, backups, and
  release artifacts are gitignored. `mix hex.audit` reports no retired or
  advisory packages.
- Tenant isolation: every user-owned query is scoped through
  `current_scope.user.id`; there are no unscoped application/tag getters.
  Association ids are re-fetched through the scope before linking and roll back
  on failure. `docs/SECURITY.md` contains the full resource × operation matrix
  and test locations.
- SQLite/performance: production uses WAL, foreign keys, a 5-second busy
  timeout, pool size 5, and `queue_target: 50`/`queue_interval: 1000`.
  Migration `20261116130000` adds `(user_id, status_id)`,
  `(user_id, recruiter_name)`, `(user_id, inserted_at)`, `(user_id, updated_at)`,
  NOCASE company/recruiter indexes, `(application_id, changed_at)` history, and
  `(tag_id, application_id)` tag-link indexes. Company/recruiter filters now use
  `COLLATE NOCASE`, and `EXPLAIN QUERY PLAN` confirms index use for listing,
  filters, search, history, tag links, suggestions, and the tag AND filter.
- Production storage: `DATABASE_PATH` defaults to
  `${DATA_DIR:-/data}/track_my_job_ex/track_my_job_ex.db`; its parent directory
  is created on boot. The release was booted against a temporary production path
  and served `/health` with `200 ok`.
- Backups: online `sqlite3 .backup` scripts verify `PRAGMA integrity_check` and
  checkpoint the copy. A seeded backup was restored to a separate path;
  users=1, applications=1, history=1, tags=1, tag links=1, statuses=13, with a
  matching schema and `integrity_check: ok`.
- Deployment: `mix phx.gen.release --docker` scaffolding plus
  `TrackMyJobEx.Release.migrate/0`, `bin/migrate`, and `bin/server`. The
  Dockerfile is multi-stage, runs as `nobody`, and uses `tini`. GitHub Actions
  runs formatting, warnings-as-errors compilation, Credo strict, and the full
  test suite. `MIX_ENV=prod mix release` builds and boots successfully.
- Testing: Phase 7 added 10 tests (241 total, up from 231), covering health,
  safe URL schemes, session cookie flags, cross-user tag association/filter
  isolation, and a full end-to-end workflow. `mix precommit` passes.
- Operator blockers: real domain/DNS/TLS, persistent volume provisioning and
  permissions, production secrets, external monitoring/log aggregation, and
  scheduled/off-site/encrypted backups. See `docs/DEPLOYMENT.md`.

---

## UI Refresh (post-Phase 7)

Presentation-only refresh; no product scope or behavior change.

- [x] Audit every screen and agree on the design direction (palette, type,
  status families, layout).
- [x] Add design tokens, a single light theme, and the app shell.
- [x] Refresh the application list, details, create/edit form, tag page, login,
  and dashboard.
- [x] Replace native confirmation dialogs with accessible modals.
- [x] Validate every screen at a 390px-wide viewport and run `mix precommit`.

**Notes:** The generator's theme toggle and dark theme were removed in favour of
one light theme. Tag filters and the form tag picker are checkbox chips with the
same container ids. Confirmation is now a two-step modal flow. Contexts, schemas,
migrations, URL contracts, ownership rules, and flash strings are unchanged. See
`SESSION.md` for the design tokens, status families, and per-screen summary.

---

## Phase 8 — Resume Management

- [x] Add `resumes` and `resume_tags` tables with foreign keys, cascades, and indexes.
- [x] Implement the `Resume` schema and validation (title, body, email, optional contact fields, URLs).
- [x] Implement the scoped `Resumes` context with email prefill, CRUD, and tag associations.
- [x] Implement the resume listing (most recently updated first).
- [x] Implement resume creation and editing with existing and inline tags.
- [x] Implement resume details with safe links and confirmation-gated deletion.
- [x] Add Resumes navigation and dashboard entry, and update tag deletion copy/cascades.
- [x] Add a Mix task that creates a simple resume for an existing user.
- [x] Add context, isolation, and LiveView tests; document the phase.

**Acceptance criteria:**
- Users can keep many independent resumes, each with a title and timestamps.
- New resumes prefill the email from the signed-in user's account; the value stays editable.
- Resume tags reuse the existing per-user tag vocabulary, support inline creation, and validate ownership.
- Resume list, details, edit, and delete flows work and are owner-scoped.
- Cross-user reads, lists, updates, deletes, and tag associations behave as not found or are rejected.
- `mix precommit` passes and the suite grows to cover the new resource.

**Phase 8 completion notes:**
- Data model: `resumes` stores the title, body, email, optional full name,
  headline, phone, and location, the three optional URLs, `user_id`, and
  timestamps. `resume_tags` joins resumes to the existing `tags` table with
  `(resume_id, tag_id)` uniqueness, cascades on both sides, and a
  `(tag_id, resume_id)` lookup index.
- Context: `TrackMyJobEx.Resumes` takes `%Scope{}` first everywhere, scopes
  reads and writes by `scope.user.id`, and supports list/get/get!/create/
  create-with-tags/change/update/update-with-tags/set-tags/delete and
  `list_resume_tags/2`. `new_resume_changeset/2` assigns the owner and prefills
  the email from the signed-in user; a client `user_id` is never cast.
- Tags: resumes reuse `TrackMyJobEx.Tags` through the same fetch/reuse/validate
  rules as applications. Selecting another user's tag id or an invalid id rolls
  back the resume and its tag links. Inline names reuse an existing tag
  case-insensitively and keep its original casing.
- Validation: title (255), body (50,000), and email (255) are required; the
  email uses the authentication regex (an `@`, no spaces/commas/semicolons).
  Optional text and URLs are trimmed, blank values become `NULL`, and the three
  URLs require an absolute `http`/`https` URL with a host.
- UI: `ResumeLive.Index/New/Edit/Show` under the protected `live_session`, plus
  the shared `ResumeForm`. The index orders by most recently updated and shows
  title, name/headline, tags, and the updated timestamp. Details render the body
  with preserved line breaks, contact values, safe links, tags, and timestamps,
  and delete through the existing confirmation modal. Navigation and the
  dashboard link to Resumes; the tag page now states that deletion affects
  applications and resumes.
- Tests: Phase 8 added 47 tests (295 total): 25 context/isolation tests, 15
  LiveView tests, and 7 Mix task tests, covering prefill, validation, tag
  creation/reuse and rollback, ordering, list/isolation, edit, safe links, the
  confirmation-gated delete, and CLI resume creation. `mix precommit` passes.
- Mix task: `mix resumes.create EMAIL [--title TITLE]` resolves an existing user
  through `Accounts.get_user_by_email/1`, derives ownership with
  `Scope.for_user/1`, and creates a simple resume through the scoped context.
  The email is prefilled from the account and the body starts as a short
  editable outline. Unknown users, blank titles, and invalid arguments fail with
  a clear message and a non-zero exit status.
- Deliberately not done: no application links, file uploads, PDF generation,
  version chains, version comparison, default resume flag, filters, or
  pagination for resumes.

## Phase 9 — MCP Server

- [x] 9.1 Add `phantom_mcp` dependency, MIME `sse` type, `:mcp` pipeline, and
  `/mcp` route forwarding to `Phantom.Plug`.
- [x] 9.2 Add `mcp_tokens` table, `TrackMyJobEx.Accounts.MCPToken` schema, and
  scoped create/list/get/revoke plus global verification in `Accounts`.
- [x] 9.3 Add `mix mcp.tokens.create|list|revoke` tasks.
- [x] 9.4 Implement `connect/2` authentication and tenant scope derivation.
- [x] 9.5 Implement read tools: `applications_list`, `applications_get`,
  `applications_status_history`, `resumes_list`, `resumes_get`, `tags_list`,
  `statuses_list`.
- [x] 9.6 Implement application write tools: `applications_create`,
  `applications_update`, `applications_delete`, `applications_change_status`.
- [x] 9.7 Implement resume write tools: `resumes_create`, `resumes_update`,
  `resumes_delete`.
- [x] 9.8 Add context, auth, tool, and Mix task tests; update docs.

**Acceptance criteria:**
- An MCP client authenticates with `Authorization: Bearer tmj_<prefix>_<secret>`.
- Unauthenticated or invalid requests return 401 with a `WWW-Authenticate`
  challenge; disallowed browser origins return 403.
- All 14 tools operate only on the token owner's records; another user's ids
  behave as not found.
- Application status changes append history atomically.
- Tag ids are validated against the owner; inline names reuse existing tags.
- `mix precommit` passes.

**Phase 9 completion notes:**
- Dependency: `phantom_mcp ~> 0.8.0` (MIT) plus `uuid_v7` (transitive),
  justified by the MCP framing/transport. `Phantom.Tracker` added to the
  application supervision tree.
- Data model: `mcp_tokens` stores `name`, `token_prefix` (unique), `token_hash`
  (SHA-256, 32 bytes), `last_used_at`, `expires_at`, `user_id` (FK cascade),
  and timestamps. Plaintext is never stored.
- Context: `TrackMyJobEx.Accounts` owns `create_mcp_token/2`, `list_mcp_tokens/1`,
  `get_mcp_token/2`, `revoke_mcp_token/2`, and the global
  `get_user_by_mcp_token/1` authentication lookup. `last_used_at` is refreshed
  at most once every five minutes.
- Router: `TrackMyJobExWeb.MCP.Router` uses `Phantom.Router` with 15 tools (including
  `account_get`) and `connect/2` returning `{:unauthorized, %{...}}` for bad
  credentials. Tools live in `TrackMyJobExWeb.MCP.Tools`; serialization in
  `TrackMyJobExWeb.MCP.Serializer`.
- Mix tasks: `mix mcp.tokens.create EMAIL --name NAME [--expires-in DAYS]`,
  `mix mcp.tokens.list EMAIL`, `mix mcp.tokens.revoke EMAIL TOKEN_ID`.
- Tests: 14 context tests, 9 auth tests, 13 tool tests, 11 Mix task tests
  (342 total). `mix precommit` passes.

## Phase 10 — MCP Token Management UI

- [x] Add `McpTokenLive.Index` listing the signed-in user's tokens with name,
  prefix, created/last-used/expires timestamps, and a revoke action.
- [x] Add a create form (name, optional expiry in days) that shows the
  plaintext token once in a dismissible panel.
- [x] Add a confirmation-gated revoke flow.
- [x] Add the `/mcp-tokens` route under the authenticated `live_session` and a
  navigation link.
- [x] Update `PRODUCT.md` and `TASKS.md`.

**Acceptance criteria:**
- A signed-in user can create, list, and revoke their own MCP tokens.
- The plaintext is displayed only at creation time.
- Another user's tokens are never visible or revocable.
- `mix precommit` passes.

**Phase 10 completion notes:**
- LiveView: `TrackMyJobExWeb.McpTokenLive.Index` uses a plain list assign (not a
  stream) for reliable updates; create shows the plaintext in a dismissible
  amber panel; revoke uses the shared confirmation modal.
- Route: `live "/mcp-tokens", McpTokenLive.Index, :index` under the
  authenticated `live_session`; nav link id `#nav-mcp-tokens`.
- Tests: 4 LiveView tests covering empty state, create + one-time display,
  cross-user isolation, and confirmation-gated revoke (346 total).
- `mix precommit` passes.

**Acceptance criteria:**
- A signed-in user can create, list, and revoke their own MCP tokens.
- The plaintext is displayed only at creation time.
- Another user's tokens are never visible or revocable.
- `mix precommit` passes.

## Phase 11 — Application Budget Range

- [x] Add `budget_min` and `budget_max` integer columns to `job_applications`.
- [x] Add fields, validation (non-negative, min <= max), and blank handling to
  `JobApplication`.
- [x] Surface the budget range in the application form and details page.
- [x] Include `budget_min`/`budget_max` in the MCP serializer and tools.
- [x] Update `PRODUCT.md` and `TASKS.md`.

**Acceptance criteria:**
- Applications can store an optional minimum and maximum budget in whole units.
- Validation rejects negative values and a maximum below the minimum.
- Blank inputs are stored as `NULL`.
- `mix precommit` passes.

**Phase 11 completion notes:**
- Migration: `20261118181200_add_budget_to_job_applications.exs` adds two
  nullable integer columns.
- Schema/changeset: `budget_min`/`budget_max` are cast and validated; blank
  strings are normalized to `nil` before casting so empty inputs do not
  produce "is invalid" errors.
- UI: a Budget section in `ApplicationForm` and a budget span on the
  application details page.
- MCP: `budget_min`/`budget_max` added to `applications_create` and
  `applications_update`, and to the serializer.
- Tests: 347 total (no new tests added; existing suites cover the new columns
  through the changeset). `mix precommit` passes.

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
