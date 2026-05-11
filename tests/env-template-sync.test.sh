#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q -- "$pattern" "$file" || fail "$file missing pattern: $pattern"
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -q -- "$pattern" "$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

assert_executable() {
  [ -x "$ROOT_DIR/$1" ] || fail "missing executable: $1"
}

assert_executable "ops/sync-env-template.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

target="$tmp_dir/.env.production"
example="$tmp_dir/.env.production.example"

cat > "$target" <<'ENV'
DEPLOY_ENV=production
DOMAIN=api.example.test
POSTGRES_PASSWORD=keep-existing-secret
OLD_MONITOR_KEY=legacy-value
ENV

cat > "$example" <<'ENV'
# comments are ignored
DEPLOY_ENV=production
DOMAIN=api.example.com
POSTGRES_PASSWORD=CHANGE_ME_POSTGRES_PASSWORD_32_RANDOM_CHARS
REDIS_PASSWORD=CHANGE_ME_REDIS_PASSWORD_32_RANDOM_CHARS
DEPLOY_INCLUDE_CPA=0
QUOTED_VALUE="hello world"
ENV

output="$(bash "$ROOT_DIR/ops/sync-env-template.sh" "$target" "$example")"

assert_contains "$target" '^POSTGRES_PASSWORD=keep-existing-secret$'
assert_contains "$target" '^REDIS_PASSWORD=CHANGE_ME_REDIS_PASSWORD_32_RANDOM_CHARS$'
assert_contains "$target" '^DEPLOY_INCLUDE_CPA=0$'
assert_contains "$target" '^QUOTED_VALUE="hello world"$'
assert_contains "$target" '^OLD_MONITOR_KEY=legacy-value$'
[ "$(grep -c '^DOMAIN=' "$target")" -eq 1 ] || fail "existing keys must not be duplicated"

backup_count="$(find "$tmp_dir" -maxdepth 1 -type f -name '.env.production.bak.*' | wc -l | tr -d ' ')"
[ "$backup_count" -eq 1 ] || fail "sync should create exactly one backup, got $backup_count"

printf '%s' "$output" | grep -q "added REDIS_PASSWORD" || fail "sync output should list added keys: $output"
printf '%s' "$output" | grep -q "added DEPLOY_INCLUDE_CPA" || fail "sync output should list added keys: $output"
printf '%s' "$output" | grep -q "deprecated OLD_MONITOR_KEY" || fail "sync output should report deprecated keys: $output"
printf '%s' "$output" | grep -q "backup=" || fail "sync output should include backup path: $output"
assert_not_contains "$target" '^# OLD_MONITOR_KEY='

second_output="$(bash "$ROOT_DIR/ops/sync-env-template.sh" "$target" "$example")"
printf '%s' "$second_output" | grep -q "no missing keys" || fail "second sync should be idempotent: $second_output"

echo "env template sync tests passed"
