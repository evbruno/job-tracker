#!/usr/bin/env bash
#
# Restore a SQLite backup produced by scripts/backup_sqlite.sh.
#
# Usage:
#   ./scripts/restore_sqlite.sh BACKUP_PATH [TARGET_PATH]
#
# The target defaults to $DATABASE_PATH, then to ./track_my_job_ex_restored.db.
# Stop the application before restoring over the live database. Set FORCE=1 to
# overwrite an existing target file:
#
#   FORCE=1 ./scripts/restore_sqlite.sh backups/my.db-20260101T000000Z.db /data/my.db
set -euo pipefail

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "error: sqlite3 CLI is required for restores" >&2
  exit 1
fi

BACKUP_PATH="${1:?usage: $0 BACKUP_PATH [TARGET_PATH]}"
TARGET_PATH="${2:-${DATABASE_PATH:-track_my_job_ex_restored.db}}"

if [ ! -f "$BACKUP_PATH" ]; then
  echo "error: backup not found: $BACKUP_PATH" >&2
  exit 1
fi

if [ -e "$TARGET_PATH" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "error: target exists: $TARGET_PATH (set FORCE=1 to overwrite)" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_PATH")"

sqlite3 "$BACKUP_PATH" ".backup '$TARGET_PATH'"

integrity="$(sqlite3 "$TARGET_PATH" "PRAGMA integrity_check;")"
if [ "$integrity" != "ok" ]; then
  echo "error: restored database failed integrity_check: $integrity" >&2
  exit 1
fi

echo "Restored $BACKUP_PATH to $TARGET_PATH"
echo "integrity_check: ok"
