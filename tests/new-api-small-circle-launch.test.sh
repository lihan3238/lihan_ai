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

assert_file "docs/new-api-small-circle-launch-runbook.md"
assert_file "docs/zh-CN/new-api-small-circle-launch-runbook.md"
assert_file "e2e/new-api-admin-users.spec.ts"
assert_executable "ops/check-new-api-admin-frontend.sh"

assert_contains "docs/i18n-map.md" "docs/new-api-small-circle-launch-runbook.md"
assert_contains "docs/i18n-map.md" "docs/zh-CN/new-api-small-circle-launch-runbook.md"
assert_contains "README.md" "new-api-small-circle-launch-runbook.md"
assert_contains "README.zh-CN.md" "new-api-small-circle-launch-runbook.md"
assert_contains "docs/ops-quick-reference.md" "Small Circle Launch"
assert_contains "docs/zh-CN/ops-quick-reference.md" "Small Circle Launch"

for file in docs/new-api-small-circle-launch-runbook.md docs/zh-CN/new-api-small-circle-launch-runbook.md; do
  assert_contains "$file" "station quota"
  assert_contains "$file" "not official USD"
  assert_contains "$file" "5"
  assert_contains "$file" "50"
  assert_contains "$file" "100"
  assert_contains "$file" "200"
  assert_contains "$file" "1000"
  assert_contains "$file" "default"
  assert_contains "$file" "vip"
  assert_contains "$file" "fair use"
  assert_contains "$file" "manual activation"
  assert_contains "$file" "calciumion/new-api:latest"
  assert_contains "$file" "NEW_API_IMAGE"
  assert_contains "$file" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD"
  assert_contains "$file" "lihan3238/new-api"
  assert_contains "$file" "5741c359"
  assert_contains "$file" "#4692"
  assert_contains "$file" "#4787"
  assert_contains "$file" "Manage Bindings"
  assert_contains "$file" "Manage Subscriptions"
  assert_contains "$file" "ops/check-new-api-admin-frontend.sh"
  assert_contains "$file" "NEW_API_ADMIN_USERNAME"
  assert_contains "$file" "NEW_API_ADMIN_PASSWORD"
  assert_contains "$file" "WeChat Moments"
  assert_not_contains "$file" "30 USD"
  assert_not_contains "$file" "100 USD"
  assert_not_contains "$file" "250 USD"
  assert_not_contains "$file" "150 USD"
done

assert_contains "package.json" "\"e2e:web:new-api-admin\""
assert_contains "e2e/new-api-admin-users.spec.ts" "NEW_API_ADMIN_USERNAME"
assert_contains "e2e/new-api-admin-users.spec.ts" "NEW_API_ADMIN_PASSWORD"
assert_contains "e2e/new-api-admin-users.spec.ts" "Manage Bindings"
assert_contains "e2e/new-api-admin-users.spec.ts" "Manage Subscriptions"
assert_contains "e2e/new-api-admin-users.spec.ts" "/users"
assert_contains "ops/check-new-api-admin-frontend.sh" "e2e:web:new-api-admin"
assert_contains "ops/check-new-api-admin-frontend.sh" "CHECK_LOCAL_NEW_API_PATCH"
assert_contains "ops/check-new-api-admin-frontend.sh" "npm run typecheck"
assert_contains "ops/check-new-api-admin-frontend.sh" "npm run build"
assert_contains "ops/check-new-api-admin-frontend.sh" "dropdown-menu.test.tsx"

echo "new-api small circle launch tests passed"
