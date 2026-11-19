# Deployment Guide

This document describes how to build, configure, run, monitor, back up, and
restore the Job Tracker in production. It reflects the repository as of Phase 7
(production readiness).

The application is a single-node Phoenix release backed by SQLite. It does not
require a separate database server. SQLite allows one writer at a time, so run
**one application instance per database file**; do not scale the container
horizontally against a shared volume.

## Scope and status

Implemented and verified locally:

- Production release build (`MIX_ENV=prod mix release`) and boot.
- SQLite database path on a persistent volume, created on boot.
- WAL journal mode, foreign-key enforcement, busy timeout, and queue settings.
- HTTPS enforcement, HSTS, and secure/HttpOnly/SameSite cookies.
- `/health` liveness/readiness endpoint.
- Online SQLite backup and restore scripts, including a tested restore.
- Hardened multi-stage Dockerfile running as a non-root user.
- GitHub Actions CI for formatting, compilation, Credo, and tests.
- End-to-end workflow test.
- Production query indexes and reviewed query plans.

Operator-only work that cannot be completed from this repository:

- DNS, a real domain, and a TLS certificate.
- Provisioning and permissions for the production persistent volume.
- Real production host names and secrets.
- External monitoring/alerting and log aggregation.
- Scheduled, off-site, encrypted backups and retention policy.
- The actual deploy step (no cloud credentials or target are stored here).

