#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

case "$ENV_FILE" in
  /*) ENV_FILE_PATH="$ENV_FILE" ;;
  *) ENV_FILE_PATH="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ ! -f "$ENV_FILE_PATH" ]; then
  echo "missing $ENV_FILE_PATH" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE_PATH"
set +a

BACKUP_CRON_LOG_DIR="${BACKUP_CRON_LOG_DIR:-$ROOT_DIR/logs}"
case "$BACKUP_CRON_LOG_DIR" in
  /*) ;;
  *) BACKUP_CRON_LOG_DIR="$ROOT_DIR/$BACKUP_CRON_LOG_DIR" ;;
esac

mkdir -p "$BACKUP_CRON_LOG_DIR"
log_file="$BACKUP_CRON_LOG_DIR/backup-cron.log"

utc_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

cd "$ROOT_DIR"

{
  printf '=== backup-cron START %s ===\n' "$(utc_now)"
  printf 'env_file=%s\n' "$ENV_FILE_PATH"
  backup_path="$(ENV_FILE="$ENV_FILE_PATH" bash ops/backup-postgres.sh)"
  printf 'backup created: %s\n' "$backup_path"
  ENV_FILE="$ENV_FILE_PATH" bash ops/verify-postgres-backup.sh "$backup_path"
  printf '=== backup-cron END %s ===\n' "$(utc_now)"
} >> "$log_file" 2>&1

echo "backup cron passed; see $log_file"
