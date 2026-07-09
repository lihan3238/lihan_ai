#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: ENV_FILE=.env.production ops/restore-postgres.sh /path/to/backup.sql" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"
DUMP_FILE="$1"

if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="$ROOT_DIR/$ENV_FILE"
fi

if [[ ! -f "$DUMP_FILE" ]]; then
  echo "backup file not found: $DUMP_FILE" >&2
  exit 2
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

echo "This will restore $DUMP_FILE into database $POSTGRES_DB on relay-postgres."
echo "Set CONFIRM_RESTORE=yes to continue." >&2
if [[ "${CONFIRM_RESTORE:-no}" != "yes" ]]; then
  exit 3
fi

docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" relay-postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$DUMP_FILE"
