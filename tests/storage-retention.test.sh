#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$ROOT_DIR/ops/prune-runtime-storage.sh" ] || fail "missing executable: ops/prune-runtime-storage.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

backup_dir="$tmp_dir/backups/postgres"
snapshot_dir="$tmp_dir/snapshots/config"
log_dir="$tmp_dir/logs"
env_file="$tmp_dir/.env.production"
mkdir -p "$backup_dir" "$snapshot_dir" "$log_dir"

cat > "$env_file" <<EOF
BACKUP_DIR=$backup_dir
BACKUP_RETENTION_DAYS=3650
BACKUP_KEEP=2
BACKUP_MAX_TOTAL_MB=1
BACKUP_CRON_LOG_DIR=$log_dir
BACKUP_CRON_LOG_MAX_MB=1
BACKUP_CRON_LOG_KEEP=2
CONFIG_SNAPSHOT_DIR=$snapshot_dir
CONFIG_SNAPSHOT_KEEP=2
CONFIG_SNAPSHOT_MAX_TOTAL_MB=1
EOF

make_file() {
  path="$1"
  size_kb="$2"
  dd if=/dev/zero of="$path" bs=1024 count="$size_kb" >/dev/null 2>&1
}

make_dump() {
  name="$1"
  size_kb="$2"
  path="$backup_dir/$name.dump"
  make_file "$path" "$size_kb"
  echo "$name" > "$path.sha256"
}

make_dump newapi_20260101T000000Z 300
sleep 1
make_dump newapi_20260102T000000Z 300
sleep 1
make_dump newapi_20260103T000000Z 300

ENV_FILE="$env_file" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" backups >/dev/null

[ ! -f "$backup_dir/newapi_20260101T000000Z.dump" ] || fail "oldest dump should be pruned by BACKUP_KEEP"
[ ! -f "$backup_dir/newapi_20260101T000000Z.dump.sha256" ] || fail "oldest dump checksum should be pruned with dump"
[ -f "$backup_dir/newapi_20260102T000000Z.dump" ] || fail "newer dump should be retained"
[ -f "$backup_dir/newapi_20260103T000000Z.dump" ] || fail "newest dump should be retained"

cat >> "$env_file" <<EOF
BACKUP_KEEP=10
BACKUP_MAX_TOTAL_MB=1
EOF

make_dump newapi_20260104T000000Z 800
sleep 1
make_dump newapi_20260105T000000Z 800

ENV_FILE="$env_file" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" backups >/dev/null

dump_count="$(find "$backup_dir" -type f -name '*.dump' | wc -l | tr -d ' ')"
[ "$dump_count" -eq 1 ] || fail "backup total-size pruning should keep only newest dump when over cap, got $dump_count"
[ -f "$backup_dir/newapi_20260105T000000Z.dump" ] || fail "backup total-size pruning should retain newest dump"

make_file "$snapshot_dir/config-redacted-20260101T000000Z.json" 10
sleep 1
make_file "$snapshot_dir/config-redacted-20260102T000000Z.json" 10
sleep 1
make_file "$snapshot_dir/config-private-20260103T000000Z.json.gpg" 10

ENV_FILE="$env_file" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" snapshots >/dev/null
[ ! -f "$snapshot_dir/config-redacted-20260101T000000Z.json" ] || fail "oldest snapshot should be pruned by CONFIG_SNAPSHOT_KEEP"
[ -f "$snapshot_dir/config-redacted-20260102T000000Z.json" ] || fail "newer snapshot should be retained"
[ -f "$snapshot_dir/config-private-20260103T000000Z.json.gpg" ] || fail "newest private snapshot should be retained"

make_file "$log_dir/backup-cron.log" 1200
ENV_FILE="$env_file" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" logs >/dev/null

[ -f "$log_dir/backup-cron.log" ] || fail "active backup-cron.log should exist after rotation"
rotated_count="$(find "$log_dir" -type f -name 'backup-cron.*.log' | wc -l | tr -d ' ')"
[ "$rotated_count" -eq 1 ] || fail "backup cron log should rotate once, got $rotated_count"
[ ! -s "$log_dir/backup-cron.log" ] || fail "active backup-cron.log should be truncated after rotation"

make_file "$log_dir/backup-cron.log" 1200
ENV_FILE="$env_file" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" logs >/dev/null
sleep 1
make_file "$log_dir/backup-cron.log" 1200
ENV_FILE="$env_file" bash "$ROOT_DIR/ops/prune-runtime-storage.sh" logs >/dev/null

rotated_count="$(find "$log_dir" -type f -name 'backup-cron.*.log' | wc -l | tr -d ' ')"
[ "$rotated_count" -eq 2 ] || fail "backup cron rotated logs should respect BACKUP_CRON_LOG_KEEP=2, got $rotated_count"

echo "storage retention tests passed"
