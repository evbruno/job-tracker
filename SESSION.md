# Job Tracker — Session Handoff

Read this file first at the start of every session, then read `TASKS.md`.
Update it before ending every session.

---

## Current State

- **Current phase:** Phase 2 — Authentication and User Isolation
- **Current task group:** 2.0 — not started
- **Next task:** Implement authentication (Phase 2).
- **Overall status:** Phase 1 complete — Phase 2 not started
- **Last commit:** Phase 1.5: Phase 1 verification

## Last Session Summary

Phase 1 (Project Foundation) is complete. The Phoenix 1.8.16 application was
verified with LiveView, Tailwind 4, daisyUI 5, and SQLite3. Dependencies were
fetched and the toolchain pinned. Development and test databases are configured
with explicit `journal_mode: :wal` and `foreign_keys: :on`, and the production
runtime config keeps `DATABASE_PATH` with the same pragmas. The generated
marketing page was replaced by a public dashboard LiveView at `/` with a small
counter interaction and a product-appropriate layout. Credo was added in strict
mode, the `precommit` alias now runs Credo, and the README documents local
development and Mix task conventions.

## Assumptions Made

- 2026-11-14 — Task 1.1: `.tool-versions` pins `erlang 28.5` and
  `elixir 1.20.5-otp-28`, matching the asdf installations on this machine. The
  requested "Erlang/OTP 28" is pinned at its installed patch release.
- 2026-11-14 — Task 1.2: The throwaway `COLLATE NOCASE`/`LIKE` probe used a raw
  SQL table because no domain tables exist yet; both the migration and its test
  were removed and the dev/test databases were recreated afterwards.
- 2026-11-14 — Task 1.3: The dashboard is intentionally public and contains no
  authentication. "Applications" and "Tags" appear as disabled, non-clickable
  placeholders because those routes do not exist yet.
- 2026-11-14 — Task 1.4: `precommit` keeps the generated `format` step (which
  rewrites files) and adds `credo --strict`; `mix format --check-formatted` is
  run separately during verification.

## Blockers and Open Questions

None.

## Deviations from PRODUCT.md

None. If this file and PRODUCT.md conflict, PRODUCT.md wins; list the conflict here and ask.

## Next Actions

1. Start Phase 2: implement authentication using the Phoenix authentication
   generator (or equivalent established solution).
2. Disable public registration and remove password reset/email confirmation flows.
3. Implement `mix users.create`, login/logout, and authenticated route protection.
4. Establish tenant isolation conventions and ownership authorization tests.

---

## Session Log

Add one entry per session, newest first, in this format:

### 2026-11-14

- **Done:** Phase 1, task groups 1.1–1.5. Verified Elixir 1.20.5 / OTP 28 and
  Phoenix 1.8.16; added `.tool-versions`; rewrote the README; deleted the stray
  tracked `Job` file; fetched dependencies; explicitly configured SQLite WAL and
  foreign keys in dev/test/prod runtime; verified connectivity, pragmas, and the
  throwaway `COLLATE NOCASE`/`LIKE` probe; replaced the marketing page with a
  dashboard LiveView and added layout/navigation; added coding conventions,
  Credo, and `credo --strict` in `precommit`; ran the app, home page, tests,
  formatting, Credo, and `mix precommit` successfully.
- **Commits:**
  - `0454233` Phase 1.1: Project initialization
  - `2866566` Phase 1.2: Database configuration
  - `6d6fa74` Phase 1.3: Frontend and layout
  - `2697fb5` Phase 1.4: Development standards
  - Phase 1.5: Phase 1 verification (this commit)
- **Assumptions:** See the Assumptions Made section above.
- **Blockers:** None.
- **Next:** Implement authentication (Phase 2).
