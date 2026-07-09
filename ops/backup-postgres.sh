#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="$ROOT_DIR/$ENV_FILE"
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
mkdir -p "$BACKUP_DIR/postgres"
OUT="$BACKUP_DIR/postgres/newapi-$(date -u +%Y%m%dT%H%M%SZ).sql"

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" relay-postgres \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$OUT"

sha256sum "$OUT" > "$OUT.sha256"
echo "$OUT"
