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

assert_executable() {
  [ -x "$ROOT_DIR/$1" ] || fail "missing executable: $1"
}

assert_executable "ops/backup-cron.sh"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
log_dir="$tmp_dir/logs"
backup_dir="$tmp_dir/backups/postgres"
env_file="$tmp_dir/.env.production"
docker_log="$tmp_dir/docker.log"
mkdir -p "$fake_bin" "$log_dir" "$backup_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$env_file" <<EOF
DEPLOY_COMPOSE_PROJECT=lihan_ai
POSTGRES_USER=newapi
POSTGRES_PASSWORD=redacted
POSTGRES_DB=newapi
REDIS_PASSWORD=redacted
SESSION_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
BACKUP_DIR=$backup_dir
BACKUP_CRON_LOG_DIR=$log_dir
EOF

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"

if [ "$1" = "compose" ]; then
  case "$*" in
    *" pg_dump "*)
      printf 'fake-postgres-dump'
      exit 0
      ;;
    *" pg_restore -l"*)
      cat >/dev/null
      exit 0
      ;;
  esac
fi

echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

output="$(PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" ENV_FILE="$env_file" bash "$ROOT_DIR/ops/backup-cron.sh")"

printf '%s' "$output" | grep -q "backup cron passed" || fail "backup-cron should report success: $output"
assert_contains "$docker_log" "pg_dump"
assert_contains "$docker_log" "pg_restore -l"

log_file="$log_dir/backup-cron.log"
[ -f "$log_file" ] || fail "backup cron log was not created"
assert_contains "$log_file" "backup created:"
assert_contains "$log_file" "backup is readable:"

echo "backup cron tests passed"
