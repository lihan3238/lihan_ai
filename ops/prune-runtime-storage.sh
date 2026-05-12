#!/usr/bin/env sh
set -eu

usage() {
  echo "usage: $0 [all|backups|snapshots|logs]" >&2
}

mode="${1:-all}"
case "$mode" in
  all|backups|snapshots|logs) ;;
  *)
    usage
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

case "$ENV_FILE" in
  /*) ;;
  *) ENV_FILE="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

to_abs_dir() {
  value="$1"
  default_value="$2"
  if [ -z "$value" ]; then
    value="$default_value"
  fi
  case "$value" in
    /*) printf '%s' "$value" ;;
    *) printf '%s/%s' "$ROOT_DIR" "$value" ;;
  esac
}

int_or_default() {
  value="$1"
  default_value="$2"
  case "$value" in
    ''|*[!0-9]*) printf '%s' "$default_value" ;;
    *) printf '%s' "$value" ;;
  esac
}

file_size() {
  stat -c '%s' "$1" 2>/dev/null || wc -c < "$1" | tr -d ' '
}

mb_to_bytes() {
  mb="$(int_or_default "$1" 0)"
  echo $((mb * 1024 * 1024))
}

sorted_files() {
  dir="$1"
  shift
  [ -d "$dir" ] || return 0
  find "$dir" -type f "$@" -printf '%T@ %p\n' 2>/dev/null | sort -n | sed 's/^[^ ]* //'
}

delete_dump() {
  dump="$1"
  rm -f "$dump" "$dump.sha256"
}

delete_oldest_by_count() {
  list_file="$1"
  keep="$2"
  delete_command="$3"

  [ "$keep" -gt 0 ] || return 0
  count="$(wc -l < "$list_file" | tr -d ' ')"
  while [ "$count" -gt "$keep" ]; do
    oldest="$(sed -n '1p' "$list_file")"
    [ -n "$oldest" ] || break
    if [ "$delete_command" = "dump" ]; then
      delete_dump "$oldest"
    else
      rm -f "$oldest"
    fi
    sed -i '1d' "$list_file"
    count=$((count - 1))
  done
}

delete_oldest_by_total() {
  list_file="$1"
  max_bytes="$2"
  delete_command="$3"

  [ "$max_bytes" -gt 0 ] || return 0
  while :; do
    count=0
    total=0
    while IFS= read -r path; do
      [ -f "$path" ] || continue
      count=$((count + 1))
      total=$((total + $(file_size "$path")))
    done < "$list_file"

    [ "$count" -gt 1 ] || break
    [ "$total" -gt "$max_bytes" ] || break

    oldest="$(sed -n '1p' "$list_file")"
    [ -n "$oldest" ] || break
    if [ "$delete_command" = "dump" ]; then
      delete_dump "$oldest"
    else
      rm -f "$oldest"
    fi
    sed -i '1d' "$list_file"
  done
}

prune_backups() {
  backup_dir="$(to_abs_dir "${BACKUP_DIR:-}" "backups/postgres")"
  [ -d "$backup_dir" ] || return 0

  retention_days="$(int_or_default "${BACKUP_RETENTION_DAYS:-14}" 14)"
  if [ "$retention_days" -gt 0 ]; then
    find "$backup_dir" -type f -name '*.dump' -mtime +"$retention_days" -print 2>/dev/null | while IFS= read -r dump; do
      delete_dump "$dump"
    done
  fi

  find "$backup_dir" -type f -name '*.dump.sha256' -print 2>/dev/null | while IFS= read -r checksum; do
    dump="${checksum%.sha256}"
    [ -f "$dump" ] || rm -f "$checksum"
  done

  tmp_list="$(mktemp)"
  sorted_files "$backup_dir" -name '*.dump' > "$tmp_list"
  delete_oldest_by_count "$tmp_list" "$(int_or_default "${BACKUP_KEEP:-30}" 30)" dump

  sorted_files "$backup_dir" -name '*.dump' > "$tmp_list"
  delete_oldest_by_total "$tmp_list" "$(mb_to_bytes "${BACKUP_MAX_TOTAL_MB:-2048}")" dump
  rm -f "$tmp_list"
}

prune_snapshots() {
  snapshot_dir="$(to_abs_dir "${CONFIG_SNAPSHOT_DIR:-}" "snapshots/config")"
  [ -d "$snapshot_dir" ] || return 0

  tmp_list="$(mktemp)"
  sorted_files "$snapshot_dir" \( -name 'config-redacted-*.json' -o -name 'config-private-*.json.gpg' \) > "$tmp_list"
  delete_oldest_by_count "$tmp_list" "$(int_or_default "${CONFIG_SNAPSHOT_KEEP:-30}" 30)" file

  sorted_files "$snapshot_dir" \( -name 'config-redacted-*.json' -o -name 'config-private-*.json.gpg' \) > "$tmp_list"
  delete_oldest_by_total "$tmp_list" "$(mb_to_bytes "${CONFIG_SNAPSHOT_MAX_TOTAL_MB:-256}")" file
  rm -f "$tmp_list"
}

prune_logs() {
  log_dir="$(to_abs_dir "${BACKUP_CRON_LOG_DIR:-}" "logs")"
  mkdir -p "$log_dir"
  active_log="$log_dir/backup-cron.log"
  max_bytes="$(mb_to_bytes "${BACKUP_CRON_LOG_MAX_MB:-10}")"

  if [ "$max_bytes" -gt 0 ] && [ -f "$active_log" ] && [ "$(file_size "$active_log")" -gt "$max_bytes" ]; then
    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    rotated="$log_dir/backup-cron.$timestamp.log"
    if [ -e "$rotated" ]; then
      rotated="$log_dir/backup-cron.$timestamp.$$.log"
    fi
    mv "$active_log" "$rotated"
    : > "$active_log"
    chmod 600 "$active_log" "$rotated" 2>/dev/null || true
  elif [ ! -f "$active_log" ]; then
    : > "$active_log"
    chmod 600 "$active_log" 2>/dev/null || true
  fi

  tmp_list="$(mktemp)"
  sorted_files "$log_dir" -name 'backup-cron.*.log' > "$tmp_list"
  delete_oldest_by_count "$tmp_list" "$(int_or_default "${BACKUP_CRON_LOG_KEEP:-5}" 5)" file
  rm -f "$tmp_list"
}

case "$mode" in
  all)
    prune_logs
    prune_backups
    prune_snapshots
    ;;
  backups) prune_backups ;;
  snapshots) prune_snapshots ;;
  logs) prune_logs ;;
esac
