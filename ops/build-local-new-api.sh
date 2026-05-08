#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
LOCAL_NEW_API_IMAGE="${LOCAL_NEW_API_IMAGE:-lihan-ai/new-api:local}"

if [ ! -f "$ROOT_DIR/vendor/new-api/Dockerfile" ]; then
  echo "missing vendor/new-api/Dockerfile; run git submodule update --init --recursive" >&2
  exit 1
fi

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

echo "building $LOCAL_NEW_API_IMAGE from vendor/new-api"
docker build -t "$LOCAL_NEW_API_IMAGE" "$ROOT_DIR/vendor/new-api"
