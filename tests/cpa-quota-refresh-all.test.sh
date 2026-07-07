#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/cpa-quota-refresh-all.sh"

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

assert_not_contains_file() {
  file="$1"
  pattern="$2"
  if grep -q -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

assert_executable "ops/cpa-quota-refresh-all.sh"
assert_contains "ops/cpa-quota-refresh-all.sh" "remote-management"
assert_contains "ops/cpa-quota-refresh-all.sh" "secret-key"
assert_contains "ops/cpa-quota-refresh-all.sh" "auth-files"
assert_contains "ops/cpa-quota-refresh-all.sh" "api-call"
assert_contains "ops/cpa-quota-refresh-all.sh" "ops/cpa-quota-snapshot.sh"
assert_not_contains_file "ops/cpa-quota-refresh-all.sh" "ops/cpa-ui.sh"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
public_dir="$tmp_dir/public"
config_file="$tmp_dir/config.yaml"
env_file="$tmp_dir/.env.production"
curl_log="$tmp_dir/curl.log"
api_payloads="$tmp_dir/api-payloads.jsonl"
mkdir -p "$fake_bin" "$public_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$config_file" <<'YAML'
remote-management:
  allow-remote: false
  secret-key: "config-secret-should-not-leak"
YAML

cat > "$env_file" <<EOF
CPA_CONFIG_PATH=$config_file
CPA_PUBLIC_PATH=$public_dir
EOF

cat > "$fake_bin/curl" <<'CURL'
#!/usr/bin/env sh
url=""
data=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--data|--data-raw|--data-binary)
      data="$2"
      shift 2
      ;;
    -K|--config|-H|-X)
      shift 2
      ;;
    -*)
      shift
      ;;
    http://*|https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

printf '%s\n' "$url" >> "$FAKE_CURL_LOG"

case "$url" in
  */v0/management/auth-files)
    cat <<'JSON'
{
  "files": [
    {"auth_index": "codex-1", "provider": "codex", "label": "Codex Max", "disabled": false, "status": "active"},
    {"auth_index": "claude-1", "provider": "claude", "label": "Claude Pro", "disabled": false, "status": "active"},
    {"auth_index": "disabled-1", "provider": "codex", "label": "Disabled", "disabled": true, "status": "disabled"},
    {"auth_index": "unavailable-1", "provider": "codex", "label": "Unavailable", "disabled": false, "unavailable": true, "status": "active"},
    {"auth_index": "gemini-1", "provider": "gemini", "label": "Gemini", "disabled": false, "status": "active"}
  ]
}
JSON
    ;;
  */v0/management/api-call)
    printf '%s\n' "$data" >> "$FAKE_API_PAYLOADS"
    auth_index="$(printf '%s' "$data" | jq -r '.auth_index')"
    target_url="$(printf '%s' "$data" | jq -r '.url')"
    case "$auth_index:$target_url" in
      codex-1:https://chatgpt.com/backend-api/wham/usage)
        printf '%s\n' '{"status_code":200,"body":"{\"provider\":\"codex\",\"plan_type\":\"max\",\"quota\":{\"five_hour\":{\"used_percent\":10,\"remaining\":90,\"reset_after_seconds\":300},\"weekly_limit\":{\"used_percent\":20,\"remaining\":80,\"resets_in_seconds\":600}}}"}'
        ;;
      claude-1:https://api.anthropic.com/api/oauth/usage)
        printf '%s\n' '{"status_code":200,"body":"{\"provider\":\"claude\",\"windows\":[{\"key\":\"five_hour\",\"used_percent\":30,\"reset_after_seconds\":900},{\"key\":\"weekly\",\"used_percent\":40,\"reset_after_seconds\":1200}]}"}'
        ;;
      *)
        printf '%s\n' '{"status_code":404,"body":"{}"}'
        ;;
    esac
    ;;
  *)
    echo "unexpected URL: $url" >&2
    exit 9
    ;;
esac
CURL
chmod +x "$fake_bin/curl"

PATH="$fake_bin:$PATH" \
FAKE_CURL_LOG="$curl_log" \
FAKE_API_PAYLOADS="$api_payloads" \
ENV_FILE="$env_file" \
CPA_QUOTA_NOW=2026-07-07T08:00:00Z \
  "$SCRIPT" >/tmp/cpa-quota-refresh-all-test.out

[ -f "$public_dir/quota-snapshot.json" ] || fail "quota-snapshot.json was not published"
[ -f "$public_dir/codex-quota.json" ] || fail "legacy codex snapshot was not published"

if grep -q "config-secret-should-not-leak" "$curl_log" "$api_payloads" "$public_dir/quota-snapshot.json"; then
  fail "management key leaked into logs, payloads, or public snapshot"
fi

python3 - "$public_dir/quota-snapshot.json" "$api_payloads" <<'PY'
import json
import pathlib
import sys

snapshot = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
payloads = [json.loads(line) for line in pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()]

assert snapshot["queried_at"] == "2026-07-07T08:00:00Z"
assert [provider["provider"] for provider in snapshot["providers"]] == ["codex", "claude"]
assert snapshot["providers"][0]["accounts"][0]["label"] == "Codex Max"
assert snapshot["providers"][0]["accounts"][0]["windows"][0]["used_percent"] == 10
assert snapshot["providers"][1]["accounts"][0]["label"] == "Claude Pro"
assert snapshot["providers"][1]["accounts"][0]["windows"][1]["used_percent"] == 40

assert len(payloads) == 2
assert {payload["auth_index"] for payload in payloads} == {"codex-1", "claude-1"}
assert all(payload["method"] == "GET" for payload in payloads)
assert all(payload["header"]["Authorization"] == "Bearer $TOKEN$" for payload in payloads)
PY

echo "cpa quota refresh-all tests passed"
