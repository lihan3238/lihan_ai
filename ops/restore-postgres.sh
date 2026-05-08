#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 path/to/backup.dump" >&2
  exit 1
fi

ENV_FILE="${ENV_FILE:-.env}"
backup="$1"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

if [ ! -f "$backup" ]; then
  echo "backup not found: $backup" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

docker compose exec -T postgres pg_restore --clean --if-exists -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$backup"
echo "restore completed from $backup"