These are called out again in [Operator checklist](#operator-checklist).

## Prerequisites

- Elixir 1.20.5 / Erlang OTP 28 (pinned in `.tool-versions`).
- `sqlite3` CLI on the host or operations runner for backups and restores.
- Docker if you deploy the provided image.
- A persistent volume mounted into the container or host (for example `/data`).
- A TLS-terminating load balancer or reverse proxy, or certificate files for
  the endpoint.

## Environment variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `SECRET_KEY_BASE` | Yes (prod) | none — boot fails | Signs cookies and other secrets. Generate with `mix phx.gen.secret`. |
| `DATABASE_PATH` | Recommended | `${DATA_DIR:-/data}/track_my_job_ex/track_my_job_ex.db` | Absolute path to the SQLite file. Must be on the persistent volume. |
| `DATA_DIR` | No | `/data` | Base directory used when `DATABASE_PATH` is not set. |
| `PHX_HOST` | Recommended | `example.com` | Public host used for URL generation and HSTS. |
| `MCP_RESOURCE_URL` | No | `https://$PHX_HOST/mcp` | Canonical OAuth audience identifier for the publicly reachable MCP endpoint. Set this when the public URL differs from this default. |
| `PORT` | No | `4000` | HTTP listen port inside the container/host. |
| `POOL_SIZE` | No | `5` | Ecto/SQLite connection pool size. Keep small (1–5). |
| `SQLITE_BUSY_TIMEOUT` | No | `5000` | Milliseconds a writer waits for the SQLite lock. |
| `PHX_SERVER` | Set by `bin/server` | unset | Starts the HTTP server in a release. |
| `DNS_CLUSTER_QUERY` | No | unset | Optional clustering; leave unset for a single node. |

Never commit `SECRET_KEY_BASE` or any `.env` file. `.env*` and database files are
gitignored. Inject secrets through the platform's secret manager.

## Build a release

```sh
export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release
```

The release is written to `_build/prod/rel/track_my_job_ex`. `mix assets.deploy`
must run before `mix release` so `priv/static/cache_manifest.json` exists;
otherwise the release logs a static-asset warm-up warning.

Run migrations before starting the new release:

```sh
bin/migrate
```

`bin/migrate` invokes `TrackMyJobEx.Release.migrate/1`, which runs all pending
Ecto migrations. It uses the same runtime environment variables as the server
(`SECRET_KEY_BASE`, `DATABASE_PATH`, and so on). The release does **not**
auto-migrate on boot, so migrations are an explicit deploy step.

Start the server:

```sh
SECRET_KEY_BASE="$(mix phx.gen.secret)" \
DATABASE_PATH=/data/track_my_job_ex/track_my_job_ex.db \
PHX_HOST=jobs.example.com \
PORT=4000 \
bin/server
```

`bin/server` sets `PHX_SERVER=true` and starts the release. The parent directory
of `DATABASE_PATH` is created on boot if it does not exist.

## Docker

Build and run:

```sh
docker build -t job-tracker:$(git rev-parse --short HEAD) .

docker run -d --name job-tracker \
  -p 4000:4000 \
  -v /var/lib/job-tracker:/data \
  -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  -e PHX_HOST=jobs.example.com \
  -e DATABASE_PATH=/data/track_my_job_ex/track_my_job_ex.db \
  job-tracker:$(git rev-parse --short HEAD)
```

The image runs as `nobody` (UID 65534) and uses `tini` as PID 1. Make the
mounted volume writable by that UID, for example:

```sh
sudo install -d -o 65534 -g 65534 -m 0750 /var/lib/job-tracker
```

Run migrations as a one-off container with the same volume and environment,
before replacing the running container:

```sh
docker run --rm \
  -v /var/lib/job-tracker:/data \
  -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  -e DATABASE_PATH=/data/track_my_job_ex/track_my_job_ex.db \
  job-tracker:$(git rev-parse --short HEAD) \
  /app/bin/migrate
```

Because SQLite has a single writer, run migrations during a short maintenance
window or before starting the new instance. Back up the database first.

## Persistent volume

- Mount the volume at `/data` (or set `DATABASE_PATH` explicitly).
- The database, its WAL file (`*.db-wal`), and shared-memory file (`*.db-shm`)
  must stay on the same local filesystem. Do not place them on NFS or a network
  filesystem that does not provide correct POSIX locking.
- Keep a single writer instance. For high availability, snapshot/restore or
  promote a standby rather than running two writers.
- Back up the volume, not only the `.db` file, using the online backup method
  below so WAL contents are included consistently.

## HTTPS

Production enforces HTTPS through `force_ssl` in `config/prod.exs`:

- Requests with `X-Forwarded-Proto: https` are treated as secure.
- Plain HTTP requests are redirected to HTTPS (except `/health` and localhost).
- HSTS is enabled for one year (`max-age=31536000`).
- Session and remember-me cookies use `Secure`, `HttpOnly`, and `SameSite=Lax`
  in production.

Terminate TLS at a trusted load balancer or reverse proxy and forward
`X-Forwarded-Proto`, `X-Forwarded-For`, and `Host`. Do not expose port 4000
directly to the internet. Alternatively, configure `https:` in
`config/runtime.exs` with certificate paths and keep the proxy out of the path.

The `/health` path is excluded from HTTPS redirects so private-network health
checks can use plain HTTP. It returns no application data.

OAuth discovery and callbacks require the public HTTPS host to be reachable.
Configure `PHX_HOST` before deployment and set `MCP_RESOURCE_URL` to the exact
URL clients use for `/mcp` if a proxy publishes a different path or host. Run
`bin/migrate` before starting the release to create the OAuth client, code, and
token tables.

## Health and monitoring

`GET /health` returns:

- `200 ok` when `SELECT 1` succeeds against SQLite.
- `503 unavailable` when the database cannot answer.

Use it for load-balancer health checks and external uptime monitoring. It is
unauthenticated by design and must not expose tenant data.

Application logs are single-line events at `:info` with `:request_id` metadata.
Ecto query logging is `:debug`, so SQL text and bound parameters are not emitted
at the production level. Do not lower the production log level. Forward logs to
the platform's log aggregation; configure retention and alerting there.

Recommended alerts (operator-side):

- `/health` non-200 for more than one check interval.
- Release restart loop or BEAM crash.
- Disk usage on the data volume above 80%.
- Backup job failure or missing recent backup.
- TLS certificate expiry within 30 days.

## Backups

Use the online SQLite backup API, not a raw file copy, so WAL contents are
captured consistently while the application is running.

### Script

`scripts/backup_sqlite.sh` uses `sqlite3 .backup`, runs `PRAGMA integrity_check`,
checkpoints the copy, and writes a single self-contained file.

```sh
DATABASE_PATH=/data/track_my_job_ex/track_my_job_ex.db \
BACKUP_DIR=/data/backups \
./scripts/backup_sqlite.sh
```

Output:

```text
Backup written to /data/backups/track_my_job_ex.db-20261116T173353Z.db
integrity_check: ok
```

The script defaults to `$DATABASE_PATH`, then `./track_my_job_ex_dev.db`, and to
`./backups`. The backup directory is gitignored.

### Scheduling

Run hourly (or at the cadence required by your recovery point objective) from
cron or the platform scheduler. Example crontab entry on the host:

```cron
0 * * * * cd /srv/job-tracker && DATABASE_PATH=/data/track_my_job_ex/track_my_job_ex.db BACKUP_DIR=/data/backups ./scripts/backup_sqlite.sh >> /var/log/job-tracker-backup.log 2>&1
```

Backups contain personal data. Encrypt them at rest and copy them off the
application host. Off-site storage, encryption keys, and retention are
operator responsibilities. A common policy is hourly local backups, daily
off-site copies, and 30-day retention, but choose based on your requirements.

### Verified restore

A restore was performed from a seeded database to a separate target. Row counts
matched (users=1, applications=1, history=1, tags=1, tag links=1, statuses=13)
and the schema matched. `PRAGMA integrity_check` returned `ok` for both the
backup and the restored copy.

Restore procedure:

1. Stop the application (or put it in maintenance mode) so nothing writes.
2. Optionally keep the current database file as a safety copy.
3. Restore to the live path with `FORCE=1`:

   ```sh
   FORCE=1 DATABASE_PATH=/data/track_my_job_ex/track_my_job_ex.db \
     ./scripts/restore_sqlite.sh \
     /data/backups/track_my_job_ex.db-20261116T173353Z.db \
     /data/track_my_job_ex/track_my_job_ex.db
   ```

   Output:

   ```text
   Restored /data/backups/track_my_job_ex.db-20261116T173353Z.db to /data/track_my_job_ex/track_my_job_ex.db
   integrity_check: ok
   ```

4. Remove stale `-wal`/`-shm` sidecars for the restored path if they remain
   from the old database, then start the application.
5. Verify `/health` returns `200` and spot-check a login and application list.

Test a restore on a schedule, not only when an incident occurs. A backup that
has never been restored is unverified.

## CI pipeline

`.github/workflows/ci.yml` runs on every push and pull request:

1. Check formatting (`mix format --check-formatted`).
2. Compile with warnings as errors.
3. Run Credo strict.
4. Run the full ExUnit suite (including the end-to-end test).

The workflow uses the pinned Elixir/OTP versions and caches `deps` and
`_build`. It does not deploy. Image publishing and environment deployment should
be added by the operator behind protected branches and environment secrets.

## Tests

`test/track_my_job_ex_web/end_to_end_test.exs` drives the real router and
LiveViews with two independently authenticated connections. It covers:

- Login through the router.
- Creating an application with a company, recruiter, and inline tag.
- Default `Interested` status and initial history.
- Status change with notes and the resulting timeline.
- Pagination.
- Search, status, company, and tag filters.
- Sort-direction toggle.
- A second user being unable to see or delete the first user's record.
- Application deletion cascading to history and tag links while tags survive.

Run locally with:

```sh
mix test
```

## Rollback

Releases are immutable and versioned. To roll back:

1. Stop the current instance.
2. Start the previous image/release with the same environment.
3. If the migration is reversible and the schema must move back, run:

   ```sh
   bin/track_my_job_ex eval \
     'TrackMyJobEx.Release.rollback(TrackMyJobEx.Repo, 20261116130000)'
   ```

   Only do this when the migration is safe to reverse (the Phase 7 migration
   only adds/drops indexes). Otherwise restore the pre-deploy backup.

4. Verify `/health`, login, and the application list.

A database backup taken immediately before deploying is the safest rollback for
destructive schema changes.

## Production SQLite configuration

`config/runtime.exs` sets:

- `journal_mode: :wal` — concurrent readers with one writer.
- `foreign_keys: :on` — referential integrity enforced.
- `busy_timeout` — writers wait up to 5 seconds by default.
- `pool_size: 5` — small pool suited to SQLite.
- `queue_target: 50`, `queue_interval: 1000` — smooth short write contention.

The Phase 7 migration adds indexes for the listing queries:
`(user_id, status_id)`, `(user_id, recruiter_name)`, `(user_id, inserted_at)`,
`(user_id, updated_at)`, NOCASE `(user_id, company_name)` and
`(user_id, recruiter_name)`, `(application_id, changed_at)` on history, and
`(tag_id, application_id)` on tag links. `EXPLAIN QUERY PLAN` confirms these
plans are index-backed, including the tag AND filter.

If you see `database is locked` errors under load, lower the instance count,
raise `SQLITE_BUSY_TIMEOUT` modestly, and keep write transactions short. Do not
increase the pool aggressively; SQLite serializes writers.

## Operator checklist

Complete these outside the repository before going live:

- [ ] Point a real domain at the load balancer and provision a TLS certificate.
- [ ] Provision the persistent volume and make it writable by UID 65534.
- [ ] Store `SECRET_KEY_BASE` in a secret manager; never in Git.
- [ ] Configure `PHX_HOST`, `DATABASE_PATH`, and `PORT` for the environment.
- [ ] Run `bin/migrate` and verify `/health` returns `200`.
- [ ] Confirm HTTPS redirect, HSTS, and `Secure` cookies through the real proxy.
- [ ] Schedule backups, test a restore, and configure off-site encrypted copies.
- [ ] Connect uptime monitoring and log aggregation, and set alerts.
- [ ] Add the image publish/deploy step to CI with protected environment secrets.
- [ ] Restrict network access so only the proxy reaches the app port.
- [ ] Apply OS/container image patching and review dependency advisories
      (`mix hex.audit`).
