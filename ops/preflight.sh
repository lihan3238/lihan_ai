#!/usr/bin/env sh
set -eu

missing=0

require_file() {
  if [ ! -f "$1" ]; then
    echo "missing required file: $1" >&2
    missing=1
  fi
}

require_file ".env"
require_file "docker-compose.yml"
require_file "Caddyfile"

if [ "$missing" -ne 0 ]; then
  exit 1
fi

if grep -q "CHANGE_ME" .env; then
  echo ".env still contains CHANGE_ME placeholders" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not in PATH" >&2
  exit 1
fi

docker compose config >/dev/null
echo "preflight passed"
