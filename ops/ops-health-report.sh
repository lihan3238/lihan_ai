#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"

usage() {
  cat >&2 <<'USAGE'
usage: ENV_FILE=.env.production ops/ops-health-report.sh collect|render
USAGE
  exit 2
}

command="${1:-}"
case "$command" in
  collect|render) ;;
  *) usage ;;
esac

case "$ENV_FILE" in
  /*) ENV_FILE_PATH="$ENV_FILE" ;;
  *) ENV_FILE_PATH="$ROOT_DIR/$ENV_FILE" ;;
esac

if [ -f "$ENV_FILE_PATH" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE_PATH"
  set +a
elif [ "$command" = "collect" ]; then
  echo "missing env file: $ENV_FILE_PATH" >&2
  exit 1
fi

MONITOR_LOG_DIR="${MONITOR_LOG_DIR:-$ROOT_DIR/logs}"
case "$MONITOR_LOG_DIR" in
  /*) ;;
  *) MONITOR_LOG_DIR="$ROOT_DIR/$MONITOR_LOG_DIR" ;;
esac

BACKUP_DIR="${BACKUP_DIR:-backups/postgres}"
case "$BACKUP_DIR" in
  /*) ;;
  *) BACKUP_DIR="$ROOT_DIR/$BACKUP_DIR" ;;
esac

OPS_HEALTH_DIR="${OPS_HEALTH_DIR:-$MONITOR_LOG_DIR/ops-health}"
case "$OPS_HEALTH_DIR" in
  /*) ;;
  *) OPS_HEALTH_DIR="$ROOT_DIR/$OPS_HEALTH_DIR" ;;
esac
mkdir -p "$OPS_HEALTH_DIR"

OPS_HEALTH_CURRENT_MODE="${OPS_HEALTH_CURRENT_MODE:-}"
status_json="$OPS_HEALTH_DIR/status.json"
index_html="$OPS_HEALTH_DIR/index.html"

RUNTIME_MAX_AGE_SECONDS="${OPS_HEALTH_RUNTIME_MAX_AGE_SECONDS:-600}"
BACKUP_MAX_AGE_SECONDS="${OPS_HEALTH_BACKUP_MAX_AGE_SECONDS:-108000}"
OFFSITE_MAX_AGE_SECONDS="${OPS_HEALTH_OFFSITE_MAX_AGE_SECONDS:-108000}"
RESTORE_DRILL_WARN_SECONDS="${OPS_HEALTH_RESTORE_DRILL_WARN_SECONDS:-3024000}"
DISK_WARN_PERCENT="${OPS_HEALTH_DISK_WARN_PERCENT:-80}"
DISK_FAIL_PERCENT="${OPS_HEALTH_DISK_FAIL_PERCENT:-90}"
INODE_WARN_PERCENT="${OPS_HEALTH_INODE_WARN_PERCENT:-80}"
INODE_FAIL_PERCENT="${OPS_HEALTH_INODE_FAIL_PERCENT:-90}"

for numeric in RUNTIME_MAX_AGE_SECONDS BACKUP_MAX_AGE_SECONDS OFFSITE_MAX_AGE_SECONDS RESTORE_DRILL_WARN_SECONDS DISK_WARN_PERCENT DISK_FAIL_PERCENT INODE_WARN_PERCENT INODE_FAIL_PERCENT; do
  value="$(eval "printf '%s' \"\${$numeric}\"")"
  case "$value" in
    ''|*[!0-9]*) eval "$numeric=0" ;;
  esac
done

utc_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

epoch_now() {
  if [ -n "${OPS_HEALTH_NOW_EPOCH:-}" ]; then
    printf '%s' "$OPS_HEALTH_NOW_EPOCH"
  else
    date -u +%s
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

parse_epoch() {
  value="$1"
  if [ -z "$value" ]; then
    return 1
  fi
  date -u -d "$value" +%s 2>/dev/null || return 1
}

status_field() {
  file="$1"
  field="$2"
  [ -f "$file" ] || return 1
  sed -n "s/^$field=//p" "$file" | tail -n 1
}

age_for_checked_at() {
  checked_at="$1"
  now="$2"
  checked_epoch="$(parse_epoch "$checked_at" 2>/dev/null || true)"
  if [ -z "$checked_epoch" ]; then
    printf -- '-1'
    return 0
  fi
  age=$((now - checked_epoch))
  if [ "$age" -lt 0 ]; then
    age=0
  fi
  printf '%s' "$age"
}

eval_monitor_mode() {
  mode="$1"
  max_age="$2"
  missing_status="$3"
  stale_status="$4"
  now="$5"
  file="$MONITOR_LOG_DIR/production-monitor-$mode.status"

  if [ ! -f "$file" ]; then
    printf '%s\t-1\t\tstatus file not recorded yet\n' "$missing_status"
    return 0
  fi

  last_status="$(status_field "$file" status || true)"
  checked_at="$(status_field "$file" checked_at || true)"
  age="$(age_for_checked_at "$checked_at" "$now")"

  if [ "$last_status" != "PASS" ]; then
    printf 'FAIL\t%s\t%s\tlast run was %s\n' "$age" "$checked_at" "${last_status:-UNKNOWN}"
  elif [ "$age" -lt 0 ]; then
    printf '%s\t%s\t%s\tchecked_at is not parseable\n' "$stale_status" "$age" "$checked_at"
  elif [ "$max_age" -gt 0 ] && [ "$age" -gt "$max_age" ]; then
    printf '%s\t%s\t%s\tlast PASS is stale\n' "$stale_status" "$age" "$checked_at"
  else
    printf 'PASS\t%s\t%s\tlast PASS is fresh\n' "$age" "$checked_at"
  fi
}

field_from_eval() {
  printf '%s' "$1" | cut -f "$2"
}

rank_status() {
  candidate="$1"
  case "$candidate" in
    FAIL) overall_status="FAIL" ;;
    WARN)
      if [ "$overall_status" = "PASS" ]; then
        overall_status="WARN"
      fi
      ;;
  esac
}

size_of_file() {
  file="$1"
  wc -c < "$file" | tr -d ' '
}

mtime_epoch() {
  file="$1"
  stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || printf '0'
}

percent_status() {
  percent="$1"
  warn="$2"
  fail="$3"
  if [ -z "$percent" ]; then
    printf 'WARN'
  elif [ "$percent" -ge "$fail" ]; then
    printf 'FAIL'
  elif [ "$percent" -ge "$warn" ]; then
    printf 'WARN'
  else
    printf 'PASS'
  fi
}

collect_backup_inventory() {
  dump_count=0
  dump_total_bytes=0
  latest_dump_path=""
  latest_dump=""
  latest_dump_epoch=0
  latest_dump_age_seconds=-1
  latest_checksum_exists=false
  backup_inventory_status="FAIL"
  backup_inventory_message="no local dump found"

  if [ -d "$BACKUP_DIR" ]; then
    dump_list="$(find "$BACKUP_DIR" -type f -name '*.dump' 2>/dev/null | sort || true)"
    if [ -n "$dump_list" ]; then
      dump_count="$(printf '%s\n' "$dump_list" | wc -l | tr -d ' ')"
      latest_dump_path="$(printf '%s\n' "$dump_list" | tail -n 1)"
      latest_dump="$(basename "$latest_dump_path")"
      latest_dump_epoch="$(mtime_epoch "$latest_dump_path")"
      if [ "$latest_dump_epoch" -gt 0 ]; then
        latest_dump_age_seconds=$((now_epoch - latest_dump_epoch))
        if [ "$latest_dump_age_seconds" -lt 0 ]; then
          latest_dump_age_seconds=0
        fi
      fi
      if [ -f "${latest_dump_path}.sha256" ]; then
        latest_checksum_exists=true
      fi
      for dump in $dump_list; do
        dump_total_bytes=$((dump_total_bytes + $(size_of_file "$dump")))
      done
      backup_inventory_status="PASS"
      backup_inventory_message="local dumps are present"
    fi
  else
    backup_inventory_message="backup directory is missing"
  fi
}

collect_restic_status() {
  restic_status="FAIL"
  restic_message="RESTIC_PASSWORD is not set"
  restic_latest_snapshot=""

  if [ -z "${RESTIC_PASSWORD:-}" ]; then
    return 0
  fi
  if [ -z "${RESTIC_REPOSITORY:-}" ]; then
    restic_message="RESTIC_REPOSITORY is not set"
    return 0
  fi
  if ! command -v restic >/dev/null 2>&1; then
    restic_message="restic is not installed"
    return 0
  fi

  restic_output="$(restic snapshots --last 1 2>&1)" || {
    restic_message="restic snapshots failed"
    return 0
  }
  restic_latest_snapshot="$(printf '%s\n' "$restic_output" | sed '/^[[:space:]]*$/d' | tail -n 1)"
  restic_status="PASS"
  restic_message="restic snapshots can be listed"
}

collect_disk_status() {
  disk_percent="$(df -P "$ROOT_DIR" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}' || true)"
  inode_percent="$(df -Pi "$ROOT_DIR" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}' || true)"
  case "$disk_percent" in ''|*[!0-9]*) disk_percent="" ;; esac
  case "$inode_percent" in ''|*[!0-9]*) inode_percent="" ;; esac
  disk_status="$(percent_status "$disk_percent" "$DISK_WARN_PERCENT" "$DISK_FAIL_PERCENT")"
  inode_status="$(percent_status "$inode_percent" "$INODE_WARN_PERCENT" "$INODE_FAIL_PERCENT")"
}

inspect_container() {
  name="$1"
  docker inspect -f '{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || true
}

collect_docker_status() {
  docker_status="PASS"
  docker_message="required containers are running"
  docker_containers=""

  if ! command -v docker >/dev/null 2>&1; then
    docker_status="FAIL"
    docker_message="docker is not installed"
    return 0
  fi

  required="relay-new-api relay-postgres relay-redis"
  if [ "${DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL:-0}" = "1" ]; then
    required="$required relay-cloudflared"
  else
    required="$required relay-caddy"
  fi
  if [ "${DEPLOY_INCLUDE_CPA:-0}" = "1" ]; then
    required="$required relay-cpa"
  fi

  for container in $required; do
    line="$(inspect_container "$container")"
    if [ -z "$line" ]; then
      docker_status="FAIL"
      docker_message="required container is missing"
      line="$container missing"
    else
      case "$line" in
        *"state=running"*) ;;
        *)
          docker_status="FAIL"
          docker_message="required container is not running"
          ;;
      esac
      case "$line" in
        *"restart=unless-stopped"*) ;;
        *)
          if [ "$docker_status" != "FAIL" ]; then
            docker_status="WARN"
            docker_message="container restart policy is not unless-stopped"
          fi
          ;;
      esac
      case "$line" in
        *"health=unhealthy"*)
          docker_status="FAIL"
          docker_message="container health is unhealthy"
          ;;
      esac
    fi
    docker_containers="${docker_containers}${docker_containers:+; }$line"
  done
}

collect_values() {
  generated_at="$(utc_now)"
  now_epoch="$(epoch_now)"
  overall_status="PASS"

  runtime_eval="$(eval_monitor_mode runtime "$RUNTIME_MAX_AGE_SECONDS" FAIL FAIL "$now_epoch")"
  backup_eval="$(eval_monitor_mode backup "$BACKUP_MAX_AGE_SECONDS" FAIL FAIL "$now_epoch")"
  offsite_eval="$(eval_monitor_mode offsite "$OFFSITE_MAX_AGE_SECONDS" FAIL FAIL "$now_epoch")"
  audit_eval="$(eval_monitor_mode audit "$RUNTIME_MAX_AGE_SECONDS" PASS WARN "$now_epoch")"
  restore_eval="$(eval_monitor_mode restore-drill "$RESTORE_DRILL_WARN_SECONDS" WARN WARN "$now_epoch")"

  runtime_status="$(field_from_eval "$runtime_eval" 1)"
  runtime_age_seconds="$(field_from_eval "$runtime_eval" 2)"
  runtime_checked_at="$(field_from_eval "$runtime_eval" 3)"
  runtime_message="$(field_from_eval "$runtime_eval" 4)"
  backup_status="$(field_from_eval "$backup_eval" 1)"
  backup_age_seconds="$(field_from_eval "$backup_eval" 2)"
  backup_checked_at="$(field_from_eval "$backup_eval" 3)"
  backup_message="$(field_from_eval "$backup_eval" 4)"
  offsite_status="$(field_from_eval "$offsite_eval" 1)"
  offsite_age_seconds="$(field_from_eval "$offsite_eval" 2)"
  offsite_checked_at="$(field_from_eval "$offsite_eval" 3)"
  offsite_message="$(field_from_eval "$offsite_eval" 4)"
  audit_status="$(field_from_eval "$audit_eval" 1)"
  audit_age_seconds="$(field_from_eval "$audit_eval" 2)"
  audit_checked_at="$(field_from_eval "$audit_eval" 3)"
  audit_message="$(field_from_eval "$audit_eval" 4)"
  restore_drill_status="$(field_from_eval "$restore_eval" 1)"
  restore_drill_age_seconds="$(field_from_eval "$restore_eval" 2)"
  restore_drill_checked_at="$(field_from_eval "$restore_eval" 3)"
  restore_drill_message="$(field_from_eval "$restore_eval" 4)"

  collect_backup_inventory
  collect_restic_status
  collect_disk_status
  collect_docker_status

  if [ "${DEPLOY_INCLUDE_CPA:-0}" = "1" ] && [ "${DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL:-0}" = "1" ]; then
    topology="cpa+tunnel"
  elif [ "${DEPLOY_INCLUDE_CPA:-0}" = "1" ]; then
    topology="cpa+caddy"
  elif [ "${DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL:-0}" = "1" ]; then
    topology="tunnel"
  else
    topology="caddy"
  fi

  for status in "$runtime_status" "$backup_status" "$offsite_status" "$restore_drill_status" "$backup_inventory_status" "$restic_status" "$disk_status" "$inode_status" "$docker_status"; do
    rank_status "$status"
  done
  if [ "$OPS_HEALTH_CURRENT_MODE" != "audit" ]; then
    rank_status "$audit_status"
  fi
}

write_json() {
  tmp_file="$status_json.tmp.$$"
  {
    printf '{\n'
    printf '  "generated_at":"%s",\n' "$(json_escape "$generated_at")"
    printf '  "overall_status":"%s",\n' "$overall_status"
    printf '  "topology":"%s",\n' "$(json_escape "$topology")"
    printf '  "cron":{"runtime":"*/5 minutes","audit":"*/15 minutes","backup":"daily","offsite":"daily","restore_drill":"monthly"},\n'
    printf '  "monitors":{\n'
    printf '    "runtime":{"status":"%s","age_seconds":%s,"checked_at":"%s","message":"%s"},\n' "$runtime_status" "$runtime_age_seconds" "$(json_escape "$runtime_checked_at")" "$(json_escape "$runtime_message")"
    printf '    "backup":{"status":"%s","age_seconds":%s,"checked_at":"%s","message":"%s"},\n' "$backup_status" "$backup_age_seconds" "$(json_escape "$backup_checked_at")" "$(json_escape "$backup_message")"
    printf '    "offsite":{"status":"%s","age_seconds":%s,"checked_at":"%s","message":"%s"},\n' "$offsite_status" "$offsite_age_seconds" "$(json_escape "$offsite_checked_at")" "$(json_escape "$offsite_message")"
    printf '    "audit":{"status":"%s","age_seconds":%s,"checked_at":"%s","message":"%s"},\n' "$audit_status" "$audit_age_seconds" "$(json_escape "$audit_checked_at")" "$(json_escape "$audit_message")"
    printf '    "restore_drill":{"status":"%s","age_seconds":%s,"checked_at":"%s","message":"%s"}\n' "$restore_drill_status" "$restore_drill_age_seconds" "$(json_escape "$restore_drill_checked_at")" "$(json_escape "$restore_drill_message")"
    printf '  },\n'
    printf '  "backups":{"status":"%s","message":"%s","directory":"%s","dump_count":%s,"total_bytes":%s,"latest_dump":"%s","latest_dump_age_seconds":%s,"latest_checksum_exists":%s},\n' "$backup_inventory_status" "$(json_escape "$backup_inventory_message")" "$(json_escape "$BACKUP_DIR")" "$dump_count" "$dump_total_bytes" "$(json_escape "$latest_dump")" "$latest_dump_age_seconds" "$latest_checksum_exists"
    printf '  "restic_status":"%s",\n' "$restic_status"
    printf '  "restic_message":"%s",\n' "$(json_escape "$restic_message")"
    printf '  "restic_latest_snapshot":"%s",\n' "$(json_escape "$restic_latest_snapshot")"
    printf '  "disk_status":"%s",\n' "$disk_status"
    printf '  "disk_used_percent":%s,\n' "${disk_percent:-0}"
    printf '  "inode_status":"%s",\n' "$inode_status"
    printf '  "inode_used_percent":%s,\n' "${inode_percent:-0}"
    printf '  "docker_status":"%s",\n' "$docker_status"
    printf '  "docker_message":"%s",\n' "$(json_escape "$docker_message")"
    printf '  "docker_containers":"%s"\n' "$(json_escape "$docker_containers")"
    printf '}\n'
  } > "$tmp_file"
  mv "$tmp_file" "$status_json"
}

