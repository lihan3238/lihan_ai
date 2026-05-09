#!/usr/bin/env sh
set -eu

if [ -z "${DEPLOY_HOST:-}" ]; then
  echo "DEPLOY_HOST is not set" >&2
  exit 2
fi

DEPLOY_PATH="${DEPLOY_PATH:-/opt/lihan_ai}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-.env.production}"
RUN_LIVE_E2E="${RUN_LIVE_E2E:-0}"
NEW_API_TEST_MODEL="${NEW_API_TEST_MODEL:-glm-5.1}"

if [ "$RUN_LIVE_E2E" = "1" ] && [ -z "${NEW_API_TEST_TOKEN_NAME:-}" ]; then
  echo "NEW_API_TEST_TOKEN_NAME is required when RUN_LIVE_E2E=1" >&2
  exit 2
fi

if [ "${VERIFY_DRY_RUN:-${DRY_RUN:-0}}" = "1" ]; then
  echo "DRY RUN verify $DEPLOY_HOST"
  echo "ssh $DEPLOY_HOST"
  echo "  docker compose ps"
  echo "  check New API /api/status inside the container network"
  echo "  optionally run named-token billing E2E"
  exit 0
fi

ssh "$DEPLOY_HOST" "DEPLOY_PATH='$DEPLOY_PATH' DEPLOY_ENV_FILE='$DEPLOY_ENV_FILE' RUN_LIVE_E2E='$RUN_LIVE_E2E' NEW_API_TEST_TOKEN_NAME='${NEW_API_TEST_TOKEN_NAME:-}' NEW_API_TEST_MODEL='$NEW_API_TEST_MODEL' sh -s" <<'REMOTE'
set -eu
cd "$DEPLOY_PATH"

if [ ! -f "$DEPLOY_ENV_FILE" ]; then
  echo "missing $DEPLOY_ENV_FILE on remote host" >&2
  exit 1
fi

compose="docker compose --env-file $DEPLOY_ENV_FILE -f docker-compose.yml -f docker-compose.prod.yml"
$compose config >/dev/null
$compose ps

$compose exec -T new-api wget -q -O - http://localhost:3000/api/status | grep -q '"success"[[:space:]]*:[[:space:]]*true'

if [ "$RUN_LIVE_E2E" = "1" ]; then
  NEW_API_TEST_TOKEN_NAME="$NEW_API_TEST_TOKEN_NAME" NEW_API_TEST_MODEL="$NEW_API_TEST_MODEL" bash ops/live-e2e-billing-from-db-token.sh
fi

echo "remote production verification passed"
REMOTE
