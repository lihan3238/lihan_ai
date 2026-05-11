#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$ROOT_DIR/$1" ] || fail "missing file: $1"
}

assert_executable() {
  [ -x "$ROOT_DIR/$1" ] || fail "missing executable: $1"
}

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q -- "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -q -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

assert_file "docker-compose.ops-dashboard.yml"
assert_executable "ops/ops-dashboard.sh"
assert_executable "ops/ops-health-report.sh"
assert_contains "docker-compose.ops-dashboard.yml" "127.0.0.1"
assert_contains "docker-compose.ops-dashboard.yml" '${OPS_DASHBOARD_PORT:-3021}:80'
assert_contains "docker-compose.ops-dashboard.yml" "./logs/ops-health:/usr/share/nginx/html:ro"
assert_not_contains "docker-compose.ops-dashboard.yml" ".env.production"
assert_contains "ops/ops-dashboard.sh" "ops/ops-health-report.sh render"
assert_contains "ops/ops-dashboard.sh" "docker-compose.ops-dashboard.yml"
assert_not_contains "ops/ops-dashboard.sh" "--remove-orphans"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
docker_log="$tmp_dir/docker.log"
mkdir -p "$fake_bin" "$tmp_dir/logs/ops-health"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/.env.production" <<'ENV'
DEPLOY_COMPOSE_PROJECT=lihan_ai
OPS_DASHBOARD_PORT=3021
ENV

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
exit 0
DOCKER
chmod +x "$fake_bin/docker"

PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" ENV_FILE="$tmp_dir/.env.production" MONITOR_LOG_DIR="$tmp_dir/logs" \
  "$ROOT_DIR/ops/ops-dashboard.sh" open >/dev/null
grep -q -- "docker-compose.ops-dashboard.yml" "$docker_log" || fail "dashboard open should use dashboard overlay"
grep -q -- "up -d ops-dashboard" "$docker_log" || fail "dashboard open should start only ops-dashboard"
if grep -q -- "--remove-orphans" "$docker_log"; then
  fail "ops dashboard helper must not use --remove-orphans"
fi

echo "ops dashboard tests passed"
