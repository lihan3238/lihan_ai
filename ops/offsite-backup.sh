#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
RESTIC_KEEP_DAILY="${RESTIC_KEEP_DAILY:-14}"
RESTIC_KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-8}"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [ -z "${RESTIC_PASSWORD:-}" ]; then
  echo "RESTIC_PASSWORD is not set" >&2
  exit 2
fi

if [ -z "${RESTIC_REPOSITORY:-}" ]; then
  echo "RESTIC_REPOSITORY is not set" >&2
  exit 2
fi

if ! command -v restic >/dev/null 2>&1; then
  echo "restic is not installed" >&2
  exit 1
fi

cd "$ROOT_DIR"

backup="$(ENV_FILE="$ENV_FILE" bash ops/backup-postgres.sh)"
redacted_snapshot="$(ENV_FILE="$ENV_FILE" bash ops/export-config-snapshot.sh)"
private_snapshot=""
if [ -n "${CONFIG_SNAPSHOT_GPG_RECIPIENT:-}" ]; then
  private_snapshot="$(ENV_FILE="$ENV_FILE" bash ops/export-config-snapshot.sh --private)"
else
  echo "WARN CONFIG_SNAPSHOT_GPG_RECIPIENT is not set; skipping GPG private config snapshot" >&2
fi

if ! restic snapshots >/dev/null 2>&1; then
  restic init
fi

set -- "$backup" "$redacted_snapshot" "$ENV_FILE"
if [ -f "${backup}.sha256" ]; then
  set -- "$@" "${backup}.sha256"
fi
if [ -n "$private_snapshot" ]; then
  set -- "$@" "$private_snapshot"
fi

restic backup "$@"
restic forget --keep-daily "$RESTIC_KEEP_DAILY" --keep-weekly "$RESTIC_KEEP_WEEKLY" --prune
restic check

echo "offsite backup passed"
