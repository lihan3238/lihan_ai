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
  mode="$(git -C "$ROOT_DIR" ls-files --stage -- "$1" | awk '{print $1}')"
  [ "$mode" = "100755" ] || fail "not executable in git index: $1 ($mode)"
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
assert_file "public/cpa-quota/widget.html"
assert_file "Caddyfile.cpa-quota"

assert_contains "Caddyfile" "handle_path /cpa-quota/*"
assert_contains "Caddyfile" "cpa-quota-static:8080"
assert_contains "Caddyfile" "Cache-Control"
assert_not_contains "Caddyfile" "8317"
assert_contains "Caddyfile.cpa-quota" "handle_path /cpa-quota/*"
assert_contains "Caddyfile.cpa-quota" "/srv/cpa-quota"

assert_contains "docker-compose.cpa.yml" "cpa-quota-static"
assert_contains "docker-compose.cpa.yml" "./public/cpa-quota:/srv/cpa-quota:ro"
assert_contains "docker-compose.cpa.yml" "CPA_PUBLIC_PATH"
assert_contains "docker-compose.cpa.yml" ":/srv/cpa-quota/data:ro"
assert_contains "docker-compose.cpa.yml" "./Caddyfile.cpa-quota:/etc/caddy/Caddyfile:ro"
assert_contains ".env.production.example" "CPA_PUBLIC_PATH=/opt/lihan_ai_deploy/shared/data/cpa/public"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

raw="$tmp_dir/raw-quota.json"
out="$tmp_dir/codex-quota.json"

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

assert data["schema_version"] == 1
assert data["generated_at"] == "2026-07-07T00:00:00Z"
assert data["source"] == "cpa"
assert len(data["accounts"]) == 1

account = data["accounts"][0]
assert account["label"] == "Codex pool"
assert account["plan_type"] == "prolite"

five = account["windows"]["five_hour"]
weekly = account["windows"]["weekly"]
assert five["used_percent"] == 37.5
assert five["used"] == 75
assert five["limit"] == 200
assert five["remaining"] == 125
assert five["reset_after_seconds"] == 3600
assert five["reset_at"].endswith("Z")
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

[ -f "$public_dir/codex-quota.json" ] || fail "default output should use CPA_PUBLIC_PATH/codex-quota.json"

assert_contains "public/cpa-quota/widget.html" "codex-quota.json"
assert_contains "public/cpa-quota/widget.html" "five_hour"
assert_contains "public/cpa-quota/widget.html" "weekly"

echo "cpa quota snapshot tests passed"
