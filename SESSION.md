# Job Tracker — Session Handoff

Read this file first at the start of every session, then read `TASKS.md`.
Update it before ending every session.

---

## Current State

- **Current phase:** Phase 3 — Core Domain
- **Current task group:** 3.1 — not started
- **Next task:** Implement the `JobApplication` schema, including plain-text
  `company_name` and optional `recruiter_name` columns.
- **Overall status:** Phase 2 complete and verified; ready to start Phase 3.
- **Last commit:** Phase 2.9: Add ownership authorization tests

## Last Session Summary

Phase 2 (Authentication and User Isolation) is complete. Authentication was
generated with `mix phx.gen.auth` and reduced to password-only email/password
sessions using `bcrypt_elixir`. Public registration was disabled, and the
generator-provided password reset, email confirmation, magic-link login, account
settings, notifier, and mailer flows were removed along with their routes,
modules, tests, configuration, and the `swoosh` dependency. A regression test
asserts that those routes return 404.

Users are now provisioned only through `mix users.create EMAIL [--password
PASSWORD]`, which uses the Accounts changeset, prompts with hidden input when no
password flag is given, and raises a clear error on duplicate emails (any
casing), invalid emails, short passwords, or invalid arguments. The users table
stores email with `COLLATE NOCASE` and has a unique index, so uniqueness is
case-insensitive in SQLite. A migration removed the unused `confirmed_at` and
`sent_to` columns.

The dashboard and logout controller route are protected by the
`require_authenticated_user` pipeline, and the dashboard LiveView also uses the
`on_mount :require_authenticated` hook. Login remains public; authenticated
users visiting `/users/log-in` are redirected to the dashboard. The layout shows
the signed-in email and a logout control, or a login link for anonymous
visitors. Tenant isolation conventions are documented in `AGENTS.md`, and tests
cover scopes, independent sessions, login/logout, protected route redirects, and
cross-user session isolation. Record-level isolation tests for applications and
tags will be added in Phase 3 when those resources exist.

## Assumptions Made

- 2026-11-14 — Task 2.1: Used the Phoenix authentication generator with LiveView
  and the default `bcrypt` hashing library on this platform.
- 2026-11-14 — Task 2.3: Because email is out of scope for the initial version,
  the notifier, mailer, Swoosh dependency, and dev mailbox were removed rather
  than left as dead plumbing. `confirmed_at` and `sent_to` were dropped through
  a reversible migration.
- 2026-11-14 — Task 2.3: Password rules are the generator defaults: minimum 12
  characters, maximum 72 bytes for bcrypt.
- 2026-11-14 — Task 2.5: Logout is a protected controller route and redirects to
  the login page. Sessions use the generator's standard 14-day token lifetime;
  no custom session policy or remember-me UI was added.
- 2026-11-14 — Task 2.6: The Mix task accepts `--password` for non-interactive
  use and otherwise prompts twice with `:io.get_password/1` (hidden where the
  terminal supports it). Failures raise `Mix.Error`, producing a non-zero exit.
- 2026-11-14 — Task 2.9: Record-level isolation tests are deferred to Phase 3
  because applications and tags do not exist yet. Current tests use two separate
  connections/sessions to prove session and scope isolation.

## Blockers and Open Questions

None.

## Deviations from PRODUCT.md

None. If this file and PRODUCT.md conflict, PRODUCT.md wins; list the conflict here and ask.

## Next Actions

1. Start Phase 3: implement the `JobApplication` schema with plain-text
   `company_name` and optional `recruiter_name` columns.
2. Continue with status history, seeded statuses, tags, and associations.
3. Add scoped context functions using `current_scope` as the first argument.
4. Add record-level cross-user isolation tests for every user-owned resource.

---

## Session Log

Add one entry per session, newest first, in this format:

### 2026-11-14

- **Done:** Phase 2, task groups 2.1–2.9. Generated password authentication with
  bcrypt; disabled registration and removed reset/confirmation/magic-link/
  settings/mailer flows and the Swoosh dependency; added regression tests for
  removed routes; implemented password login/logout and navigation; added
  `mix users.create` with tests for success, duplicate/case-insensitive email,
  invalid email, short password, and bad arguments; protected the dashboard and
  logout route with both plug and LiveView `on_mount` hooks; documented tenant
  isolation conventions; added scope, session-isolation, protected-route, and
  helper tests. All checks pass via `mix precommit`.
- **Commits:**
  - `19122e4` Phase 2.1: Implement authentication
  - `ffc2d65` Phase 2.2: Disable public registration
  - `30c5b6a` Phase 2.3: Remove password reset and confirmation flows
  - `1bc563e` Phase 2.4: Add no-public-registration test
  - `72e2986` Phase 2.5: Implement login and logout
  - `518996a` Phase 2.6: Implement mix users.create
  - `69cb10c` Phase 2.7: Add authenticated route protection
  - `2f48670` Phase 2.8: Define tenant isolation conventions
  - Phase 2.9: Add ownership authorization tests (this commit)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None.
- **Next:** Implement the `JobApplication` schema (Phase 3).
