#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="$ROOT_DIR/$ENV_FILE"
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

COMPOSE_PROJECT="${DEPLOY_COMPOSE_PROJECT:-lihan_ai}"

case "${1:-}" in
  open)
    docker compose --env-file "$ENV_FILE" -p "$COMPOSE_PROJECT" \
      -f "$ROOT_DIR/docker-compose.yml" \
      -f "$ROOT_DIR/docker-compose.prod.yml" \
      -f "$ROOT_DIR/docker-compose.cpa.yml" \
      -f "$ROOT_DIR/docker-compose.cpa.ui.yml" \
      up -d --no-deps --force-recreate cli-proxy-api
    ;;
  close)
    docker compose --env-file "$ENV_FILE" -p "$COMPOSE_PROJECT" \
      -f "$ROOT_DIR/docker-compose.yml" \
      -f "$ROOT_DIR/docker-compose.prod.yml" \
      -f "$ROOT_DIR/docker-compose.cpa.yml" \
      up -d --no-deps --force-recreate cli-proxy-api
    ;;
  *)
    echo "usage: ENV_FILE=.env.production ops/cpa-ui.sh open|close" >&2
    exit 2
    ;;
esac
