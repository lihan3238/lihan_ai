#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/local-new-api-e2e.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$ROOT_DIR/$1" ] || fail "missing file: $1"
}

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q -- "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_file "ops/local-new-api-e2e.sh"
assert_contains "ops/local-new-api-e2e.sh" "LOCAL_E2E_ADMIN_USERNAME"
assert_contains "ops/local-new-api-e2e.sh" "codex_e2e_admin"
assert_contains "ops/local-new-api-e2e.sh" "CodexLocal123!"
assert_contains "ops/local-new-api-e2e.sh" "NEW_API_BASE_URL"
assert_contains "ops/local-new-api-e2e.sh" "localhost"
assert_contains "ops/local-new-api-e2e.sh" "127.0.0.1"
assert_contains "ops/local-new-api-e2e.sh" "create extension if not exists pgcrypto"
assert_contains "ops/local-new-api-e2e.sh" "run_npm"
assert_contains "ops/local-new-api-e2e.sh" "cmd.exe"
assert_contains "ops/local-new-api-e2e.sh" "WSLENV"
assert_contains "ops/local-new-api-e2e.sh" "NEW_API_REQUIRE_ADMIN_E2E"
assert_contains "ops/local-new-api-e2e.sh" "npm run e2e:web:new-api"
assert_contains "ops/local-new-api-e2e.sh" "e2e:web:new-api-admin"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/docker" <<'FAKE_DOCKER'
#!/usr/bin/env sh
echo "docker must not run for unsafe target" >&2
exit 99
FAKE_DOCKER
chmod +x "$fake_bin/docker"

cat > "$fake_bin/npm" <<'FAKE_NPM'
#!/usr/bin/env sh
echo "npm must not run for unsafe target" >&2
exit 99
FAKE_NPM
chmod +x "$fake_bin/npm"

set +e
unsafe_output="$(PATH="$fake_bin:$PATH" NEW_API_BASE_URL=https://api.example.test sh "$SCRIPT" 2>&1)"
unsafe_status="$?"
set -e

[ "$unsafe_status" -eq 2 ] || fail "unsafe target should exit 2, got $unsafe_status: $unsafe_output"
printf '%s' "$unsafe_output" | grep -q "localhost" || fail "unsafe target output should explain localhost guard: $unsafe_output"

unsafe_env_file="$tmp_dir/.env.production"
cat > "$unsafe_env_file" <<'ENV'
NEW_API_BASE_URL=http://localhost:3100
POSTGRES_USER=newapi
POSTGRES_DB=newapi
DEPLOY_ENV=production
ENV

set +e
unsafe_env_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$unsafe_env_file" sh "$SCRIPT" 2>&1)"
unsafe_env_status="$?"
set -e

[ "$unsafe_env_status" -eq 2 ] || fail "unsafe env file should exit 2, got $unsafe_env_status: $unsafe_env_output"
printf '%s' "$unsafe_env_output" | grep -q ".env.local-restore" || fail "unsafe env output should require local restore env: $unsafe_env_output"

echo "local New API E2E tests passed"
