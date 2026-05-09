#!/usr/bin/env sh
set -eu

if [ -z "${DEPLOY_HOST:-}" ]; then
  echo "DEPLOY_HOST is not set" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/lihan_ai}"
DEPLOY_ENV="${DEPLOY_ENV:-production}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-.env.production}"
DEPLOY_REF="${DEPLOY_REF:-main}"
DEPLOY_REPO="${DEPLOY_REPO:-$(git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || true)}"
RUN_REMOTE_BACKUP="${RUN_REMOTE_BACKUP:-1}"
ALLOW_NON_MAIN_PROD_DEPLOY="${ALLOW_NON_MAIN_PROD_DEPLOY:-0}"

if [ -z "$DEPLOY_REPO" ]; then
  echo "DEPLOY_REPO is not set and git remote origin is unavailable" >&2
  exit 2
fi

if [ "$DEPLOY_ENV" = "production" ] && [ "$DEPLOY_REF" != "main" ]; then
  if [ "$ALLOW_NON_MAIN_PROD_DEPLOY" != "1" ]; then
    echo "production deploy requires DEPLOY_REF=main; set ALLOW_NON_MAIN_PROD_DEPLOY=1 only for a documented emergency override" >&2
    exit 2
  fi
  echo "WARN non-main production deploy override: DEPLOY_REF=$DEPLOY_REF" >&2
fi

remote_compose="docker compose --env-file $DEPLOY_ENV_FILE -f docker-compose.yml -f docker-compose.prod.yml"

if [ "${DEPLOY_DRY_RUN:-${DRY_RUN:-0}}" = "1" ]; then
  echo "DRY RUN deploy to $DEPLOY_HOST"
  echo "ssh $DEPLOY_HOST"
  echo "  ensure repo $DEPLOY_REPO at $DEPLOY_PATH ref $DEPLOY_REF"
  echo "  check $DEPLOY_ENV_FILE and Docker Compose config"
  echo "  create pre-deploy PostgreSQL backup when an existing database is running"
  echo "  $remote_compose pull"
  echo "  $remote_compose up -d --remove-orphans"
  echo "  verify New API /api/status inside the container network"
  exit 0
fi

ssh "$DEPLOY_HOST" "DEPLOY_PATH='$DEPLOY_PATH' DEPLOY_ENV='$DEPLOY_ENV' DEPLOY_ENV_FILE='$DEPLOY_ENV_FILE' DEPLOY_REF='$DEPLOY_REF' DEPLOY_REPO='$DEPLOY_REPO' RUN_REMOTE_BACKUP='$RUN_REMOTE_BACKUP' sh -s" <<'REMOTE'
set -eu

if [ ! -d "$DEPLOY_PATH/.git" ]; then
  parent="$(dirname "$DEPLOY_PATH")"
  mkdir -p "$parent"
  git clone "$DEPLOY_REPO" "$DEPLOY_PATH"
fi

cd "$DEPLOY_PATH"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "remote repository has local changes; refusing deploy" >&2
  exit 1
fi

git fetch origin "$DEPLOY_REF"
git checkout -B "deploy/$DEPLOY_ENV" FETCH_HEAD
git submodule update --init --recursive

if [ ! -f "$DEPLOY_ENV_FILE" ]; then
  echo "missing $DEPLOY_ENV_FILE on remote host" >&2
  exit 1
fi

ENV_FILE="$DEPLOY_ENV_FILE" bash ops/preflight.sh

compose="docker compose --env-file $DEPLOY_ENV_FILE -f docker-compose.yml -f docker-compose.prod.yml"

if [ "$RUN_REMOTE_BACKUP" = "1" ] && $compose ps postgres 2>/dev/null | grep -q "relay-postgres"; then
  ENV_FILE="$DEPLOY_ENV_FILE" bash ops/backup-postgres.sh >/dev/null
else
  echo "WARN no running PostgreSQL service found before deploy; skipped pre-deploy backup"
fi

$compose pull
$compose up -d --remove-orphans

ready=0
for _ in $(seq 1 40); do
  if $compose exec -T new-api wget -q -O - http://localhost:3000/api/status 2>/dev/null | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
    ready=1
    break
  fi
  sleep 3
done

if [ "$ready" -ne 1 ]; then
  $compose ps
  echo "New API did not become healthy after deploy" >&2
  exit 1
fi

$compose ps
echo "production deploy passed"
REMOTE
