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
  grep -q "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_file "docker-compose.local-build.yml"
assert_executable "ops/build-local-new-api.sh"
assert_executable "ops/start-local-new-api.sh"
assert_executable "ops/export-config-snapshot.sh"
assert_executable "ops/drill-restore-postgres.sh"
assert_executable "ops/production-gate.sh"
assert_executable "ops/validate-ops-profile.sh"
assert_executable "ops/channel-health-advisor.sh"
assert_executable "ops/live-e2e-billing-from-db-token.sh"
assert_executable "ops/check-local-ports.sh"
assert_executable "tests/ops-profile.test.sh"
assert_executable "tests/channel-health-advisor.test.sh"
assert_executable "tests/live-e2e-token-wrapper.test.sh"
assert_executable "tests/check-local-ports.test.sh"
assert_executable "tests/browser-e2e-scaffold.test.sh"
assert_file "docs/development-workflow.md"
assert_file "docs/wrapper-infra-runbook.md"
assert_file "docs/kuma-status-runbook.md"
assert_file "config/ops-profiles/glm-standard.example.json"
assert_file "config/ops-profiles/glm-standard-health.example.json"
assert_file "Caddyfile.status.example"

assert_contains ".gitignore" "^snapshots/$"
assert_contains ".env.example" "LOCAL_NEW_API_IMAGE="
assert_contains ".env.example" "CONFIG_SNAPSHOT_DIR="
assert_contains ".env.example" "CONFIG_SNAPSHOT_GPG_RECIPIENT="
assert_contains ".env.example" "NEW_API_DEV_PORT=3100"
assert_contains ".env.example" "STATUS_DOMAIN="
assert_contains ".env.example" "KUMA_PORT=3011"
assert_contains "docker-compose.local-build.yml" "vendor/new-api"
assert_contains "docker-compose.local-build.yml" "LOCAL_NEW_API_IMAGE"
assert_contains "docs/development-workflow.md" "Research Gate"
assert_contains "ops/production-gate.sh" "tests/ai-dev-check.test.sh"
assert_contains "ops/production-gate.sh" "AI_DEV_FEATURE_DIR"
assert_contains "ops/production-gate.sh" "OPS_PROFILE_FILE"
assert_contains "ops/production-gate.sh" "OPS_HEALTH_PROFILE_FILE"
assert_contains "docs/kuma-status-runbook.md" "API Gateway"
assert_contains "docs/kuma-status-runbook.md" "GLM Standard"
assert_contains "Caddyfile.status.example" "uptime-kuma:3001"
assert_contains "ops/live-e2e-billing-from-db-token.sh" "NEW_API_TEST_TOKEN_NAME"
assert_contains "ops/check-local-ports.sh" "KUMA_PORT"

set +e
private_output="$(env -u CONFIG_SNAPSHOT_GPG_RECIPIENT "$ROOT_DIR/ops/export-config-snapshot.sh" --private 2>&1)"
private_status="$?"
set -e
[ "$private_status" -eq 2 ] || fail "expected private snapshot exit 2 without recipient, got $private_status: $private_output"
printf '%s' "$private_output" | grep -q "CONFIG_SNAPSHOT_GPG_RECIPIENT is not set" || fail "missing private snapshot recipient message"

fake_bin="$(mktemp -d)"
tmp_out="$(mktemp -d)"
trap 'rm -rf "$fake_bin" "$tmp_out"' EXIT

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
if [ "$1" = "compose" ] && [ "$2" = "--env-file" ]; then
  cat <<'JSON'
{
  "snapshot_kind": "redacted",
  "generated_at": "2026-05-08T00:00:00Z",
  "database": "newapi",
  "data": {
    "channels": [
      {
        "id": 1,
        "name": "official",
        "type": 14,
        "status": 1,
        "models": "glm-5.1",
        "base_url": "https://example.invalid",
        "key_fingerprint": "sha256:abcd1234",
        "key_length": 96,
        "used_quota": 123
      }
    ],
    "tokens": [
      {
        "id": 1,
        "user_id": 1,
        "status": 1,
        "name": "test",
        "key_fingerprint": "sha256:ef567890",
        "key_length": 48,
        "remain_quota": 10,
        "used_quota": 20
      }
    ]
  }
}
JSON
  exit 0
fi
echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

snapshot_output="$(PATH="$fake_bin:$PATH" CONFIG_SNAPSHOT_DIR="$tmp_out" "$ROOT_DIR/ops/export-config-snapshot.sh")"
[ -f "$snapshot_output" ] || fail "snapshot output not found: $snapshot_output"
grep -q '"snapshot_kind": "redacted"' "$snapshot_output" || fail "snapshot missing redacted kind"
grep -q '"key_fingerprint"' "$snapshot_output" || fail "snapshot missing key fingerprint"
if grep -Eiq 'sk-[A-Za-z0-9]|password|SESSION_SECRET|POSTGRES_PASSWORD|REDIS_PASSWORD' "$snapshot_output"; then
  fail "redacted snapshot contains forbidden secret-looking content"
fi

set +e
gate_output="$(env -u NEW_API_TEST_TOKEN "$ROOT_DIR/ops/production-gate.sh" 2>&1)"
gate_status="$?"
set -e
[ "$gate_status" -eq 2 ] || fail "expected production gate exit 2 without token, got $gate_status: $gate_output"
printf '%s' "$gate_output" | grep -q "NEW_API_TEST_TOKEN is not set" || fail "missing production gate token message"

echo "wrapper-infra tests passed"
