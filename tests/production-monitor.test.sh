#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q -- "$pattern" "$file" || fail "$file missing pattern: $pattern"
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -q -- "$pattern" "$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
log_dir="$tmp_dir/logs"
backup_dir="$tmp_dir/backups"
snapshot_dir="$tmp_dir/snapshots"
docker_log="$tmp_dir/docker.log"
webhook_log="$tmp_dir/webhook.log"
push_log="$tmp_dir/push.log"
restic_log="$tmp_dir/restic.log"
env_file="$tmp_dir/.env.production"
mkdir -p "$fake_bin" "$log_dir" "$backup_dir" "$snapshot_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$env_file" <<EOF
DEPLOY_ENV=production
DOMAIN=api.example.test
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=1
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
RUNTIME_EXTERNAL_RETRIES=1
RUNTIME_EXTERNAL_RETRY_SECONDS=0
POSTGRES_USER=newapi
POSTGRES_PASSWORD=redacted
POSTGRES_DB=newapi
REDIS_PASSWORD=redacted
SESSION_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
RESTIC_REPOSITORY=sftp:user@backup.example:/srv/restic/lihan-ai
RESTIC_PASSWORD=test-restic-password
CONFIG_SNAPSHOT_DIR=$snapshot_dir
EOF

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"

if [ "$1" = "inspect" ]; then
  case "$*" in
    *"HostConfig.RestartPolicy"*"relay-new-api"*) printf '/relay-new-api restart=unless-stopped state=running health=healthy\n'; exit 0 ;;
    *"HostConfig.RestartPolicy"*"relay-cloudflared"*) printf '/relay-cloudflared restart=unless-stopped state=running health=none\n'; exit 0 ;;
    *"relay-new-api"*) printf 'healthy\n'; exit 0 ;;
    *"relay-cloudflared"*) printf 'running\n'; exit 0 ;;
    *"relay-postgres"*) printf '/relay-postgres restart=unless-stopped state=running health=healthy\n'; exit 0 ;;
    *"relay-redis"*) printf '/relay-redis restart=unless-stopped state=running health=healthy\n'; exit 0 ;;
    *"relay-cpa"*) printf '/relay-cpa restart=unless-stopped state=running health=none\n'; exit 0 ;;
  esac
fi

if [ "$1" = "network" ]; then
  exit 0
fi

if [ "$1" = "run" ]; then
  printf 'fake-container-id\n'
  exit 0
fi

if [ "$1" = "rm" ]; then
  exit 0
fi

if [ "$1" = "exec" ]; then
  case "$*" in
    *" wget "*)
      printf '{"success":true}\n'
      exit 0
      ;;
    *" pg_isready "*|*" select 1;"*|*" pg_restore "*|*" psql "*)
      cat >/dev/null 2>/dev/null || true
      printf '1\n'
      exit 0
      ;;
  esac
  exit 0
fi

if [ "$1" = "port" ] && [ "$2" = "relay-caddy" ]; then
  exit 1
fi

if [ "$1" = "logs" ] && [ "${4:-}" = "relay-cloudflared" ]; then
  printf 'registered tunnel connection\n'
  exit 0
fi

if [ "$1" = "compose" ]; then
  case "$*" in
    *" config")
      exit 0
      ;;
    *" ps postgres")
      printf 'relay-postgres running\n'
      exit 0
      ;;
    *" ps redis")
      printf 'relay-redis running\n'
      exit 0
      ;;
    *" ps new-api")
      printf 'relay-new-api running\n'
      exit 0
      ;;
    *" ps cloudflared")
      printf 'relay-cloudflared running\n'
      exit 0
      ;;
    *" exec -T new-api wget"*)
      printf '{"success":true}\n'
      exit 0
      ;;
    *" pg_dump "*)
      printf 'fake-postgres-dump'
      exit 0
      ;;
    *" pg_restore -l"*)
      cat >/dev/null
      exit 0
      ;;
    *" psql "*)
      printf '{"snapshot_kind":"redacted","generated_at":"2026-05-11T00:00:00Z","data":{}}\n'
      exit 0
      ;;
  esac
