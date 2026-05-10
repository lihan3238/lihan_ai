#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 path/to/backup.dump" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"
backup="$1"
checksum="${backup}.sha256"

case "$ENV_FILE" in
  /*) ;;
  *) ENV_FILE="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

if [ ! -f "$backup" ]; then
  echo "backup not found: $backup" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${DEPLOY_COMPOSE_PROJECT:-}}"

compose() {
  if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
    docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.prod.yml" "$@"
  else
    docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/docker-compose.prod.yml" "$@"
  fi
}

if [ -f "$checksum" ] && command -v sha256sum >/dev/null 2>&1; then
  (cd "$(dirname "$backup")" && sha256sum -c "$(basename "$checksum")")
fi

compose exec -T postgres pg_restore -l < "$backup" >/dev/null
echo "backup is readable: $backup"
