#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
feature_dir="${1:-}"

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [docs/ai-dev/<YYYY-MM-DD-topic>]" >&2
  exit 2
fi

run() {
  echo "+ $*"
  "$@"
}

if command -v powershell >/dev/null 2>&1; then
  POWERSHELL_BIN="powershell"
elif command -v pwsh >/dev/null 2>&1; then
  POWERSHELL_BIN="pwsh"
elif [ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]; then
  POWERSHELL_BIN="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
else
  echo "missing PowerShell runtime: install powershell or pwsh" >&2
  exit 127
fi

cd "$ROOT_DIR"

run git diff --check
run bash -n ops/*.sh tests/*.test.sh

for test in tests/*.test.sh; do
  run bash "$test"
done

run "$POWERSHELL_BIN" -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/verify-repo.ps1 -SkipDocker

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
