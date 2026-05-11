#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

usage() {
  cat >&2 <<'USAGE'
usage: ops/kuma-ui.sh <open|close|ps>
USAGE
  exit 2
}

command="${1:-}"
case "$command" in
  open|close|ps) ;;
  *) usage ;;
esac

case "$ENV_FILE" in
  /*) ENV_FILE_PATH="$ENV_FILE" ;;
  *) ENV_FILE_PATH="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ ! -f "$ENV_FILE_PATH" ]; then
  echo "missing env file: $ENV_FILE_PATH" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE_PATH"
set +a

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${DEPLOY_COMPOSE_PROJECT:-lihan_ai}}"
DEPLOY_INCLUDE_CPA="${DEPLOY_INCLUDE_CPA:-0}"
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL="${DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL:-0}"

compose_base() {
  if [ "$DEPLOY_INCLUDE_CPA" = "1" ] && [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
      -f "$ROOT_DIR/docker-compose.yml" \
      -f "$ROOT_DIR/docker-compose.prod.yml" \
      -f "$ROOT_DIR/docker-compose.cpa.yml" \
      -f "$ROOT_DIR/docker-compose.cloudflare-tunnel.yml" \
      "$@"
  elif [ "$DEPLOY_INCLUDE_CPA" = "1" ]; then
    docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
      -f "$ROOT_DIR/docker-compose.yml" \
      -f "$ROOT_DIR/docker-compose.prod.yml" \
      -f "$ROOT_DIR/docker-compose.cpa.yml" \
      "$@"
  elif [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
    docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
      -f "$ROOT_DIR/docker-compose.yml" \
      -f "$ROOT_DIR/docker-compose.prod.yml" \
      -f "$ROOT_DIR/docker-compose.cloudflare-tunnel.yml" \
      "$@"
  else
    docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
      -f "$ROOT_DIR/docker-compose.yml" \
      -f "$ROOT_DIR/docker-compose.prod.yml" \
      "$@"
  fi
}

case "$command" in
  open)
    if [ "$DEPLOY_INCLUDE_CPA" = "1" ] && [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
      docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
        -f "$ROOT_DIR/docker-compose.yml" \
        -f "$ROOT_DIR/docker-compose.prod.yml" \
        -f "$ROOT_DIR/docker-compose.cpa.yml" \
        -f "$ROOT_DIR/docker-compose.cloudflare-tunnel.yml" \
        -f "$ROOT_DIR/docker-compose.kuma.ui.yml" \
        up -d --force-recreate --no-deps uptime-kuma
    elif [ "$DEPLOY_INCLUDE_CPA" = "1" ]; then
      docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
        -f "$ROOT_DIR/docker-compose.yml" \
        -f "$ROOT_DIR/docker-compose.prod.yml" \
        -f "$ROOT_DIR/docker-compose.cpa.yml" \
        -f "$ROOT_DIR/docker-compose.kuma.ui.yml" \
        up -d --force-recreate --no-deps uptime-kuma
    elif [ "$DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL" = "1" ]; then
      docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
        -f "$ROOT_DIR/docker-compose.yml" \
        -f "$ROOT_DIR/docker-compose.prod.yml" \
        -f "$ROOT_DIR/docker-compose.cloudflare-tunnel.yml" \
        -f "$ROOT_DIR/docker-compose.kuma.ui.yml" \
        up -d --force-recreate --no-deps uptime-kuma
    else
      docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
        -f "$ROOT_DIR/docker-compose.yml" \
        -f "$ROOT_DIR/docker-compose.prod.yml" \
        -f "$ROOT_DIR/docker-compose.kuma.ui.yml" \
        up -d --force-recreate --no-deps uptime-kuma
    fi
    echo "Kuma UI is available on the origin loopback at http://127.0.0.1:${KUMA_PORT:-3011}"
    ;;
  close)
    compose_base up -d --force-recreate --no-deps uptime-kuma
    ;;
  ps)
    compose_base ps uptime-kuma
    ;;
esac
