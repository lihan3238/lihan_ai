#!/usr/bin/env sh
set -eu

ENV_FILE="${ENV_FILE:-.env}"
missing=0

require_file() {
  if [ ! -f "$1" ]; then
    echo "missing required file: $1" >&2
    missing=1
  fi
}

require_file "$ENV_FILE"
require_file "docker-compose.yml"
require_file "Caddyfile"

if [ "$missing" -ne 0 ]; then
  exit 1
fi

if grep -v '^[[:space:]]*#' "$ENV_FILE" | grep -q "CHANGE_ME"; then
  echo "$ENV_FILE still contains CHANGE_ME placeholders" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not in PATH" >&2
  exit 1
fi

docker compose --env-file "$ENV_FILE" config >/dev/null
echo "preflight passed"
