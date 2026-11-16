#!/usr/bin/env bash
#
# Create a consistent online backup of the SQLite database.
#
# Usage:
#   ./scripts/backup_sqlite.sh [DATABASE_PATH]
#
# The database path defaults to $DATABASE_PATH, then to
# ./track_my_job_ex_dev.db. Set BACKUP_DIR to choose the output directory
# (defaults to ./backups).
#
# `sqlite3 .backup` is used instead of copying the file because it takes a
# consistent snapshot even while the application is writing in WAL mode.
set -euo pipefail

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "error: sqlite3 CLI is required for backups" >&2
  exit 1
fi

DB_PATH="${1:-${DATABASE_PATH:-track_my_job_ex_dev.db}}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

if [ ! -f "$DB_PATH" ]; then
  echo "error: database not found: $DB_PATH" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
target="$BACKUP_DIR/$(basename "$DB_PATH")-$timestamp.db"

# The quoted SQL string is required by the sqlite3 dot-command parser.
sqlite3 "$DB_PATH" ".backup '$target'"

integrity="$(sqlite3 "$target" "PRAGMA integrity_check;")"
if [ "$integrity" != "ok" ]; then
  echo "error: backup integrity check failed: $integrity" >&2
  exit 1
fi

# Flush the backup's WAL into the main file and remove empty sidecars so the
# artifact is a single self-contained .db file.
sqlite3 "$target" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null
if [ ! -s "$target-wal" ]; then
  rm -f "$target-wal" "$target-shm"
fi

echo "Backup written to $target"
echo "integrity_check: ok"
