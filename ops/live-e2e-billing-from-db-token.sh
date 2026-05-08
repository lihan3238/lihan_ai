#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${NEW_API_ENV_FILE:-$ROOT_DIR/.env}"
TOKEN_NAME="${1:-${NEW_API_TEST_TOKEN_NAME:-}}"
MODEL="${NEW_API_TEST_MODEL:-glm-5.1}"
MAX_TOKENS="${NEW_API_TEST_MAX_TOKENS:-24}"
E2E_BILLING_SCRIPT="${E2E_BILLING_SCRIPT:-$ROOT_DIR/ops/e2e-api-billing.sh}"
BASE_URL="${NEW_API_BASE_URL:-}"

if [ -z "$TOKEN_NAME" ]; then
  echo "token name is required" >&2
  echo "usage: $0 <token-name>" >&2
  echo "or: NEW_API_TEST_TOKEN_NAME=<token-name> $0" >&2
  exit 2
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

POSTGRES_USER="${POSTGRES_USER:-newapi}"
POSTGRES_DB="${POSTGRES_DB:-newapi}"

sql_literal() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

TOKEN_NAME_SQL="$(sql_literal "$TOKEN_NAME")"

token="$(
  docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.dev.yml" \
    exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA \
    -c "select key from tokens where name = $TOKEN_NAME_SQL and status = 1 and deleted_at is null order by id limit 1;" |
    tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -n 1
)"

if [ -z "$token" ]; then
  echo "token not found: $TOKEN_NAME" >&2
  exit 1
fi

printf 'Running live billing E2E with token name: %s\n' "$TOKEN_NAME"
printf 'Model:      %s\n' "$MODEL"
printf 'Max tok:    %s\n\n' "$MAX_TOKENS"

NEW_API_TEST_TOKEN="$token" \
NEW_API_TEST_MODEL="$MODEL" \
NEW_API_TEST_MAX_TOKENS="$MAX_TOKENS" \
NEW_API_BASE_URL="$BASE_URL" \
"$E2E_BILLING_SCRIPT"
