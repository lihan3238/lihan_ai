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

assert_executable "ops/cpa-quota-snapshot.sh"
assert_file "public/cpa-quota/home.html"
assert_file "public/cpa-quota/widget.html"
assert_file "Caddyfile.cpa-quota"
[ -d "$ROOT_DIR/public/cpa-quota/data" ] || fail "missing CPA quota public data mountpoint"

assert_contains "Caddyfile" "handle_path /cpa-quota/*"
assert_contains "Caddyfile" "cpa-quota-static:8080"
assert_contains "Caddyfile" "Cache-Control"
assert_not_contains "Caddyfile" "8317"
assert_contains "Caddyfile.cpa-quota" "handle_path /cpa-quota/*"
assert_contains "Caddyfile.cpa-quota" "/srv/cpa-quota"
assert_contains "Caddyfile.cpa-quota" "Access-Control-Allow-Origin"
assert_contains "Caddyfile.cpa-quota" "/data/*"
assert_contains "Caddyfile.cpa-quota" "/cpa-quota/data/*"

assert_contains "docker-compose.cpa.yml" "cpa-quota-static"
assert_contains "docker-compose.cpa.yml" "./public/cpa-quota:/srv/cpa-quota:ro"
assert_contains "docker-compose.cpa.yml" "CPA_PUBLIC_PATH"
assert_contains "docker-compose.cpa.yml" ":/srv/cpa-quota/data:ro"
assert_contains "docker-compose.cpa.yml" "./Caddyfile.cpa-quota:/etc/caddy/Caddyfile:ro"
assert_contains ".env.production.example" "CPA_PUBLIC_PATH=/opt/lihan_ai_deploy/shared/data/cpa/public"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

raw="$tmp_dir/raw-quota.json"
out="$tmp_dir/quota-snapshot.json"

cat > "$raw" <<'JSON'
{
  "email": "human@example.com",
  "api_key": "sk-secret-should-not-leak",
  "access_token": "token-should-not-leak",
  "plan_type": "prolite",
  "quota": {
    "five_hour": {
      "used_percent": 37.5,
      "used": 75,
      "limit": 200,
      "remaining": 125,
      "reset_after_seconds": 3600,
      "reset_at": 1783404860
    },
    "weekly_limit": {
      "used_percent": 80,
      "limit_window_seconds": 604800,
      "resets_in_seconds": 86400,
      "resets_at": 1784000000
    }
  }
}
JSON

CPA_QUOTA_NOW=2026-07-07T00:00:00Z \
  bash "$ROOT_DIR/ops/cpa-quota-snapshot.sh" \
    --input "$raw" \
    --output "$out" \
    --label "Codex pool" >/dev/null

python3 - "$out" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
dumped = json.dumps(data, sort_keys=True)

assert data["schema_version"] == 2
assert data["generated_at"] == "2026-07-07T00:00:00Z"
assert data["source"] == "cpa"
assert len(data["providers"]) == 1

provider = data["providers"][0]
assert provider["provider"] == "codex"
assert provider["title"] == "Codex"
assert len(provider["accounts"]) == 1

account = provider["accounts"][0]
assert account["label"] == "Codex pool"
assert account["plan_type"] == "prolite"

five = account["windows"][0]
weekly = account["windows"][1]
assert five["key"] == "five_hour"
assert five["title"] == "5-hour limit"
assert five["used_percent"] == 37.5
assert five["used"] == 75
assert five["limit"] == 200
assert five["remaining"] == 125
assert five["reset_after_seconds"] == 3600
assert five["reset_at"].endswith("Z")
assert weekly["key"] == "weekly"
assert weekly["title"] == "Weekly limit"
assert weekly["used_percent"] == 80
assert weekly["limit_window_seconds"] == 604800
assert weekly["reset_after_seconds"] == 86400
assert weekly["reset_at"].endswith("Z")

for secret in ("human@example.com", "sk-secret-should-not-leak", "token-should-not-leak"):
    assert secret not in dumped
PY