status_class() {
  case "$1" in
    PASS) printf 'pass' ;;
    WARN) printf 'warn' ;;
    FAIL) printf 'fail' ;;
    *) printf 'warn' ;;
  esac
}

write_html() {
  tmp_file="$index_html.tmp.$$"
  {
    cat <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Ops Health Dashboard</title>
  <style>
    :root { color-scheme: light dark; font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; background: #0f172a; color: #e5e7eb; }
    main { max-width: 1180px; margin: 0 auto; padding: 28px; }
    h1 { margin: 0; font-size: 28px; }
    h2 { margin: 0 0 12px; font-size: 17px; }
    .muted { color: #94a3b8; }
    .top { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; margin-bottom: 22px; }
    .badge { display: inline-flex; align-items: center; border-radius: 999px; padding: 5px 10px; font-size: 12px; font-weight: 700; letter-spacing: .04em; }
    .pass { background: #14532d; color: #bbf7d0; }
    .warn { background: #713f12; color: #fde68a; }
    .fail { background: #7f1d1d; color: #fecaca; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px; }
    section, .card { border: 1px solid #263449; background: #111827; border-radius: 8px; padding: 16px; }
    dl { display: grid; grid-template-columns: minmax(110px, 42%) 1fr; gap: 8px 12px; margin: 0; }
    dt { color: #94a3b8; }
    dd { margin: 0; overflow-wrap: anywhere; }
    code { color: #bfdbfe; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border-bottom: 1px solid #263449; padding: 9px 7px; text-align: left; vertical-align: top; }
    th { color: #94a3b8; font-weight: 600; }
    @media (max-width: 720px) { main { padding: 18px; } .top { flex-direction: column; } }
  </style>
</head>
<body>
<main>
HTML
    printf '  <div class="top"><div><h1>Ops Health Dashboard</h1><p class="muted">Generated at %s · topology %s</p></div><span class="badge %s">%s</span></div>\n' \
      "$(html_escape "$generated_at")" "$(html_escape "$topology")" "$(status_class "$overall_status")" "$(html_escape "$overall_status")"
    cat <<'HTML'
  <div class="grid">
    <section>
      <h2>Cron monitor status</h2>
      <table>
        <thead><tr><th>Mode</th><th>Status</th><th>Last check</th><th>Message</th></tr></thead>
        <tbody>
HTML
    for row in \
      "runtime|$runtime_status|$runtime_checked_at|$runtime_message" \
      "backup|$backup_status|$backup_checked_at|$backup_message" \
      "offsite|$offsite_status|$offsite_checked_at|$offsite_message" \
      "audit|$audit_status|$audit_checked_at|$audit_message" \
      "restore-drill|$restore_drill_status|$restore_drill_checked_at|$restore_drill_message"; do
      mode="$(printf '%s' "$row" | cut -d '|' -f 1)"
      row_status="$(printf '%s' "$row" | cut -d '|' -f 2)"
      checked="$(printf '%s' "$row" | cut -d '|' -f 3)"
      message="$(printf '%s' "$row" | cut -d '|' -f 4-)"
      printf '          <tr><td><code>%s</code></td><td><span class="badge %s">%s</span></td><td>%s</td><td>%s</td></tr>\n' \
        "$(html_escape "$mode")" "$(status_class "$row_status")" "$(html_escape "$row_status")" "$(html_escape "$checked")" "$(html_escape "$message")"
    done
    cat <<'HTML'
        </tbody>
      </table>
    </section>
    <section>
      <h2>Backup inventory</h2>
HTML
    printf '      <dl><dt>Status</dt><dd><span class="badge %s">%s</span></dd><dt>Directory</dt><dd><code>%s</code></dd><dt>Dumps</dt><dd>%s files, %s bytes</dd><dt>Latest</dt><dd><code>%s</code></dd><dt>Checksum</dt><dd>%s</dd></dl>\n' \
      "$(status_class "$backup_inventory_status")" "$(html_escape "$backup_inventory_status")" "$(html_escape "$BACKUP_DIR")" "$dump_count" "$dump_total_bytes" "$(html_escape "$latest_dump")" "$latest_checksum_exists"
    cat <<'HTML'
    </section>
    <section>
      <h2>Offsite backup</h2>
HTML
    printf '      <dl><dt>Restic</dt><dd><span class="badge %s">%s</span></dd><dt>Message</dt><dd>%s</dd><dt>Latest snapshot</dt><dd><code>%s</code></dd></dl>\n' \
      "$(status_class "$restic_status")" "$(html_escape "$restic_status")" "$(html_escape "$restic_message")" "$(html_escape "$restic_latest_snapshot")"
    cat <<'HTML'
    </section>
    <section>
      <h2>Host resources</h2>
HTML
    printf '      <dl><dt>Disk</dt><dd><span class="badge %s">%s</span> %s%% used</dd><dt>Inodes</dt><dd><span class="badge %s">%s</span> %s%% used</dd></dl>\n' \
      "$(status_class "$disk_status")" "$disk_status" "${disk_percent:-0}" "$(status_class "$inode_status")" "$inode_status" "${inode_percent:-0}"
    cat <<'HTML'
    </section>
    <section>
      <h2>Docker runtime</h2>
HTML
    printf '      <dl><dt>Status</dt><dd><span class="badge %s">%s</span></dd><dt>Message</dt><dd>%s</dd><dt>Containers</dt><dd><code>%s</code></dd></dl>\n' \
      "$(status_class "$docker_status")" "$docker_status" "$(html_escape "$docker_message")" "$(html_escape "$docker_containers")"
    cat <<'HTML'
    </section>
  </div>
</main>
</body>
</html>
HTML
  } > "$tmp_file"
  mv "$tmp_file" "$index_html"
}

collect_values
write_json

case "$command" in
  collect)
    if [ "$overall_status" = "FAIL" ]; then
      echo "ops health report failed; see $status_json" >&2
      exit 1
    fi
    echo "$status_json"
    ;;
  render)
    write_html
    echo "$index_html"
    ;;
esac
