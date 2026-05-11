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
backup_dir="$tmp_dir/backups/postgres"
env_file="$tmp_dir/.env.production"
docker_log="$tmp_dir/docker.log"
restic_log="$tmp_dir/restic.log"
mkdir -p "$fake_bin" "$log_dir" "$backup_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$env_file" <<EOF
DEPLOY_ENV=production
DOMAIN=api.example.test
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=1
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
POSTGRES_USER=newapi
POSTGRES_PASSWORD=super-secret-postgres
POSTGRES_DB=newapi
REDIS_PASSWORD=super-secret-redis
SESSION_SECRET=super-secret-session
RESTIC_REPOSITORY=sftp:user@backup.example:/repo
RESTIC_PASSWORD=super-secret-restic
BACKUP_DIR=$backup_dir
MONITOR_LOG_DIR=$log_dir
EOF

cat > "$log_dir/production-monitor-runtime.status" <<EOF
status=PASS
mode=runtime
checked_at=2026-05-11T00:58:00Z
exit_code=0
log_file=$log_dir/production-monitor-runtime.log
EOF

cat > "$log_dir/production-monitor-backup.status" <<EOF
status=PASS
mode=backup
checked_at=2026-05-11T00:30:00Z
exit_code=0
log_file=$log_dir/production-monitor-backup.log
EOF

cat > "$log_dir/production-monitor-offsite.status" <<EOF
status=PASS
mode=offsite
checked_at=2026-05-11T00:40:00Z
exit_code=0
log_file=$log_dir/production-monitor-offsite.log
EOF

cat > "$log_dir/production-monitor-restore-drill.status" <<EOF
status=PASS
mode=restore-drill
checked_at=2026-05-01T00:00:00Z
exit_code=0
log_file=$log_dir/production-monitor-restore-drill.log
EOF

printf 'fake-dump-new' > "$backup_dir/newapi_20260511T003000Z.dump"
printf 'hash  newapi_20260511T003000Z.dump\n' > "$backup_dir/newapi_20260511T003000Z.dump.sha256"
printf 'fake-dump-old' > "$backup_dir/newapi_20260510T003000Z.dump"

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
if [ "$1" = "inspect" ]; then
  case "$*" in
    *relay-new-api*) printf '/relay-new-api restart=unless-stopped state=running health=healthy\n'; exit 0 ;;
    *relay-postgres*) printf '/relay-postgres restart=unless-stopped state=running health=healthy\n'; exit 0 ;;
    *relay-redis*) printf '/relay-redis restart=unless-stopped state=running health=healthy\n'; exit 0 ;;
    *relay-cloudflared*) printf '/relay-cloudflared restart=unless-stopped state=running health=none\n'; exit 0 ;;
    *relay-cpa*) printf '/relay-cpa restart=unless-stopped state=running health=none\n'; exit 0 ;;
  esac
fi
exit 1
DOCKER
chmod +x "$fake_bin/docker"

cat > "$fake_bin/restic" <<'RESTIC'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_RESTIC_LOG"
case "$1" in
  snapshots)
    printf 'ID        Time                 Host        Tags        Paths\n'
    printf 'abc123    2026-05-11 00:40:00  origin                  /backup\n'
    exit 0
    ;;
  check)
    exit 0
    ;;
esac
exit 1
RESTIC
chmod +x "$fake_bin/restic"

cat > "$fake_bin/df" <<'DF'
#!/usr/bin/env sh
if [ "$1" = "-Pi" ]; then
  printf 'Filesystem Inodes IUsed IFree IUse%% Mounted on\n'
  printf '/dev/vda1 1000 700 300 70%% /\n'
else
  printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
  printf '/dev/vda1 1000 700 300 70%% /\n'
fi
DF
chmod +x "$fake_bin/df"

PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  BACKUP_DIR="$backup_dir" \
  OPS_HEALTH_NOW_EPOCH=1778457600 \
  bash "$ROOT_DIR/ops/ops-health-report.sh" collect

json_file="$log_dir/ops-health/status.json"
[ -f "$json_file" ] || fail "status json was not created"
assert_contains "$json_file" '"overall_status":"PASS"'
assert_contains "$json_file" '"dump_count":2'
assert_contains "$json_file" '"latest_dump":"newapi_20260511T003000Z.dump"'
assert_contains "$json_file" '"latest_checksum_exists":true'
assert_contains "$json_file" '"restic_status":"PASS"'
assert_contains "$json_file" '"disk_status":"PASS"'
assert_contains "$json_file" '"topology":"cpa+tunnel"'
assert_not_contains "$json_file" "super-secret"
assert_not_contains "$json_file" "RESTIC_PASSWORD"

PATH="$fake_bin:$PATH" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  BACKUP_DIR="$backup_dir" \
  OPS_HEALTH_NOW_EPOCH=1778457600 \
  bash "$ROOT_DIR/ops/ops-health-report.sh" render

html_file="$log_dir/ops-health/index.html"
[ -f "$html_file" ] || fail "dashboard html was not created"
assert_contains "$html_file" "Ops Health Dashboard"
assert_contains "$html_file" "Backup inventory"
assert_contains "$html_file" "newapi_20260511T003000Z.dump"
assert_not_contains "$html_file" "super-secret"

cat > "$fake_bin/df" <<'DF'
#!/usr/bin/env sh
if [ "$1" = "-Pi" ]; then
  printf 'Filesystem Inodes IUsed IFree IUse%% Mounted on\n'
  printf '/dev/vda1 1000 950 50 95%% /\n'
else
  printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
  printf '/dev/vda1 1000 910 90 91%% /\n'
fi
DF
chmod +x "$fake_bin/df"

set +e
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_RESTIC_LOG="$restic_log" \
  ENV_FILE="$env_file" \
  MONITOR_LOG_DIR="$log_dir" \
  BACKUP_DIR="$backup_dir" \
  OPS_HEALTH_NOW_EPOCH=1778457600 \
  bash "$ROOT_DIR/ops/ops-health-report.sh" collect >/dev/null 2>&1
disk_fail_status="$?"
set -e
[ "$disk_fail_status" -ne 0 ] || fail "collect should fail when disk or inode thresholds are exceeded"
assert_contains "$json_file" '"overall_status":"FAIL"'
assert_contains "$json_file" '"disk_status":"FAIL"'
assert_contains "$json_file" '"inode_status":"FAIL"'

missing_restic_env="$tmp_dir/.env.missing-restic"
grep -v '^RESTIC_PASSWORD=' "$env_file" > "$missing_restic_env"
set +e
PATH="$fake_bin:$PATH" \
  ENV_FILE="$missing_restic_env" \
  MONITOR_LOG_DIR="$log_dir" \
  BACKUP_DIR="$backup_dir" \
  OPS_HEALTH_NOW_EPOCH=1778457600 \
  bash "$ROOT_DIR/ops/ops-health-report.sh" collect >/dev/null 2>&1
missing_status="$?"
set -e
[ "$missing_status" -ne 0 ] || fail "collect should fail when restic password is missing"
assert_contains "$json_file" '"restic_status":"FAIL"'
assert_contains "$json_file" '"restic_message":"RESTIC_PASSWORD is not set"'

echo "ops health report tests passed"
