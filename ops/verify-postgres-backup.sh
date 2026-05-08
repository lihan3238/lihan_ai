#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 path/to/backup.dump" >&2
  exit 1
fi

backup="$1"
checksum="${backup}.sha256"

if [ ! -f "$backup" ]; then
  echo "backup not found: $backup" >&2
  exit 1
fi

if [ -f "$checksum" ] && command -v sha256sum >/dev/null 2>&1; then
  (cd "$(dirname "$backup")" && sha256sum -c "$(basename "$checksum")")
fi

docker compose exec -T postgres pg_restore -l < "$backup" >/dev/null
echo "backup is readable: $backup"
