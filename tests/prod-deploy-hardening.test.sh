#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
log="${FAKE_DOCKER_LOG:?}"
printf '%s\n' "$*" >> "$log"

if [ "$1" = "compose" ]; then
  shift
  case "$*" in
    *" config")
      exit 0
      ;;
    *" pg_dump "*)
      printf 'fake-postgres-dump'
      exit 0
      ;;
    *" pg_restore -l")
      cat >/dev/null
      exit 0
      ;;
    *" pg_restore --clean --if-exists"*)
      cat >/dev/null
      exit 0
      ;;
  esac
fi

echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

write_env() {
  path="$1"
  postgres_password="$2"
  cat > "$path" <<EOF
DEPLOY_ENV=production
DOMAIN=api.example.com
ACME_EMAIL=ops@example.com
SESSION_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
POSTGRES_USER=newapi
POSTGRES_PASSWORD=$postgres_password
POSTGRES_DB=newapi
REDIS_PASSWORD=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
EOF
}

bad_env="$tmp_dir/bad.env"
good_env="$tmp_dir/good.env"
docker_log="$tmp_dir/docker.log"
export FAKE_DOCKER_LOG="$docker_log"

write_env "$bad_env" "abc/def+ghi="
set +e
bad_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$bad_env" "$ROOT_DIR/ops/preflight.sh" 2>&1)"
bad_status="$?"
set -e
[ "$bad_status" -ne 0 ] || fail "preflight should reject URL-unsafe postgres password"
printf '%s' "$bad_output" | grep -q "POSTGRES_PASSWORD contains characters" || fail "bad password output was not clear: $bad_output"

write_env "$good_env" "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
: > "$docker_log"
PATH="$fake_bin:$PATH" ENV_FILE="$good_env" "$ROOT_DIR/ops/preflight.sh" >/dev/null
grep -q -- "-f docker-compose.prod.yml config" "$docker_log" || fail "production preflight did not render docker-compose.prod.yml"

: > "$docker_log"
backup_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$good_env" BACKUP_DIR="$tmp_dir/backups" "$ROOT_DIR/ops/backup-postgres.sh")"
[ -f "$ROOT_DIR/$backup_output" ] || [ -f "$backup_output" ] || fail "backup script did not create output: $backup_output"
grep -q -- "--env-file $good_env" "$docker_log" || fail "backup script did not pass --env-file"

backup_path="$ROOT_DIR/$backup_output"
[ -f "$backup_path" ] || backup_path="$backup_output"

: > "$docker_log"
PATH="$fake_bin:$PATH" ENV_FILE="$good_env" "$ROOT_DIR/ops/verify-postgres-backup.sh" "$backup_path" >/dev/null
grep -q -- "--env-file $good_env" "$docker_log" || fail "verify script did not pass --env-file"

: > "$docker_log"
PATH="$fake_bin:$PATH" ENV_FILE="$good_env" "$ROOT_DIR/ops/restore-postgres.sh" "$backup_path" >/dev/null
grep -q -- "--env-file $good_env" "$docker_log" || fail "restore script did not pass --env-file"

grep -q -- "--log-dir /tmp/new-api-logs" "$ROOT_DIR/ops/drill-restore-stack.sh" || fail "restore stack drill should use a temp log dir whose parent exists in the upstream image"
if grep -q -- "--log-dir /app/logs" "$ROOT_DIR/ops/drill-restore-stack.sh"; then
  fail "restore stack drill must not use /app/logs without mounting that parent path"
fi

if printf '%s\n' "$bad_output" | grep -Eiq 'SESSION_SECRET|REDIS_PASSWORD=.*|POSTGRES_PASSWORD=.*'; then
  fail "preflight printed secret values"
fi

echo "prod deploy hardening tests passed"
