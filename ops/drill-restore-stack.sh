#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 path/to/backup.dump" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"
backup="$1"

case "$ENV_FILE" in
  /*) ;;
  *) ENV_FILE="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

if [ ! -f "$backup" ]; then
  echo "backup not found: $backup" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

project="lihan-ai-stack-drill-$(date -u +%Y%m%d%H%M%S)"
network="${project}-net"
postgres="${project}-postgres"
redis="${project}-redis"
new_api="${project}-new-api"
pg_password="restore_drill_password"
redis_password="restore_drill_redis_password"
session_secret="restore_drill_session_secret_0123456789abcdef"
image="${NEW_API_IMAGE:-calciumion/new-api:latest}"

cleanup() {
  docker rm -f "$new_api" "$postgres" "$redis" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$network" >/dev/null

docker run -d --name "$postgres" --network "$network" --network-alias postgres \
  -e POSTGRES_USER=restore \
  -e POSTGRES_PASSWORD="$pg_password" \
  -e POSTGRES_DB=restore \
  postgres:15-alpine >/dev/null

ready=0
for _ in $(seq 1 45); do
  if docker exec "$postgres" pg_isready -U restore -d restore >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "restore drill postgres did not become ready" >&2
  exit 1
fi

ready=0
for _ in $(seq 1 15); do
  if docker exec "$postgres" psql -U restore -d restore -c 'select 1;' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  docker logs --tail=80 "$postgres" >&2 || true
  echo "restore drill postgres did not accept a test query" >&2
  exit 1
fi

pg_restore_status=1
for attempt in $(seq 1 3); do
  if docker exec -i "$postgres" pg_restore --clean --if-exists --no-owner -U restore -d restore < "$backup"; then
    pg_restore_status=0
    break
  fi
  echo "WARN restore drill pg_restore failed on attempt $attempt; retrying" >&2
  docker logs --tail=40 "$postgres" >&2 || true
  sleep 3
done

if [ "$pg_restore_status" -ne 0 ]; then
  echo "restore drill pg_restore failed" >&2
  exit 1
fi

docker run -d --name "$redis" --network "$network" --network-alias redis \
  redis:7-alpine redis-server --appendonly yes --requirepass "$redis_password" >/dev/null

docker run -d --name "$new_api" --network "$network" \
  -e SQL_DSN="postgresql://restore:$pg_password@postgres:5432/restore" \
  -e REDIS_CONN_STRING="redis://:$redis_password@redis:6379" \
  -e SESSION_SECRET="$session_secret" \
  -e TZ="${TZ:-Asia/Shanghai}" \
  -e ERROR_LOG_ENABLED=false \
  "$image" --log-dir /tmp/new-api-logs >/dev/null

ready=0
for _ in $(seq 1 90); do
  if docker exec "$new_api" wget -q -O - http://localhost:3000/api/status 2>/dev/null | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  docker logs --tail=80 "$new_api" >&2 || true
  echo "restore stack drill new-api did not become ready" >&2
  exit 1
fi

for table in users tokens channels abilities logs options; do
  docker exec "$postgres" psql -U restore -d restore -tA -c "select count(*) from $table;" >/dev/null
done

echo "restore stack drill passed: $backup"
