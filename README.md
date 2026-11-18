# Job Tracker

Job Tracker is a multi-user web application for organising a job search. It keeps
applications, companies, recruiters, resume versions, tags, statuses, and the
full status history in one place so that every opportunity and every step of the
recruitment process can be reviewed later.

The product requirements live in [`PRODUCT.md`](PRODUCT.md), the implementation
plan and development rules live in [`TASKS.md`](TASKS.md), and the session
handoff notes live in [`SESSION.md`](SESSION.md).

## Stack

- Elixir 1.20.5 / Erlang OTP 28
- Phoenix 1.8.16 with Phoenix LiveView 1.2
- SQLite3 through `ecto_sqlite3`
- Tailwind CSS 4 with daisyUI 5
- ExUnit with Ecto SQL Sandbox

Versions are pinned in [`.tool-versions`](.tool-versions) for
[asdf](https://asdf-vm.com/).

## Prerequisites

- [asdf](https://asdf-vm.com/) (or matching Elixir/Erlang installations)
- A C compiler and `make` for the `exqlite` NIF
- Node.js is not required; esbuild and Tailwind are managed by Mix

Install the pinned toolchain:

```sh
asdf install
```

## Setup

```sh
mix deps.get
mix setup
```

`mix setup` fetches dependencies, creates and migrates the SQLite databases,
seeds them, and installs/builds the esbuild and Tailwind assets.

## Running locally

```sh
mix phx.server
```

Then open <http://localhost:4000>. Anonymous visitors are redirected to the
login page. To run inside IEx:

```sh
iex -S mix phx.server
```

## User accounts

Public registration is disabled. Users are provisioned by an administrator with
the custom Mix task:

```sh
mix users.create alice@example.com
```

The task prompts for a password twice using hidden input where supported. For
non-interactive environments, pass the password explicitly:

```sh
mix users.create alice@example.com --password "a long password"
```

Passwords must satisfy the application changeset rules (at least 12 characters,
at most 72 bytes). Email addresses are unique case-insensitively, so creating
`ALICE@example.com` after `alice@example.com` fails. The task exits with a
non-zero status and a clear message for duplicate emails, invalid emails, short
passwords, or invalid arguments.

Log in at <http://localhost:4000/users/log-in>. Sessions use the standard
Phoenix session token lifetime. Log out from the navigation bar. Password reset,
email confirmation, magic-link login, and public registration are intentionally
unavailable in this version.

Development and test SQLite databases are created in the project root
(`track_my_job_ex_dev.db` and `track_my_job_ex_test.db`) and are gitignored.
SQLite foreign keys are enforced and WAL journal mode is enabled in every
environment.

## Tests

```sh
mix test
```

Tests use ExUnit and `Ecto.Adapters.SQL.Sandbox`. SQLite allows a single writer
at a time; if a database test is affected by lock contention, run it
synchronously (`async: false`).

## Quality checks

```sh
mix format --check-formatted
mix credo --strict
mix precommit
```

`mix precommit` compiles with warnings as errors, removes unused dependencies,
formats the code, runs Credo in strict mode, and runs the test suite. A task is
complete only when this command passes.

## Mix task conventions

Project-specific Mix tasks live in `lib/mix/tasks/` and are namespaced by
domain (for example `mix users.create`). Tasks validate their arguments, print
clear errors on invalid or duplicate input, and are covered by tests where the
behaviour is non-trivial. `mix users.create` is the only supported way to
provision users because public registration is disabled.

## Project layout

- `lib/track_my_job_ex/` — contexts, schemas, and application services
- `lib/track_my_job_ex_web/` — endpoint, router, LiveViews, and components
- `priv/repo/migrations/` — version-controlled Ecto migrations
- `test/` — ExUnit tests and support modules
