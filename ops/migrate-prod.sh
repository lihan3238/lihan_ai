#!/usr/bin/env sh
set -eu

if [ -z "${SOURCE_SSH:-}" ]; then
  echo "SOURCE_SSH is not set" >&2
  exit 2
fi

if [ -z "${TARGET_SSH:-}" ]; then
  echo "TARGET_SSH is not set" >&2
  exit 2
fi

if [ "${CONFIRM_FINAL_CUTOVER:-no}" != "yes" ]; then
  echo "CONFIRM_FINAL_CUTOVER must be yes; CONFIRM_FINAL_CUTOVER=yes is required before stopping the source service or restoring over the target database" >&2
  exit 2
fi

DEPLOY_PATH="${DEPLOY_PATH:-/opt/lihan_ai}"
SOURCE_ENV_FILE="${SOURCE_ENV_FILE:-.env.production}"
TARGET_ENV_FILE="${TARGET_ENV_FILE:-.env.production}"

if [ "${MIGRATION_DRY_RUN:-${DRY_RUN:-0}}" = "1" ]; then
  echo "DRY RUN final production migration"
  echo "ssh $SOURCE_SSH cd $DEPLOY_PATH and docker compose stop caddy new-api"
  echo "ssh $SOURCE_SSH create final dump with PostgreSQL backup"
  echo "copy final backup from source to target through local machine"
  echo "ssh $TARGET_SSH start postgres/redis, restore target database, start production stack"
  echo "verify target New API /api/status; DNS or edge upstream switch remains manual"
  exit 0
fi

tmp_backup="$(mktemp)"
cleanup() {
  rm -f "$tmp_backup"
}
trap cleanup EXIT

source_compose="docker compose --env-file $SOURCE_ENV_FILE -f docker-compose.yml -f docker-compose.prod.yml"
target_compose="docker compose --env-file $TARGET_ENV_FILE -f docker-compose.yml -f docker-compose.prod.yml"

ssh "$SOURCE_SSH" "cd '$DEPLOY_PATH' && $source_compose stop caddy new-api"
backup_path="$(ssh "$SOURCE_SSH" "cd '$DEPLOY_PATH' && ENV_FILE='$SOURCE_ENV_FILE' bash ops/backup-postgres.sh")"
scp "$SOURCE_SSH:$DEPLOY_PATH/$backup_path" "$tmp_backup" >/dev/null
scp "$tmp_backup" "$TARGET_SSH:/tmp/lihan-ai-final-migration.dump" >/dev/null

ssh "$TARGET_SSH" "cd '$DEPLOY_PATH' && \
  test -f '$TARGET_ENV_FILE' && \
  $target_compose up -d postgres redis && \
  ENV_FILE='$TARGET_ENV_FILE' bash ops/restore-postgres.sh /tmp/lihan-ai-final-migration.dump && \
  rm -f /tmp/lihan-ai-final-migration.dump && \
  $target_compose up -d --remove-orphans"

ssh "$TARGET_SSH" "cd '$DEPLOY_PATH' && \
  ready=0; \
  for i in \$(seq 1 40); do \
    if $target_compose exec -T new-api wget -q -O - http://localhost:3000/api/status 2>/dev/null | grep -q '\"success\"[[:space:]]*:[[:space:]]*true'; then ready=1; break; fi; \
    sleep 3; \
  done; \
  test \"\$ready\" = 1"

echo "migration cutover data move passed; switch DNS or edge upstream after manual external verification"