fi

echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

cat > "$fake_bin/curl" <<'CURL'
#!/usr/bin/env sh
payload=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--data|--data-raw|--data-binary)
      shift
      payload="${1:-}"
      ;;
    http*)
      url="$1"
      ;;
  esac
  shift || true
done

case "$url" in
  *webhook.example.test*)
    printf '%s\n' "$payload" >> "$FAKE_WEBHOOK_LOG"
    exit 0
    ;;
  *push-fail.example.test*)
    printf '%s\n' "$url" >> "$FAKE_PUSH_LOG"
    exit 28
    ;;
  *push.example.test*)
    printf '%s\n' "$url" >> "$FAKE_PUSH_LOG"
    exit 0
    ;;
esac

if [ "${FAKE_RUNTIME_FAIL:-0}" = "1" ]; then
  exit 22
fi

printf '{"success":true}\n'
CURL
chmod +x "$fake_bin/curl"

cat > "$fake_bin/ss" <<'SS'
#!/usr/bin/env sh
exit 0
SS
chmod +x "$fake_bin/ss"

cat > "$fake_bin/df" <<'DF'
#!/usr/bin/env sh
if [ "$1" = "-Pi" ]; then
  printf 'Filesystem Inodes IUsed IFree IUse%% Mounted on\n'
  printf '/dev/vda1 1000 500 500 50%% /\n'
else
  printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
  printf '/dev/vda1 1000 500 500 50%% /\n'
fi
DF
chmod +x "$fake_bin/df"

cat > "$fake_bin/restic" <<'RESTIC'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_RESTIC_LOG"
case "$1" in
  snapshots|init|backup|forget|check) exit 0 ;;
esac
echo "unexpected restic args: $*" >&2
exit 1
RESTIC
chmod +x "$fake_bin/restic"

run_monitor() {
  PATH="$fake_bin:$PATH" \
    FAKE_DOCKER_LOG="$docker_log" \
    FAKE_WEBHOOK_LOG="$webhook_log" \
    FAKE_PUSH_LOG="$push_log" \
    FAKE_RESTIC_LOG="$restic_log" \
    ENV_FILE="$env_file" \
    MONITOR_LOG_DIR="$log_dir" \
    BACKUP_DIR="$backup_dir" \
    bash "$ROOT_DIR/ops/production-monitor.sh" "$@"
}

: > "$docker_log"
: > "$webhook_log"
: > "$push_log"
run_monitor runtime
assert_contains "$log_dir/production-monitor-runtime.status" "status=PASS"
assert_contains "$log_dir/production-monitor-runtime.status" "mode=runtime"
assert_contains "$log_dir/production-monitor-runtime.status" "log_file=$log_dir/production-monitor-runtime.log"
[ ! -s "$webhook_log" ] || fail "runtime success without webhook should not alert"
assert_contains "$log_dir/production-monitor-runtime.log" "PASS external status"

: > "$webhook_log"
set +e
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  FAKE_RUNTIME_FAIL=1 \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  MONITOR_ALERT_WEBHOOK_URL="https://webhook.example.test/monitor" \
  MONITOR_ALERT_REPEAT_SECONDS=3600 \
  BACKUP_DIR="$backup_dir" \
  bash "$ROOT_DIR/ops/production-monitor.sh" runtime >/dev/null 2>&1
fail_status="$?"
set -e
[ "$fail_status" -ne 0 ] || fail "runtime failure should exit nonzero"
assert_contains "$log_dir/production-monitor-runtime.status" "status=FAIL"
assert_contains "$webhook_log" '"status":"FAIL"'
assert_contains "$webhook_log" '"mode":"runtime"'
assert_not_contains "$webhook_log" "test-restic-password"

set +e
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  FAKE_RUNTIME_FAIL=1 \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  MONITOR_ALERT_WEBHOOK_URL="https://webhook.example.test/monitor" \
  MONITOR_ALERT_REPEAT_SECONDS=3600 \
  BACKUP_DIR="$backup_dir" \
  bash "$ROOT_DIR/ops/production-monitor.sh" runtime >/dev/null 2>&1
