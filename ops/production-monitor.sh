#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

usage() {
  echo "usage: ENV_FILE=.env.production $0 runtime|backup|offsite|audit|restore-drill" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

mode="$1"
case "$mode" in
  runtime|backup|offsite|audit|restore-drill) ;;
  *)
    usage
    exit 2
    ;;
esac

case "$ENV_FILE" in
  /*) ;;
  *) ENV_FILE="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

MONITOR_LOG_DIR="${MONITOR_LOG_DIR:-$ROOT_DIR/logs}"
case "$MONITOR_LOG_DIR" in
  /*) ;;
  *) MONITOR_LOG_DIR="$ROOT_DIR/$MONITOR_LOG_DIR" ;;
esac
mkdir -p "$MONITOR_LOG_DIR"

MONITOR_PROJECT_NAME="${MONITOR_PROJECT_NAME:-${COMPOSE_PROJECT_NAME:-${DEPLOY_COMPOSE_PROJECT:-lihan_ai}}}"
MONITOR_ALERT_WEBHOOK_URL="${MONITOR_ALERT_WEBHOOK_URL:-}"
MONITOR_ALERT_REPEAT_SECONDS="${MONITOR_ALERT_REPEAT_SECONDS:-3600}"
MONITOR_ALERT_TIMEOUT_SECONDS="${MONITOR_ALERT_TIMEOUT_SECONDS:-10}"
MONITOR_PUSH_RUNTIME_URL="${MONITOR_PUSH_RUNTIME_URL:-}"
MONITOR_PUSH_BACKUP_URL="${MONITOR_PUSH_BACKUP_URL:-}"
MONITOR_PUSH_OFFSITE_URL="${MONITOR_PUSH_OFFSITE_URL:-}"
MONITOR_PUSH_AUDIT_URL="${MONITOR_PUSH_AUDIT_URL:-}"
MONITOR_PUSH_RESTORE_DRILL_URL="${MONITOR_PUSH_RESTORE_DRILL_URL:-}"

case "$MONITOR_ALERT_REPEAT_SECONDS" in
  ''|*[!0-9]*) MONITOR_ALERT_REPEAT_SECONDS=3600 ;;
esac
case "$MONITOR_ALERT_TIMEOUT_SECONDS" in
  ''|*[!0-9]*) MONITOR_ALERT_TIMEOUT_SECONDS=10 ;;
esac

log_file="$MONITOR_LOG_DIR/production-monitor-$mode.log"
status_file="$MONITOR_LOG_DIR/production-monitor-$mode.status"
alert_state_file="$MONITOR_LOG_DIR/production-monitor-$mode.alert-state"

utc_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

epoch_now() {
  date -u +%s
}

host_name() {
  hostname 2>/dev/null || printf 'unknown'
}

read_status() {
  file="$1"
  if [ -f "$file" ]; then
    sed -n 's/^status=//p' "$file" | tail -n 1
  fi
}

read_last_alert_epoch() {
  file="$1"
  if [ -f "$file" ]; then
    value="$(sed -n 's/^last_alert_epoch=//p' "$file" | tail -n 1)"
    case "$value" in
      ''|*[!0-9]*) printf '0' ;;
      *) printf '%s' "$value" ;;
    esac
  else
    printf '0'
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_status() {
  result="$1"
  exit_code="$2"
  checked_at="$3"
  tmp_file="$status_file.tmp.$$"
  {
    printf 'status=%s\n' "$result"
    printf 'mode=%s\n' "$mode"
    printf 'checked_at=%s\n' "$checked_at"
    printf 'exit_code=%s\n' "$exit_code"
    printf 'log_file=%s\n' "$log_file"
  } > "$tmp_file"
  mv "$tmp_file" "$status_file"
}

send_alert() {
  event="$1"
  result="$2"
  exit_code="$3"
  checked_at="$4"
  now_epoch="$5"

  [ -n "$MONITOR_ALERT_WEBHOOK_URL" ] || return 0
  if ! command -v curl >/dev/null 2>&1; then
    printf '%s alert skipped: curl is not installed\n' "$(utc_now)" >> "$log_file"
    return 0
  fi

  payload="$(printf '{"project":"%s","mode":"%s","status":"%s","event":"%s","host":"%s","checked_at":"%s","exit_code":%s,"log_file":"%s"}' \
    "$(json_escape "$MONITOR_PROJECT_NAME")" \
    "$(json_escape "$mode")" \
    "$(json_escape "$result")" \
    "$(json_escape "$event")" \
    "$(json_escape "$(host_name)")" \
    "$(json_escape "$checked_at")" \
    "$exit_code" \
    "$(json_escape "$log_file")")"

  if curl -fsS --max-time "$MONITOR_ALERT_TIMEOUT_SECONDS" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$MONITOR_ALERT_WEBHOOK_URL" >/dev/null 2>&1; then
    {
      printf 'last_alert_epoch=%s\n' "$now_epoch"
      printf 'last_alert_status=%s\n' "$result"
      printf 'last_alert_event=%s\n' "$event"
    } > "$alert_state_file"
    printf '%s alert sent: %s %s\n' "$(utc_now)" "$event" "$result" >> "$log_file"
  else
    printf '%s alert failed: webhook request did not complete\n' "$(utc_now)" >> "$log_file"
  fi
}

maybe_alert() {
  result="$1"
  previous_status="$2"
  exit_code="$3"
  checked_at="$4"
  now_epoch="$5"

  if [ "$result" = "FAIL" ]; then
    last_alert_epoch="$(read_last_alert_epoch "$alert_state_file")"
    if [ "$previous_status" != "FAIL" ] || [ $((now_epoch - last_alert_epoch)) -ge "$MONITOR_ALERT_REPEAT_SECONDS" ]; then
      send_alert "failure" "$result" "$exit_code" "$checked_at" "$now_epoch"
    fi
  elif [ "$result" = "PASS" ] && [ "$previous_status" = "FAIL" ]; then
    send_alert "recovery" "$result" "$exit_code" "$checked_at" "$now_epoch"
  fi
}

push_url_for_mode() {
  case "$mode" in
    runtime) printf '%s' "$MONITOR_PUSH_RUNTIME_URL" ;;
    backup) printf '%s' "$MONITOR_PUSH_BACKUP_URL" ;;
    offsite) printf '%s' "$MONITOR_PUSH_OFFSITE_URL" ;;
    audit) printf '%s' "$MONITOR_PUSH_AUDIT_URL" ;;
    restore-drill) printf '%s' "$MONITOR_PUSH_RESTORE_DRILL_URL" ;;
  esac
}

send_push() {
  result="$1"
  duration_seconds="$2"
  push_url="$(push_url_for_mode)"

  [ -n "$push_url" ] || return 0
  if ! command -v curl >/dev/null 2>&1; then
    printf '%s push skipped: curl is not installed\n' "$(utc_now)" >> "$log_file"
    return 0
  fi

  if [ "$result" = "PASS" ]; then
    push_status="up"
  else
    push_status="down"
  fi

  case "$push_url" in
    *\?*) separator="&" ;;
    *) separator="?" ;;
  esac

  if curl -fsS --max-time "$MONITOR_ALERT_TIMEOUT_SECONDS" \
    "${push_url}${separator}status=${push_status}&msg=${mode}-${result}&ping=${duration_seconds}" >/dev/null 2>&1; then
    printf '%s push sent: %s %s\n' "$(utc_now)" "$mode" "$push_status" >> "$log_file"
  else
    printf '%s push failed: %s heartbeat did not complete\n' "$(utc_now)" "$mode" >> "$log_file"
  fi
}

latest_backup() {
  backup_dir="${BACKUP_DIR:-backups/postgres}"
  case "$backup_dir" in
    /*) ;;
    *) backup_dir="$ROOT_DIR/$backup_dir" ;;
  esac

  find "$backup_dir" -type f -name '*.dump' 2>/dev/null | sort | tail -n 1
}

run_audit() {
  audit_status=0
  OPS_HEALTH_CURRENT_MODE=audit ENV_FILE="$ENV_FILE" bash ops/ops-health-report.sh collect || audit_status="$?"
  OPS_HEALTH_CURRENT_MODE=audit ENV_FILE="$ENV_FILE" bash ops/ops-health-report.sh render || {
    render_status="$?"
    if [ "$audit_status" -eq 0 ]; then
      audit_status="$render_status"
    fi
  }
  return "$audit_status"
}

run_restore_drill() {
  backup_path="$(latest_backup)"
  if [ -z "$backup_path" ]; then
    echo "no restore drill backup found under ${BACKUP_DIR:-backups/postgres}" >&2
    return 1
  fi
  printf 'restore drill backup: %s\n' "$backup_path"
  ENV_FILE="$ENV_FILE" bash ops/drill-restore-stack.sh "$backup_path"
}

run_mode() {
  case "$mode" in
    runtime)
      ENV_FILE="$ENV_FILE" bash ops/check-production-runtime.sh
      ;;
    backup)
      backup_path="$(ENV_FILE="$ENV_FILE" bash ops/backup-postgres.sh)"
      printf 'backup created: %s\n' "$backup_path"
      ENV_FILE="$ENV_FILE" bash ops/verify-postgres-backup.sh "$backup_path"
      ;;
    offsite)
      ENV_FILE="$ENV_FILE" bash ops/offsite-backup.sh
      ;;
    audit)
      run_audit
      ;;
    restore-drill)
      run_restore_drill
      ;;
  esac
}

cd "$ROOT_DIR"
previous_status="$(read_status "$status_file" || true)"
started_at="$(utc_now)"
started_epoch="$(epoch_now)"
exit_code=0

{
  printf '=== production-monitor %s START %s ===\n' "$mode" "$started_at"
  printf 'root=%s\n' "$ROOT_DIR"
  printf 'env_file=%s\n' "$ENV_FILE"
  printf 'project=%s\n' "$MONITOR_PROJECT_NAME"
  run_mode
} >> "$log_file" 2>&1 || exit_code="$?"

finished_at="$(utc_now)"
if [ "$exit_code" -eq 0 ]; then
  result="PASS"
else
  result="FAIL"
fi

{
  printf 'result=%s\n' "$result"
  printf 'exit_code=%s\n' "$exit_code"
  printf 'finished_at=%s\n' "$finished_at"
  printf '=== production-monitor %s END %s ===\n' "$mode" "$finished_at"
} >> "$log_file" 2>&1

write_status "$result" "$exit_code" "$finished_at"
if [ "$mode" = "audit" ] || [ "$mode" = "restore-drill" ]; then
  ENV_FILE="$ENV_FILE" bash ops/ops-health-report.sh render >/dev/null 2>&1 || true
fi
duration_seconds=$(( $(epoch_now) - started_epoch ))
if [ "$duration_seconds" -lt 0 ]; then
  duration_seconds=0
fi
send_push "$result" "$duration_seconds"
maybe_alert "$result" "${previous_status:-}" "$exit_code" "$finished_at" "$(epoch_now)"

if [ "$exit_code" -ne 0 ]; then
  echo "production monitor $mode failed; see $log_file" >&2
  exit "$exit_code"
fi

echo "production monitor $mode passed; see $log_file"
