# Security Review

This document records the Phase 7 security and tenant-isolation review. It lists
what was fixed, what was verified, accepted risks that follow from the product
scope, and operator-only controls.

## Scope and method

Reviewed:

- Authentication, session, and cookie handling.
- Authorization and every context query that reads or writes user-owned data.
- LiveView event handlers and form parameters.
- URL rendering, search input handling, and error behavior.
- Production transport security, headers, logging, and health exposure.
- Dependency advisories and container runtime posture.

Verification: full ExUnit suite (`mix test`), `mix precommit`, a production
release boot, and `mix hex.audit` (`No retired or security advisory packages
found`).

## Findings

### Fixed in this phase

| Finding | Fix | Verification |
|---|---|---|
| Session cookie did not explicitly set `HttpOnly`/`Secure` | Set `http_only: true`, `secure: Mix.env() == :prod`, kept `SameSite=Lax` | Session cookie tests and production release response headers |
| Remember-me cookie lacked `HttpOnly`/`Secure` | Added the same flags to `@remember_me_options` | `user_auth` tests; production boot inspection |
| Plain HTTP was served in production | Enabled `force_ssl` with `rewrite_on: [:x_forwarded_proto]`, one-year HSTS | Production boot: `302` redirect and `strict-transport-security: max-age=31536000` |
| Health endpoint could be caught by HTTPS redirects/checks | Excluded `/health` and localhost from `force_ssl`; endpoint is unauthenticated and returns no data | `health_controller_test.exs`; release boot returned `200 ok` |
| Company/recruiter filters used `lower(column) = ?`, preventing index use | Changed to `column = ? COLLATE NOCASE` and added NOCASE composite indexes | `EXPLAIN QUERY PLAN` uses the NOCASE indexes |
| Database files and local secrets could be committed | Added `*.db*`, `*.db-wal`, `*.db-shm`, `.env*`, `/backups/`, and release artifacts to `.gitignore` | `git status` review |
| Container ran with default root user and no init | Hardened Dockerfile to run as `nobody` and use `tini` as PID 1 | Dockerfile review |

### Verified as already correct

- Passwords are hashed with bcrypt through the Phoenix authentication generator;
  plaintext passwords are never stored or logged.
- Public registration, password reset, confirmation, and magic-link flows are
  removed. Users are provisioned only through `mix users.create`.
- Login renews the session and rotates the session token; logout deletes the
  token and renews the session.
- Browser routes use the Phoenix CSRF plug through the `:browser` pipeline, and
  LiveView forms are protected by LiveView's CSRF token handling.
- All user-owned context functions take a `%Scope{}` first argument and filter
  by the scope's user id. There is no unscoped `get_*`/`get_*!` for applications,
  tags, or resumes.
- Client-provided `user_id` values are never cast. Ownership is always derived
  from `current_scope.user.id`.
- Association IDs (tag ids) are re-fetched through the current user's scope
  before linking. Another user's tag id is rejected and rolls back the whole
  create/update transaction.
- Cross-user reads return `nil` or behave as "not found"; LiveViews redirect
  with an error flash rather than confirming that another user's record exists.
- Status changes update the application and append history in one transaction;
  history has no update/delete API.
- Job posting URLs are validated on write and rendered only when
  `Formatters.safe_http_url/1` accepts an absolute `http`/`https` URL. This
  blocks `javascript:`, `data:`, `file:`, `mailto:`, protocol-relative, and
  relative URLs.
