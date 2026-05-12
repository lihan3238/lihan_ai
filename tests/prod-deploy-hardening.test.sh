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
DEPLOY_COMPOSE_PROJECT=lihan_ai
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

local_image_collision_env="$tmp_dir/local-image-collision.env"
cat "$good_env" > "$local_image_collision_env"
cat >> "$local_image_collision_env" <<'EOF'
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
NEW_API_IMAGE=calciumion/new-api:latest
LOCAL_NEW_API_IMAGE=calciumion/new-api:latest
EOF

set +e
local_image_collision_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$local_image_collision_env" "$ROOT_DIR/ops/preflight.sh" 2>&1)"
local_image_collision_status="$?"
set -e
[ "$local_image_collision_status" -ne 0 ] || fail "preflight should reject LOCAL_NEW_API_IMAGE matching NEW_API_IMAGE"
printf '%s' "$local_image_collision_output" | grep -q "LOCAL_NEW_API_IMAGE must differ from NEW_API_IMAGE" || fail "local image collision output was not clear: $local_image_collision_output"

local_image_pull_env="$tmp_dir/local-image-pull.env"
cat "$good_env" > "$local_image_pull_env"
cat >> "$local_image_pull_env" <<'EOF'
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull
NEW_API_IMAGE=calciumion/new-api:latest
LOCAL_NEW_API_IMAGE=ghcr.io/lihan3238/new-api:f80e8ea6-dropdown
EOF

: > "$docker_log"
PATH="$fake_bin:$PATH" ENV_FILE="$local_image_pull_env" "$ROOT_DIR/ops/preflight.sh" >/dev/null
if grep -q -- "docker-compose.local-build.yml" "$docker_log"; then
  fail "preflight pull mode should not render docker-compose.local-build.yml"
fi

cpa_config="$tmp_dir/cpa-config.yaml"
cat > "$cpa_config" <<'EOF'
logging-to-file: true
logs-max-total-size-mb: 0
error-logs-max-files: 10
EOF

cpa_env="$tmp_dir/cpa.env"
cat "$good_env" > "$cpa_env"
cat >> "$cpa_env" <<EOF
DEPLOY_INCLUDE_CPA=1
CPA_CONFIG_PATH=$cpa_config
EOF

set +e
cpa_bad_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$cpa_env" "$ROOT_DIR/ops/preflight.sh" 2>&1)"
cpa_bad_status="$?"
set -e
[ "$cpa_bad_status" -ne 0 ] || fail "preflight should reject CPA file logging without logs-max-total-size-mb"
printf '%s' "$cpa_bad_output" | grep -q "CPA logging-to-file requires logs-max-total-size-mb" || fail "CPA logging cap output was not clear: $cpa_bad_output"

cat > "$cpa_config" <<'EOF'
logging-to-file: true
logs-max-total-size-mb: 200
error-logs-max-files: 10
EOF

: > "$docker_log"
PATH="$fake_bin:$PATH" ENV_FILE="$cpa_env" "$ROOT_DIR/ops/preflight.sh" >/dev/null
grep -q -- "docker-compose.cpa.yml" "$docker_log" || fail "CPA preflight should render docker-compose.cpa.yml"

: > "$docker_log"
backup_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$good_env" BACKUP_DIR="$tmp_dir/backups" "$ROOT_DIR/ops/backup-postgres.sh")"
[ -f "$ROOT_DIR/$backup_output" ] || [ -f "$backup_output" ] || fail "backup script did not create output: $backup_output"
grep -q -- "--env-file $good_env" "$docker_log" || fail "backup script did not pass --env-file"
grep -q -- "compose -p lihan_ai" "$docker_log" || fail "backup script did not use DEPLOY_COMPOSE_PROJECT"

backup_path="$ROOT_DIR/$backup_output"
[ -f "$backup_path" ] || backup_path="$backup_output"

: > "$docker_log"
PATH="$fake_bin:$PATH" ENV_FILE="$good_env" "$ROOT_DIR/ops/verify-postgres-backup.sh" "$backup_path" >/dev/null
grep -q -- "--env-file $good_env" "$docker_log" || fail "verify script did not pass --env-file"
grep -q -- "compose -p lihan_ai" "$docker_log" || fail "verify script did not use DEPLOY_COMPOSE_PROJECT"

: > "$docker_log"
PATH="$fake_bin:$PATH" ENV_FILE="$good_env" "$ROOT_DIR/ops/restore-postgres.sh" "$backup_path" >/dev/null
grep -q -- "--env-file $good_env" "$docker_log" || fail "restore script did not pass --env-file"
grep -q -- "compose -p lihan_ai" "$docker_log" || fail "restore script did not use DEPLOY_COMPOSE_PROJECT"

grep -q -- "--log-dir /tmp/new-api-logs" "$ROOT_DIR/ops/drill-restore-stack.sh" || fail "restore stack drill should use a temp log dir whose parent exists in the upstream image"
grep -q -- "command: --log-dir=" "$ROOT_DIR/docker-compose.prod.yml" || fail "production override should disable New API file logs"
if grep -q -- "--log-dir /app/logs" "$ROOT_DIR/ops/drill-restore-stack.sh"; then
  fail "restore stack drill must not use /app/logs without mounting that parent path"
fi
grep -q -- "select 1" "$ROOT_DIR/ops/drill-restore-stack.sh" || fail "restore stack drill should verify PostgreSQL accepts a real query before restore"
grep -q -- "pg_restore_status" "$ROOT_DIR/ops/drill-restore-stack.sh" || fail "restore stack drill should retry pg_restore transient startup/shutdown races"

if printf '%s\n' "$bad_output" | grep -Eiq 'SESSION_SECRET|REDIS_PASSWORD=.*|POSTGRES_PASSWORD=.*'; then
  fail "preflight printed secret values"
fi

echo "prod deploy hardening tests passed"
