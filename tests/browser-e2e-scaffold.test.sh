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

assert_not_file() {
  [ ! -f "$ROOT_DIR/$1" ] || fail "file should have been removed: $1"
}

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -q "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

assert_file "package.json"
assert_file "playwright.config.ts"
assert_file "e2e/new-api-smoke.spec.ts"
assert_not_file "e2e/kuma-status.spec.ts"
assert_file "docs/browser-e2e-runbook.md"

assert_contains "package.json" "\"e2e:web\""
assert_contains "package.json" "\"e2e:web:new-api\""
assert_contains "package.json" "@playwright/test"
assert_contains "playwright.config.ts" "NEW_API_BASE_URL"
assert_not_contains "playwright.config.ts" "KUMA_BASE_URL"
assert_contains "e2e/new-api-smoke.spec.ts" "/api/status"
assert_contains "docs/browser-e2e-runbook.md" "NEW_API_BASE_URL"
assert_not_contains "docs/browser-e2e-runbook.md" "KUMA_"
assert_contains ".gitignore" "^.auth/$"
assert_contains ".gitignore" "^playwright-report/$"
assert_contains ".gitignore" "^test-results/$"

if grep -RIEq 'sk-[A-Za-z0-9]{20,}|NEW_API_TEST_TOKEN=' "$ROOT_DIR/e2e" "$ROOT_DIR/playwright.config.ts" "$ROOT_DIR/package.json"; then
  fail "browser e2e scaffold contains secret-looking content"
fi

echo "browser-e2e scaffold tests passed"
