#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.local-restore}"
LOCAL_E2E_ADMIN_USERNAME="${LOCAL_E2E_ADMIN_USERNAME:-codex_e2e_admin}"
LOCAL_E2E_ADMIN_PASSWORD="${LOCAL_E2E_ADMIN_PASSWORD:-CodexLocal123!}"
POSTGRES_CONTAINER="${LOCAL_E2E_POSTGRES_CONTAINER:-relay-postgres}"

run_npm() {
  if command -v npm >/dev/null 2>&1; then
    npm "$@"
  elif command -v npm.cmd >/dev/null 2>&1; then
    npm.cmd "$@"
  elif [ -x /mnt/c/Windows/System32/cmd.exe ]; then
    windows_env="NEW_API_BASE_URL:NEW_API_ADMIN_USERNAME:NEW_API_ADMIN_PASSWORD:NEW_API_ADMIN_TARGET_USERNAME:NEW_API_REQUIRE_ADMIN_E2E"
    if [ -n "${WSLENV:-}" ]; then
      WSLENV="$WSLENV:$windows_env" /mnt/c/Windows/System32/cmd.exe /c npm "$@"
    else
      WSLENV="$windows_env" /mnt/c/Windows/System32/cmd.exe /c npm "$@"
    fi
  else
    echo "missing npm; install Node.js/npm in this shell or expose Windows npm to WSL" >&2
    return 127
  fi
}

case "${NEW_API_BASE_URL:-}" in
  "") ;;
  http://localhost|http://localhost:*|http://127.0.0.1|http://127.0.0.1:*) ;;
  *)
    echo "local E2E only accepts localhost targets; got NEW_API_BASE_URL=${NEW_API_BASE_URL}" >&2
    exit 2
    ;;
esac

case "$ENV_FILE" in
  /*) ;;
  *) ENV_FILE="$ROOT_DIR/$ENV_FILE" ;;
esac

env_name="$(basename "$ENV_FILE")"
case "$env_name" in
  .env.local|.env.local-*|*.local|*.local-*) ;;
  *)
    echo "local E2E requires a local restore env file (default .env.local-restore); got $ENV_FILE" >&2
    exit 2
    ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE; restore or create a local env before running E2E" >&2
  exit 2
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

NEW_API_BASE_URL="${NEW_API_BASE_URL:-http://localhost:${NEW_API_DEV_PORT:-3100}}"

case "$NEW_API_BASE_URL" in
  http://localhost|http://localhost:*|http://127.0.0.1|http://127.0.0.1:*) ;;
  *)
    echo "local E2E only accepts localhost targets; got NEW_API_BASE_URL=$NEW_API_BASE_URL" >&2
    exit 2
    ;;
esac

if [ ! -x "$ROOT_DIR/node_modules/.bin/playwright" ]; then
  echo "missing Playwright dependencies; run: npm install && npx playwright install chromium" >&2
  exit 2
fi

if ! run_npm --version >/dev/null 2>&1; then
  echo "missing npm runtime for Playwright; run npm from a shell where Node.js is available" >&2
  exit 2
fi

if ! docker inspect "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
  echo "missing local PostgreSQL container: $POSTGRES_CONTAINER" >&2
  echo "start the local restored stack before running E2E" >&2
  exit 2
fi

cd "$ROOT_DIR"

echo "resetting local E2E admin user: $LOCAL_E2E_ADMIN_USERNAME"
docker exec -i "$POSTGRES_CONTAINER" \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 \
  -v username="$LOCAL_E2E_ADMIN_USERNAME" \
  -v password="$LOCAL_E2E_ADMIN_PASSWORD" <<'SQL'
create extension if not exists pgcrypto;
insert into users (
  username,
  password,
  display_name,
  role,
  status,
  email,
  quota,
  used_quota,
  request_count,
  "group",
  created_at,
  last_login_at
) values (
  :'username',
  crypt(:'password', gen_salt('bf', 10)),
  'Codex E2E Admin',
  100,
  1,
  'codex-e2e@example.test',
  1000000,
  0,
  0,
  'vip',
  extract(epoch from now())::bigint,
  0
) on conflict (username) do update set
  password = excluded.password,
  display_name = excluded.display_name,
  role = 100,
  status = 1,
  deleted_at = null,
  "group" = 'vip';
SQL

echo "running browser smoke E2E against $NEW_API_BASE_URL"
export NEW_API_BASE_URL
run_npm run e2e:web:new-api

echo "running admin user-management E2E against $NEW_API_BASE_URL"
NEW_API_ADMIN_USERNAME="$LOCAL_E2E_ADMIN_USERNAME"
NEW_API_ADMIN_PASSWORD="$LOCAL_E2E_ADMIN_PASSWORD"
NEW_API_ADMIN_TARGET_USERNAME="$LOCAL_E2E_ADMIN_USERNAME"
NEW_API_REQUIRE_ADMIN_E2E=1
export NEW_API_ADMIN_USERNAME NEW_API_ADMIN_PASSWORD NEW_API_ADMIN_TARGET_USERNAME NEW_API_REQUIRE_ADMIN_E2E
run_npm run e2e:web:new-api-admin

echo "local New API E2E passed"
