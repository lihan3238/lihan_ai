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

assert_file "docker-compose.kuma.ui.yml"
assert_executable "ops/kuma-ui.sh"
assert_contains "docker-compose.kuma.ui.yml" "127.0.0.1"
assert_contains "docker-compose.kuma.ui.yml" '${KUMA_PORT:-3011}:3001'
assert_contains "ops/kuma-ui.sh" "docker-compose.kuma.ui.yml"
assert_contains "ops/kuma-ui.sh" "--force-recreate --no-deps uptime-kuma"
assert_not_contains "ops/kuma-ui.sh" "--remove-orphans"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
docker_log="$tmp_dir/docker.log"
mkdir -p "$fake_bin"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/.env.production" <<'ENV'
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=1
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
KUMA_PORT=3011
ENV

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
exit 0
DOCKER
chmod +x "$fake_bin/docker"

PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" ENV_FILE="$tmp_dir/.env.production" \
  "$ROOT_DIR/ops/kuma-ui.sh" open >/dev/null
grep -q -- "docker-compose.kuma.ui.yml" "$docker_log" || fail "open should use Kuma UI overlay"
grep -q -- "--force-recreate --no-deps uptime-kuma" "$docker_log" || fail "open should only recreate uptime-kuma"
if grep -q -- "--remove-orphans" "$docker_log"; then
  fail "kuma ui helper must not use --remove-orphans"
fi

echo "kuma ui script tests passed"