public_dir="$tmp_dir/public"
CPA_PUBLIC_PATH="$public_dir" CPA_QUOTA_NOW=2026-07-07T00:00:00Z \
  bash "$ROOT_DIR/ops/cpa-quota-snapshot.sh" --input "$raw" >/dev/null

[ -f "$public_dir/quota-snapshot.json" ] || fail "default output should use CPA_PUBLIC_PATH/quota-snapshot.json"
[ -f "$public_dir/codex-quota.json" ] || fail "default output should keep legacy CPA_PUBLIC_PATH/codex-quota.json"

multi="$tmp_dir/multi-quota.json"
multi_out="$tmp_dir/multi-quota-snapshot.json"
cat > "$multi" <<'JSON'
{
  "providers": [
    {
      "provider": "codex",
      "title": "GPT / Codex",
      "accounts": [
        {
          "label": "Codex Max",
          "email": "codex-owner@example.com",
          "access_token": "codex-token-should-not-leak",
          "plan_type": "max",
          "windows": [
            {
              "key": "five_hour",
              "title": "5-hour limit",
              "used_percent": 10,
              "remaining": 90,
              "reset_after_seconds": 1800
            },
            {
              "key": "weekly",
              "title": "Weekly limit",
              "used_percent": 40,
              "reset_after_seconds": 86400
            }
          ]
        },
        {
          "label": "Codex Team",
          "plan_type": "team",
          "windows": [
            {"key": "monthly", "title": "Monthly limit", "used_percent": 22}
          ]
        }
      ]
    },
    {
      "provider": "claude",
      "title": "Claude",
      "accounts": [
        {
          "label": "Claude Pro",
          "refresh_token": "claude-refresh-should-not-leak",
          "windows": [
            {"key": "five_hour", "title": "5-hour limit", "used_percent": 55},
            {"key": "seven_day_opus", "title": "7-day Opus", "used_percent": 12}
          ]
        },
        {
          "name": "claude-owner@example.com",
          "windows": [
            {"key": "weekly", "title": "Weekly limit", "used_percent": 7}
          ]
        }
      ]
    }
  ]
}
JSON

CPA_QUOTA_NOW=2026-07-07T00:00:00Z \
  bash "$ROOT_DIR/ops/cpa-quota-snapshot.sh" \
    --input "$multi" \
    --output "$multi_out" >/dev/null

python3 - "$multi_out" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
dumped = json.dumps(data, sort_keys=True)
assert data["schema_version"] == 2
assert [provider["provider"] for provider in data["providers"]] == ["codex", "claude"]
assert len(data["providers"][0]["accounts"]) == 2
assert len(data["providers"][1]["accounts"]) == 2
assert data["providers"][0]["accounts"][0]["windows"][0]["key"] == "five_hour"
assert data["providers"][1]["accounts"][0]["windows"][1]["key"] == "seven_day_opus"
assert data["providers"][1]["accounts"][1]["label"] == "Claude 2"
for secret in ("codex-owner@example.com", "codex-token-should-not-leak", "claude-refresh-should-not-leak", "claude-owner@example.com"):
    assert secret not in dumped
PY

assert_contains "public/cpa-quota/home.html" "quota-snapshot.json"
assert_contains "public/cpa-quota/home.html" "Lihan AI"
assert_contains "public/cpa-quota/home.html" "providers"
assert_contains "public/cpa-quota/home.html" "quota-only"
assert_not_contains "public/cpa-quota/home.html" "nav-actions"
assert_not_contains "public/cpa-quota/home.html" "Sign in"
assert_not_contains "public/cpa-quota/home.html" "One endpoint"
assert_not_contains "public/cpa-quota/home.html" "base_url"
assert_not_contains "public/cpa-quota/home.html" "/v0/management"
assert_not_contains "public/cpa-quota/home.html" "8317"
assert_contains "public/cpa-quota/widget.html" "quota-snapshot.json"
assert_contains "public/cpa-quota/widget.html" "codex-quota.json"
assert_contains "public/cpa-quota/widget.html" "providers"

echo "cpa quota snapshot tests passed"
