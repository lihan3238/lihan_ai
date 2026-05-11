#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

usage() {
  cat >&2 <<'USAGE'
usage: ops/ops-dashboard.sh <open|close|ps|render>
USAGE
  exit 2
}

command="${1:-}"
case "$command" in
  open|close|ps|render) ;;
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

compose_dashboard() {
  docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE_PATH" \
    -f "$ROOT_DIR/docker-compose.ops-dashboard.yml" "$@"
}

render_dashboard() {
  (cd "$ROOT_DIR" && ENV_FILE="$ENV_FILE_PATH" bash ops/ops-health-report.sh render)
}

case "$command" in
  render)
    render_dashboard
    ;;
  open)
    render_dashboard
    compose_dashboard up -d ops-dashboard
    echo "Ops dashboard is available on the origin loopback at http://127.0.0.1:${OPS_DASHBOARD_PORT:-3021}"
    ;;
  close)
    compose_dashboard stop ops-dashboard >/dev/null 2>&1 || true
    compose_dashboard rm -f ops-dashboard >/dev/null 2>&1 || true
    ;;
  ps)
    compose_dashboard ps ops-dashboard
    ;;
esac