- Search input is bound through Ecto parameters and escapes `%`, `_`, and `\`
  for `LIKE`.
- Health checks execute a constant `SELECT 1` and return no tenant data.
- Production logs are `:info`; Ecto `:debug` SQL text and parameters are not
  emitted. Logs include a request id.

### Accepted risks

These follow from `PRODUCT.md` and are recorded rather than silently fixed:

- **No login rate limiting.** Listed as out of scope for the initial version.
  Mitigate at the reverse proxy or load balancer if needed.
- **No MFA.** Not in scope.
- **No self-service password reset.** Out of scope; administrators provision
  accounts and can reset passwords operationally.
- **Single-node SQLite.** There is no built-in replication or automatic
  failover. Recovery relies on backups and redeploying the release.
- **No application-level encryption at rest.** Use encrypted disks/volumes and
  encrypted, access-controlled backups.
- **Unauthenticated `/health`.** Intentional; it exposes only `ok`/`unavailable`.
- **No administrative UI.** User provisioning is an operator task through the
  Mix task.

### Operator-only controls

- DNS, domain ownership, TLS certificate issuance/renewal, and proxy
  configuration.
- Firewall/network policy so the application port is reachable only from the
  proxy.
- Secret storage for `SECRET_KEY_BASE` and any platform credentials.
- OS/container image patching and vulnerability scanning.
- Off-site encrypted backups, retention, and periodic restore drills.
- Log aggregation, retention, uptime checks, and alerting.
- Disk encryption and volume access control.

## Tenant isolation matrix

Legend: "not found" means a cross-user read returns `nil`, and a cross-user
write raises/returns an error without revealing whether the record exists.

### Applications (`JobApplication`)

| Operation | Expected behavior for another user's id | Test |
|---|---|---|
| Read one | `get_application/2` returns `nil`; `get_application!/2` raises `Ecto.NoResultsError` | `test/track_my_job_ex/job_applications_test.exs:215`; LiveViews at `test/track_my_job_ex_web/live/application_live_test.exs:114,276` |
| List | Owning scope lists only its rows; filters never return other users' rows | `job_applications_test.exs:203,1182` |
| Filter options | Company/recruiter/status values do not leak | `job_applications_test.exs:1206` |
| Create | Owner is taken from the scope; client `user_id` is ignored | `job_applications_test.exs` create tests; E2E |
| Update | Rejected | `job_applications_test.exs:245,889` |
| Delete | Rejected | `job_applications_test.exs:273`; `application_live_test.exs:556` |
| Change status | Rejected with no history row | `job_applications_test.exs:499` |
| Render in list | Other user's application is not rendered | `application_live_test.exs:15` |

### Tags (`Tag`)

| Operation | Expected behavior for another user's id | Test |
|---|---|---|
| Read one | Not found | `test/track_my_job_ex/tags_test.exs:71` |
| List | Only the current user's tags | `test/track_my_job_ex_web/live/tag_live_test.exs:14` |
| Create/reuse | Never reuses another user's tag; creates a separate tag if allowed | `tags_test.exs:165` |
| Update/rename | Rejected | `tags_test.exs:100`; `tag_live_test.exs:90` |
| Delete | Rejected | `tags_test.exs:125`; `tag_live_test.exs:144` |
| Inline creation | Scoped to the current user | `job_applications_test.exs` create-with-tags tests |

### Resumes (`Resume`)

| Operation | Expected behavior for another user's id | Test |
|---|---|---|
| Read one | `get_resume/2` returns `nil`; `get_resume!/2` raises `Ecto.NoResultsError` | `test/track_my_job_ex/resumes_test.exs:190`; LiveViews at `test/track_my_job_ex_web/live/resume_live_test.exs:207,274` |
| List | Only the scope's resumes, with preloaded tags | `resumes_test.exs:158,174` |
| Create | Owner is taken from the scope; client `user_id` is ignored; email defaults from the scope's user | `resumes_test.exs` create/prefill tests |
| Update | Rejected | `resumes_test.exs:216` |
| Delete | Rejected | `resumes_test.exs:380` |
| Render in list/details | Other users' resumes are not rendered; details redirect with "not found" | `resume_live_test.exs` index/show tests |

### Resume tags (`ResumeTag`)

| Operation | Expected behavior | Test |
|---|---|---|
| Link another user's tag | Rejected; the whole create/update rolls back | `resumes_test.exs:270`; `resume_live_test.exs:145` |
| Replace tags with another user's tag | Rejected; no partial field or link changes | `resumes_test.exs` update-with-tags tests |
| Read another user's resume links | Not reachable because the resume read is scoped | `resumes_test.exs:190` |
| Delete a resume | Cascades to its tag links; tags are kept | `resumes_test.exs:362` |
| Delete a tag | Cascades to resume links; resumes are kept | `resumes_test.exs:391` |

### Status history (`ApplicationStatusHistory`)

| Operation | Expected behavior | Test |
|---|---|---|
| Read/list | Only history for the current user's application; another user's history is not readable | `job_applications_test.exs:327` |
| Create | Only through a scoped status change; atomic with the application update | `job_applications_test.exs:499` and Phase 5 rollback tests |
| Update/delete | No API exists | Phase 5 API-surface test |

### Associations (`ApplicationTag`)

| Operation | Expected behavior | Test |
|---|---|---|
| Link another user's tag | Rejected; transaction rolls back | `job_applications_test.exs:598,743`; `application_live_test.exs:780` |
| Replace tags with another user's tag | Rejected; no partial changes | `job_applications_test.exs:610,845,889`; `application_live_test.exs:854` |
| Read another user's application links | Not reachable because the application read is scoped | `job_applications_test.exs:578` |
| List tag links | Scoped through the application query | `job_applications_test.exs:203` |

### Sessions and authentication

| Case | Expected behavior | Test |
|---|---|---|
| Two users log in independently | Each session resolves to its own user | `test/track_my_job_ex_web/tenant_isolation_test.exs:31` |
| Logout of one session | Does not invalidate the other | `tenant_isolation_test.exs:46` |
| Anonymous request | Redirected to login; LiveView mount halted | `tenant_isolation_test.exs:79,88` |
| Cookie flags | `Secure` in prod, `HttpOnly`, `SameSite=Lax` | `test/track_my_job_ex_web/controllers/user_session_controller_test.exs` |

## Session and cookie settings

- Session store: signed cookie, `SameSite=Lax`, `HttpOnly`, `Secure` in
  production.
- Remember-me cookie: signed, 14-day max age, `SameSite=Lax`, `HttpOnly`,
  `Secure` in production.
- Session token rotation on login and logout.
- `SECRET_KEY_BASE` is required in production; boot fails without it.

## SQL injection and input handling

- Ecto parameter binding is used for all values, including search and filters.
- Filter fields are selected from a fixed internal set, never from user input.
- Sort fields and directions are whitelisted.
- Tag ids are parsed and re-fetched through the scoped context.
- HTML output is escaped by HEEx; the only raw URL usage is gated by
  `safe_http_url/1`.

## Reporting

If you find a vulnerability, report it privately to the maintainers rather than
opening a public issue. Include reproduction steps and affected versions.
