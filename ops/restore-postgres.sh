#!/usr/bin/env bash
set -euo pipefail
umask 077

if [ "$#" -ne 1 ]; then
  echo "usage: ENV_FILE=.env.production ops/restore-postgres.sh /path/to/backup.dump" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"
[[ "$ENV_FILE" = /* ]] || ENV_FILE="$ROOT_DIR/$ENV_FILE"
DUMP_FILE="$1"

[ -f "$DUMP_FILE" ] && [ ! -L "$DUMP_FILE" ] || { echo "backup file not found" >&2; exit 2; }
mode="$(stat -c %a "$DUMP_FILE")"
((8#$mode & 077)) && { echo "backup file permissions are too broad" >&2; exit 2; }
if [ -f "$DUMP_FILE.sha256" ]; then
  sidecar_mode="$(stat -c %a "$DUMP_FILE.sha256")"
  ((8#$sidecar_mode & 077)) && { echo "checksum permissions are too broad" >&2; exit 2; }
  (cd "$(dirname "$DUMP_FILE")" && sha256sum -c "$(basename "$DUMP_FILE").sha256" >/dev/null)
fi
[ -f "$ENV_FILE" ] && [ ! -L "$ENV_FILE" ] || { echo "environment file not found" >&2; exit 2; }

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

echo "This will restore the selected backup into database $POSTGRES_DB on ${POSTGRES_CONTAINER:-relay-postgres}." >&2
echo "Set CONFIRM_RESTORE=yes to continue." >&2
[ "${CONFIRM_RESTORE:-no}" = yes ] || exit 3

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-relay-postgres}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
if [ "$(head -c 5 "$DUMP_FILE")" = PGDMP ]; then
  "$DOCKER_BIN" exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" "$POSTGRES_CONTAINER" \
    pg_restore --clean --if-exists --no-owner \
      --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <"$DUMP_FILE"
else
  "$DOCKER_BIN" exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" "$POSTGRES_CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <"$DUMP_FILE"
fi
