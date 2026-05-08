#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/live-e2e-billing-from-db-token.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

env_file="$tmp_dir/.env"
cat > "$env_file" <<'ENV'
POSTGRES_USER=newapi
POSTGRES_DB=newapi
NEW_API_DEV_PORT=3100
ENV

set +e
missing_name_output="$(NEW_API_ENV_FILE="$env_file" "$SCRIPT" 2>&1)"
missing_name_status="$?"
set -e
[ "$missing_name_status" -eq 2 ] || fail "expected missing token name exit 2, got $missing_name_status: $missing_name_output"
printf '%s' "$missing_name_output" | grep -q "token name is required" || fail "missing token name message: $missing_name_output"

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
if [ "$1" = "compose" ]; then
  if [ "${TOKEN_WRAPPER_DB_STATE:-found}" = "missing" ]; then
    exit 0
  fi
  printf 'sk-live-wrapper-secret-abc\n'
  exit 0
fi
echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

fake_e2e="$tmp_dir/e2e.sh"
cat > "$fake_e2e" <<'E2E'
#!/usr/bin/env sh
set -eu
[ "${NEW_API_TEST_TOKEN:-}" = "sk-live-wrapper-secret-abc" ] || exit 31
[ "${NEW_API_BASE_URL:-}" = "http://localhost:43100" ] || exit 32
printf 'fake e2e ran for model=%s\n' "${NEW_API_TEST_MODEL:-unset}"
E2E
chmod +x "$fake_e2e"

set +e
missing_db_output="$(TOKEN_WRAPPER_DB_STATE=missing PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" E2E_BILLING_SCRIPT="$fake_e2e" "$SCRIPT" test_token 2>&1)"
missing_db_status="$?"
set -e
[ "$missing_db_status" -eq 1 ] || fail "expected missing db token exit 1, got $missing_db_status: $missing_db_output"
printf '%s' "$missing_db_output" | grep -q "token not found" || fail "missing db token message: $missing_db_output"
if printf '%s' "$missing_db_output" | grep -q "sk-live-wrapper-secret-abc"; then
  fail "missing db output leaked token: $missing_db_output"
fi

found_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" E2E_BILLING_SCRIPT="$fake_e2e" NEW_API_BASE_URL=http://localhost:43100 NEW_API_TEST_MODEL=glm-5.1 "$SCRIPT" test_token)"
printf '%s' "$found_output" | grep -q "Running live billing E2E with token name: test_token" || fail "found output missing wrapper banner: $found_output"
printf '%s' "$found_output" | grep -q "fake e2e ran for model=glm-5.1" || fail "found output missing fake e2e output: $found_output"
if printf '%s' "$found_output" | grep -q "sk-live-wrapper-secret-abc"; then
  fail "found output leaked token: $found_output"
fi

env_name_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" E2E_BILLING_SCRIPT="$fake_e2e" NEW_API_BASE_URL=http://localhost:43100 NEW_API_TEST_TOKEN_NAME=env_token "$SCRIPT")"
printf '%s' "$env_name_output" | grep -q "token name: env_token" || fail "env token name was not used: $env_name_output"

echo "live-e2e-token-wrapper tests passed"
