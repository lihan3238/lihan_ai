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

"$ROOT_DIR/ops/compose.sh" ps

docker inspect relay-postgres relay-redis relay-new-api \
  --format '{{.Name}} state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} image={{.Config.Image}}'

docker exec relay-new-api sh -lc \
  "wget -q -O - http://localhost:3000/api/status | grep -o '\"success\":\\s*true'"

if docker inspect relay-cpa >/dev/null 2>&1; then
  docker inspect relay-cpa \
    --format '{{.Name}} state={{.State.Status}} image={{.Config.Image}}'
  curl -fsS --max-time 5 "http://${CPA_BIND_IP:-127.0.0.1}:${CPA_UI_PORT:-8317}/management.html" >/dev/null
fi

if docker inspect relay-cloudflared >/dev/null 2>&1; then
  docker inspect relay-cloudflared \
    --format '{{.Name}} state={{.State.Status}} image={{.Config.Image}}'
fi
