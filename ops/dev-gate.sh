#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
feature_dir="${1:-}"

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [local-feature-dir]" >&2
  exit 2
fi

run() {
  echo "+ $*"
  "$@"
}

cd "$ROOT_DIR"

run git diff --check
run bash -n ops/*.sh scripts/*.sh tests/*.test.sh

for test in tests/*.test.sh; do
  run bash "$test"
done

run bash scripts/verify-repo.sh --skip-docker

run docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.dev.yml config
run docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local-build.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cpa.ui.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cloudflare-tunnel.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cloudflare-tunnel.yml config
run docker compose --env-file .env.production.example -f docker-compose.edge.yml config

if [ -n "$feature_dir" ]; then
  run bash ops/feature-completion-check.sh "$feature_dir"
fi

echo "dev gate passed"
