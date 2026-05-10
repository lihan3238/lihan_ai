#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/validate-ops-profile.sh"
PROFILE="$ROOT_DIR/config/ops-profiles/glm-standard.example.json"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"
[ -f "$PROFILE" ] || fail "missing profile $PROFILE"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

env_file="$tmp_dir/.env"
cat > "$env_file" <<'EOF'
POSTGRES_USER=newapi
POSTGRES_DB=newapi
POSTGRES_PASSWORD=redacted
NEW_API_DEV_PORT=3100
EOF

set +e
missing_output="$("$SCRIPT" "$tmp_dir/missing.json" 2>&1)"
missing_status="$?"
set -e
[ "$missing_status" -eq 1 ] || fail "expected missing profile exit 1, got $missing_status: $missing_output"
printf '%s' "$missing_output" | grep -q "missing profile" || fail "missing profile message: $missing_output"

bad_json="$tmp_dir/bad.json"
printf '{bad json' > "$bad_json"
set +e
bad_json_output="$("$SCRIPT" "$bad_json" 2>&1)"
bad_json_status="$?"
set -e
[ "$bad_json_status" -eq 1 ] || fail "expected bad json exit 1, got $bad_json_status: $bad_json_output"
printf '%s' "$bad_json_output" | grep -q "invalid JSON" || fail "bad json message: $bad_json_output"

missing_required="$tmp_dir/missing-required.json"
cat > "$missing_required" <<'JSON'
{
  "name": "bad-profile",
  "group": "standard",
  "min_enabled_channels": 1
}
JSON
set +e
required_output="$("$SCRIPT" "$missing_required" 2>&1)"
required_status="$?"
set -e
[ "$required_status" -eq 1 ] || fail "expected required field exit 1, got $required_status: $required_output"
printf '%s' "$required_output" | grep -q "profile.model is required" || fail "required field message: $required_output"

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
if [ "${OPS_PROFILE_FAKE_DB_STATE:-pass}" = "pass" ]; then
  cat <<'JSON'
{"enabled_channel_count":1,"enabled_channel_names":["glm-official"],"user_count":2,"active_token_count":1,"subscription_plan_count":0,"payment_option_count":0}
JSON
else
  cat <<'JSON'
{"enabled_channel_count":0,"enabled_channel_names":[],"user_count":1,"active_token_count":0,"subscription_plan_count":0,"payment_option_count":0}
JSON
fi
DOCKER
chmod +x "$fake_bin/docker"
cat > "$fake_bin/curl" <<'CURL'
#!/usr/bin/env sh
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    out="$2"
    shift 2
    continue
  fi
  shift
done
cat > "$out" <<'JSON'
{"object":"list","data":[{"id":"glm-5.1","object":"model"}]}
JSON
printf '200'
CURL
chmod +x "$fake_bin/curl"

pass_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT" "$PROFILE")"
printf '%s' "$pass_output" | grep -q "PASS enabled channels" || fail "pass output missing enabled channel pass: $pass_output"
printf '%s' "$pass_output" | grep -q "WARN subscriptions" || fail "pass output missing subscription warning: $pass_output"
printf '%s' "$pass_output" | grep -q "Summary: pass=" || fail "pass output missing summary: $pass_output"
if printf '%s' "$pass_output" | grep -Eiq 'sk-[A-Za-z0-9]|password|SESSION_SECRET|POSTGRES_PASSWORD|REDIS_PASSWORD'; then
  fail "validator output contains secret-looking content: $pass_output"
fi

set +e
fail_output="$(OPS_PROFILE_FAKE_DB_STATE=fail PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT" "$PROFILE" 2>&1)"
fail_status="$?"
set -e
[ "$fail_status" -eq 1 ] || fail "expected profile mismatch exit 1, got $fail_status: $fail_output"
printf '%s' "$fail_output" | grep -q "FAIL enabled channels" || fail "fail output missing enabled channel failure: $fail_output"

models_output="$(NEW_API_TEST_TOKEN='sk-test-redacted' PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" "$SCRIPT" "$PROFILE")"
printf '%s' "$models_output" | grep -q "PASS models api" || fail "models output missing API pass: $models_output"
if printf '%s' "$models_output" | grep -q "sk-test-redacted"; then
  fail "validator output printed test token: $models_output"
fi

echo "ops-profile tests passed"
