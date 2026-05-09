#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 path/to/backup.dump" >&2
  exit 1
fi

backup="$1"
if [ ! -f "$backup" ]; then
  echo "backup not found: $backup" >&2
  exit 1
fi

project="lihan-ai-restore-drill-$(date -u +%Y%m%d%H%M%S)"
container="${project}-postgres"
password="restore_drill_password"

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "$container" \
  -e POSTGRES_USER=restore \
  -e POSTGRES_PASSWORD="$password" \
  -e POSTGRES_DB=restore \
  postgres:15-alpine >/dev/null

ready=0
for _ in $(seq 1 30); do
  if docker exec "$container" pg_isready -U restore -d restore >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "restore drill postgres did not become ready" >&2
  exit 1
fi

docker exec -i "$container" pg_restore --clean --if-exists --no-owner -U restore -d restore < "$backup"

required_tables="users tokens channels abilities logs options"
for table in $required_tables; do
  docker exec "$container" psql -U restore -d restore -tA -c "select count(*) from $table;" >/dev/null
done

echo "restore drill passed: $backup"
