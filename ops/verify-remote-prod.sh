#!/usr/bin/env sh
set -eu

if [ -z "${DEPLOY_HOST:-}" ]; then
  echo "DEPLOY_HOST is not set" >&2
  exit 2
fi

DEPLOY_PATH_EXPLICIT=0
if [ "${DEPLOY_PATH+x}" = "x" ] && [ -n "${DEPLOY_PATH:-}" ]; then
  DEPLOY_PATH_EXPLICIT=1
fi
DEPLOY_PATH="${DEPLOY_PATH:-}"
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
  echo "  use DEPLOY_PATH when set; otherwise prefer /opt/lihan_ai_deploy/current, then /opt/lihan_ai"
  echo "  docker compose ps"
  echo "  check New API /api/status inside the container network"
  echo "  optionally run named-token billing E2E"
  exit 0
fi

ssh "$DEPLOY_HOST" "DEPLOY_PATH='$DEPLOY_PATH' DEPLOY_PATH_EXPLICIT='$DEPLOY_PATH_EXPLICIT' DEPLOY_ENV_FILE='$DEPLOY_ENV_FILE' RUN_LIVE_E2E='$RUN_LIVE_E2E' NEW_API_TEST_TOKEN_NAME='${NEW_API_TEST_TOKEN_NAME:-}' NEW_API_TEST_MODEL='$NEW_API_TEST_MODEL' sh -s" <<'REMOTE'
set -eu

if [ "${DEPLOY_PATH_EXPLICIT:-0}" != "1" ]; then
  if [ -d /opt/lihan_ai_deploy/current ]; then
    DEPLOY_PATH=/opt/lihan_ai_deploy/current
  else
    DEPLOY_PATH=/opt/lihan_ai
  fi
fi

cd "$DEPLOY_PATH"

if [ ! -f "$DEPLOY_ENV_FILE" ]; then
  echo "missing $DEPLOY_ENV_FILE on remote host" >&2
  exit 1
fi

env_value() {
  key="$1"
  awk -F= -v key="$key" '
    $0 !~ /^[[:space:]]*#/ && $1 == key {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      gsub(/^'\''|'\''$/, "", value)
      print value
      exit
    }
  ' "$DEPLOY_ENV_FILE"
}

DEPLOY_COMPOSE_PROJECT="$(env_value DEPLOY_COMPOSE_PROJECT)"
DEPLOY_COMPOSE_PROJECT="${DEPLOY_COMPOSE_PROJECT:-lihan_ai}"
DEPLOY_INCLUDE_CPA="$(env_value DEPLOY_INCLUDE_CPA)"
DEPLOY_INCLUDE_CPA="${DEPLOY_INCLUDE_CPA:-0}"
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL="$(env_value DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL)"
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL="${DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL:-0}"

compose() {
  if [ "$DEPLOY_INCLUDE_CPA" = "1" ] && [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cloudflare-tunnel.yml "$@"
  elif [ "$DEPLOY_INCLUDE_CPA" = "1" ]; then
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml "$@"
  elif [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cloudflare-tunnel.yml "$@"
  else
    docker compose -p "$DEPLOY_COMPOSE_PROJECT" --env-file "$DEPLOY_ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml "$@"
  fi
}

if [ -x ops/check-production-runtime.sh ]; then
  COMPOSE_PROJECT_NAME="$DEPLOY_COMPOSE_PROJECT" ENV_FILE="$DEPLOY_ENV_FILE" bash ops/check-production-runtime.sh
else
  compose config >/dev/null
  compose ps
  compose exec -T new-api wget -q -O - http://localhost:3000/api/status | grep -q '"success"[[:space:]]*:[[:space:]]*true'
fi

if [ "$RUN_LIVE_E2E" = "1" ]; then
  NEW_API_TEST_TOKEN_NAME="$NEW_API_TEST_TOKEN_NAME" NEW_API_TEST_MODEL="$NEW_API_TEST_MODEL" bash ops/live-e2e-billing-from-db-token.sh
fi

echo "remote production verification passed"
REMOTE
