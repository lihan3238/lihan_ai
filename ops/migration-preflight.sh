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

DEPLOY_PATH="${DEPLOY_PATH:-/opt/lihan_ai}"
SOURCE_ENV_FILE="${SOURCE_ENV_FILE:-.env.production}"
TARGET_ENV_FILE="${TARGET_ENV_FILE:-.env.production}"

if [ "${MIGRATION_DRY_RUN:-${DRY_RUN:-0}}" = "1" ]; then
  echo "DRY RUN migration preflight"
  echo "ssh $SOURCE_SSH check source repo, compose, and current database"
  echo "ssh $TARGET_SSH check target repo, compose, and restore drill prerequisites"
  echo "create source backup, copy it through local machine, run target isolated restore drill"
  exit 0
fi

tmp_backup="$(mktemp)"
cleanup() {
  rm -f "$tmp_backup"
}
trap cleanup EXIT

ssh "$SOURCE_SSH" "cd '$DEPLOY_PATH' && test -f '$SOURCE_ENV_FILE' && docker compose version >/dev/null && ENV_FILE='$SOURCE_ENV_FILE' bash ops/preflight.sh"
ssh "$TARGET_SSH" "cd '$DEPLOY_PATH' && test -f '$TARGET_ENV_FILE' && docker compose version >/dev/null && ENV_FILE='$TARGET_ENV_FILE' bash ops/preflight.sh"

backup_path="$(ssh "$SOURCE_SSH" "cd '$DEPLOY_PATH' && ENV_FILE='$SOURCE_ENV_FILE' bash ops/backup-postgres.sh")"
scp "$SOURCE_SSH:$DEPLOY_PATH/$backup_path" "$tmp_backup" >/dev/null
scp "$tmp_backup" "$TARGET_SSH:/tmp/lihan-ai-restore-drill.dump" >/dev/null
ssh "$TARGET_SSH" "cd '$DEPLOY_PATH' && bash ops/drill-restore-postgres.sh /tmp/lihan-ai-restore-drill.dump && rm -f /tmp/lihan-ai-restore-drill.dump"

echo "migration preflight passed"
