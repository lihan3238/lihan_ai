#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/channel-health-advisor.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

profile="$tmp_dir/health.json"
env_file="$tmp_dir/.env"
fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

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
printf '%s' "$missing_output" | grep -q "missing profile" || fail "missing profile message"

printf '{bad json' > "$profile"
set +e
bad_json_output="$("$SCRIPT" "$profile" 2>&1)"
bad_json_status="$?"
set -e
[ "$bad_json_status" -eq 1 ] || fail "expected bad JSON exit 1, got $bad_json_status: $bad_json_output"
printf '%s' "$bad_json_output" | grep -q "invalid JSON" || fail "bad JSON message"

cat > "$profile" <<'EOF'
{
  "name": "broken",
  "group": "default"
}
EOF
set +e
missing_field_output="$("$SCRIPT" "$profile" 2>&1)"
missing_field_status="$?"
set -e
[ "$missing_field_status" -eq 1 ] || fail "expected missing field exit 1, got $missing_field_status: $missing_field_output"
printf '%s' "$missing_field_output" | grep -q "profile.model is required" || fail "missing field message"

cat > "$profile" <<'EOF'
{
  "name": "glm-default-health",
  "group": "default",
  "model": "glm-5.1",
  "mode": "development",
  "window_hours": 24,
  "min_enabled_channels": 1,
  "min_sample_count": 20,
  "thresholds": {
    "max_error_rate": 0.2,
    "min_error_count_for_rate": 10,
    "max_recent_errors": 20,
    "max_p95_use_time_seconds": 20,
    "max_response_time_ms": 10000,
    "max_test_age_hours": 12
  }
}
EOF

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
case "${FAKE_HEALTH_SCENARIO:-pass}" in
  no_channel)
    cat <<'JSON'
{"matched_channel_count":0,"enabled_channel_count":0,"disabled_channel_count":0,"window_request_count":0,"window_error_count":0,"window_error_rate":0,"channels":[]}
JSON
    ;;
  high_error)
    cat <<'JSON'
{"matched_channel_count":1,"enabled_channel_count":1,"disabled_channel_count":0,"window_request_count":50,"window_error_count":25,"window_error_rate":0.5,"channels":[{"id":1,"name":"glm-default-a","status":1,"ability_enabled":true,"priority":0,"weight":10,"response_time":300,"test_age_hours":1,"window_request_count":50,"window_error_count":25,"window_error_rate":0.5,"p95_use_time":3,"used_quota":1000,"recommendations":["investigate upstream errors"]}]}
JSON
    ;;
  development_noise)
    cat <<'JSON'
{"matched_channel_count":1,"enabled_channel_count":1,"disabled_channel_count":0,"window_request_count":500,"window_error_count":45,"window_error_rate":0.09,"channels":[{"id":1,"name":"glm-default-a","status":1,"ability_enabled":true,"priority":0,"weight":10,"response_time":3973,"test_age_hours":4,"window_request_count":500,"window_error_count":45,"window_error_rate":0.09,"p95_use_time":24,"used_quota":1000,"recommendations":[]}]}
JSON
    ;;
  low_sample)
    cat <<'JSON'
{"matched_channel_count":1,"enabled_channel_count":1,"disabled_channel_count":0,"window_request_count":1,"window_error_count":0,"window_error_rate":0,"channels":[{"id":1,"name":"glm-default-a","status":1,"ability_enabled":true,"priority":0,"weight":10,"response_time":300,"test_age_hours":1,"window_request_count":1,"window_error_count":0,"window_error_rate":0,"p95_use_time":2,"used_quota":1000,"recommendations":[]}]}
JSON
    ;;
  pass)
    cat <<'JSON'
{"matched_channel_count":2,"enabled_channel_count":2,"disabled_channel_count":0,"window_request_count":20,"window_error_count":1,"window_error_rate":0.05,"channels":[{"id":1,"name":"glm-default-a","status":1,"ability_enabled":true,"priority":0,"weight":10,"response_time":300,"test_age_hours":1,"window_request_count":10,"window_error_count":0,"window_error_rate":0,"p95_use_time":2,"used_quota":1000,"recommendations":[]},{"id":2,"name":"glm-default-b","status":1,"ability_enabled":true,"priority":1,"weight":5,"response_time":600,"test_age_hours":2,"window_request_count":10,"window_error_count":1,"window_error_rate":0.1,"p95_use_time":4,"used_quota":800,"recommendations":[]}]}
JSON
    ;;
esac
DOCKER
chmod +x "$fake_bin/docker"

set +e
no_channel_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" FAKE_HEALTH_SCENARIO=no_channel "$SCRIPT" "$profile" 2>&1)"
no_channel_status="$?"
set -e
[ "$no_channel_status" -eq 1 ] || fail "expected no channel exit 1, got $no_channel_status: $no_channel_output"
printf '%s' "$no_channel_output" | grep -q "FAIL enabled channels" || fail "missing enabled channel failure"

set +e
high_error_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" FAKE_HEALTH_SCENARIO=high_error "$SCRIPT" "$profile" 2>&1)"
high_error_status="$?"
set -e
[ "$high_error_status" -eq 1 ] || fail "expected high error exit 1, got $high_error_status: $high_error_output"
printf '%s' "$high_error_output" | grep -q "FAIL error rate" || fail "missing error rate failure"

development_noise_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" FAKE_HEALTH_SCENARIO=development_noise "$SCRIPT" "$profile")"
printf '%s' "$development_noise_output" | grep -q "WARN recent errors" || fail "missing development recent errors warning"
printf '%s' "$development_noise_output" | grep -q "WARN latency" || fail "missing development latency warning"
printf '%s' "$development_noise_output" | grep -q "Summary: pass=.*fail=0" || fail "development noise should not fail: $development_noise_output"

production_profile="$tmp_dir/health-production.json"
sed 's/"mode": "development"/"mode": "production"/' "$profile" > "$production_profile"
set +e
production_noise_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" FAKE_HEALTH_SCENARIO=development_noise "$SCRIPT" "$production_profile" 2>&1)"
production_noise_status="$?"
set -e
[ "$production_noise_status" -eq 1 ] || fail "expected production noise exit 1, got $production_noise_status: $production_noise_output"
printf '%s' "$production_noise_output" | grep -q "FAIL recent errors" || fail "missing production recent errors failure"

low_sample_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" FAKE_HEALTH_SCENARIO=low_sample "$SCRIPT" "$profile" 2>&1 || true)"
printf '%s' "$low_sample_output" | grep -q "WARN sample size" || fail "missing low sample warning"

pass_output="$(PATH="$fake_bin:$PATH" NEW_API_ENV_FILE="$env_file" FAKE_HEALTH_SCENARIO=pass "$SCRIPT" "$profile")"
printf '%s' "$pass_output" | grep -q "PASS enabled channels" || fail "missing pass enabled channels"
printf '%s' "$pass_output" | grep -q "PASS error rate" || fail "missing pass error rate"
if printf '%s' "$pass_output" | grep -Eiq 'sk-[A-Za-z0-9]{20,}|password|secret|token|base_url'; then
  fail "health output contains secret-looking content"
fi

echo "channel-health-advisor tests passed"
