#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"
WITH_CPA="${WITH_CPA:-1}"
WITH_TUNNEL="${WITH_TUNNEL:-0}"

if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="$ROOT_DIR/$ENV_FILE"
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

COMPOSE_PROJECT="${DEPLOY_COMPOSE_PROJECT:-lihan_ai}"
files=(-f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.prod.yml")

if [[ "$WITH_CPA" == "1" ]]; then
  files+=(-f "$ROOT_DIR/docker-compose.cpa.yml")
fi

if [[ "$WITH_TUNNEL" == "1" ]]; then
  files+=(-f "$ROOT_DIR/docker-compose.cloudflare-tunnel.yml")
fi

exec docker compose --env-file "$ENV_FILE" -p "$COMPOSE_PROJECT" "${files[@]}" "$@"
