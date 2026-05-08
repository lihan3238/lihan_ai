#!/usr/bin/env sh
set -eu

ENV_FILE="${ENV_FILE:-.env}"
BACKUP_DIR="${BACKUP_DIR:-backups/postgres}"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

mkdir -p "$BACKUP_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
target="$BACKUP_DIR/${POSTGRES_DB}_${timestamp}.dump"
checksum="${target}.sha256"

docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$target"
docker compose exec -T postgres pg_restore -l < "$target" >/dev/null

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$(dirname "$target")" && sha256sum "$(basename "$target")" > "$(basename "$checksum")")
fi

chmod 600 "$target" "$checksum" 2>/dev/null || true
find "$BACKUP_DIR" -type f -name "*.dump" -mtime +"${BACKUP_RETENTION_DAYS:-14}" -delete
find "$BACKUP_DIR" -type f -name "*.dump.sha256" -mtime +"${BACKUP_RETENTION_DAYS:-14}" -delete

echo "$target"
