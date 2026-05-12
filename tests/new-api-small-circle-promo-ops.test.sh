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

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q -- "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

for file in \
  docs/new-api-small-circle-promo-ops.md \
  docs/zh-CN/new-api-small-circle-promo-ops.md
do
  assert_file "$file"
  assert_contains "$file" "Lihan AI Relay"
  assert_contains "$file" "HomePageContent"
  assert_contains "$file" "Notice"
  assert_contains "$file" "Announcements"
  assert_contains "$file" "console_setting.api_info"
  assert_contains "$file" "console_setting.faq"
  assert_contains "$file" "https://api.lihan3238.com"
  assert_contains "$file" "https://api.lihan3238.com/v1"
  assert_contains "$file" "station quota is not official USD balance"
  assert_contains "$file" "Manual activation"
  assert_contains "$file" "WeChat"
  assert_contains "$file" "QQ"
  assert_contains "$file" "request id"
  assert_contains "$file" "default"
  assert_contains "$file" "vip"
  assert_contains "$file" "docs/browser-e2e-runbook.md"
done

assert_contains "README.md" "new-api-small-circle-promo-ops.md"
assert_contains "README.zh-CN.md" "new-api-small-circle-promo-ops.md"
assert_contains "docs/i18n-map.md" "docs/new-api-small-circle-promo-ops.md"
assert_contains "docs/i18n-map.md" "docs/zh-CN/new-api-small-circle-promo-ops.md"

echo "new-api small circle promo ops tests passed"