set -e
[ "$(wc -l < "$webhook_log" | tr -d ' ')" -eq 1 ] || fail "failure alert should respect cooldown"

PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  MONITOR_ALERT_WEBHOOK_URL="https://webhook.example.test/monitor" \
  BACKUP_DIR="$backup_dir" \
  bash "$ROOT_DIR/ops/production-monitor.sh" runtime >/dev/null
[ "$(wc -l < "$webhook_log" | tr -d ' ')" -eq 2 ] || fail "recovery should send one alert"
tail -n 1 "$webhook_log" | grep -q '"event":"recovery"' || fail "recovery alert should be marked as recovery"

: > "$push_log"
cat > "$log_dir/production-monitor-audit.status" <<EOF
status=FAIL
mode=audit
checked_at=2026-05-10T00:00:00Z
exit_code=1
log_file=$log_dir/production-monitor-audit.log
EOF
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_PUSH_LOG="$push_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  MONITOR_PUSH_RUNTIME_URL="https://push.example.test/runtime" \
  BACKUP_DIR="$backup_dir" \
  bash "$ROOT_DIR/ops/production-monitor.sh" runtime >/dev/null
assert_contains "$push_log" "status=up"
assert_not_contains "$push_log" "test-restic-password"

: > "$docker_log"
run_monitor backup
assert_contains "$log_dir/production-monitor-backup.status" "status=PASS"
grep -q "pg_dump" "$docker_log" || fail "backup mode should create a dump"
[ "$(grep -c "pg_restore -l" "$docker_log")" -ge 2 ] || fail "backup mode should verify the created dump"

: > "$push_log"
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_PUSH_LOG="$push_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  MONITOR_PUSH_BACKUP_URL="https://push-fail.example.test/backup" \
  BACKUP_DIR="$backup_dir" \
  bash "$ROOT_DIR/ops/production-monitor.sh" backup >/dev/null
assert_contains "$log_dir/production-monitor-backup.log" "push failed"

: > "$restic_log"
run_monitor offsite
assert_contains "$log_dir/production-monitor-offsite.status" "status=PASS"
assert_contains "$restic_log" "backup"
assert_contains "$restic_log" "check"

: > "$push_log"
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_PUSH_LOG="$push_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  MONITOR_PUSH_AUDIT_URL="https://push.example.test/audit" \
  BACKUP_DIR="$backup_dir" \
  OPS_HEALTH_NOW_EPOCH=1778457600 \
  bash "$ROOT_DIR/ops/production-monitor.sh" audit >/dev/null
assert_contains "$log_dir/production-monitor-audit.status" "status=PASS"
assert_contains "$log_dir/ops-health/status.json" '"audit":{"status":"PASS"'
assert_contains "$log_dir/ops-health/status.json" '"restic_status":"PASS"'
assert_contains "$push_log" "status=up"

: > "$push_log"
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_PUSH_LOG="$push_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  MONITOR_PUSH_RESTORE_DRILL_URL="https://push.example.test/restore" \
  BACKUP_DIR="$backup_dir" \
  bash "$ROOT_DIR/ops/production-monitor.sh" restore-drill >/dev/null
assert_contains "$log_dir/production-monitor-restore-drill.status" "status=PASS"
assert_contains "$push_log" "status=up"
grep -q "network create" "$docker_log" || fail "restore-drill mode should create an isolated network"

missing_restic_env="$tmp_dir/.env.missing-restic"
grep -v '^RESTIC_PASSWORD=' "$env_file" > "$missing_restic_env"
set +e
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_WEBHOOK_LOG="$webhook_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$missing_restic_env" \
  MONITOR_LOG_DIR="$log_dir" \
  BACKUP_DIR="$backup_dir" \
  bash "$ROOT_DIR/ops/production-monitor.sh" offsite >/dev/null 2>&1
missing_status="$?"
set -e
[ "$missing_status" -ne 0 ] || fail "offsite mode should fail when RESTIC_PASSWORD is missing"
assert_contains "$log_dir/production-monitor-offsite.status" "status=FAIL"

echo "production monitor tests passed"
