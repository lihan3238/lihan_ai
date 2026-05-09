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
  grep -q "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_file "README.zh-CN.md"
assert_file "docs/i18n-map.md"
assert_contains "README.md" "README.zh-CN.md"

docs="
production-deployment-runbook.md
edge-proxy-runbook.md
migration-runbook.md
disaster-recovery-runbook.md
backup-strategy.md
operations-runbook.md
server-buying-guide.md
"

for doc in $docs; do
  assert_file "docs/$doc"
  assert_file "docs/zh-CN/$doc"
  assert_contains "docs/i18n-map.md" "docs/$doc"
  assert_contains "docs/i18n-map.md" "docs/zh-CN/$doc"

  if grep -Eiq '\b(TBD|TODO|FIXME)\b|待定|占位|稍后|未定' "$ROOT_DIR/docs/zh-CN/$doc"; then
    fail "docs/zh-CN/$doc contains placeholder text"
  fi
done

for keyword in "docker compose" ".env.production" "DEPLOY_HOST" "ops/deploy-prod.sh" "ops/verify-remote-prod.sh"; do
  assert_contains "README.md" "$keyword"
  assert_contains "README.zh-CN.md" "$keyword"
done

for keyword in "CONFIRM_FINAL_CUTOVER=yes" "ops/migrate-prod.sh" "SOURCE_SSH" "TARGET_SSH"; do
  assert_contains "docs/migration-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/migration-runbook.md" "$keyword"
done

for keyword in "RESTIC_REPOSITORY" "ops/offsite-backup.sh" "ops/restore-postgres.sh"; do
  assert_contains "docs/disaster-recovery-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/disaster-recovery-runbook.md" "$keyword"
done

for keyword in "ORIGIN_UPSTREAM" "docker-compose.edge.yml" ".env.edge"; do
  assert_contains "docs/edge-proxy-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/edge-proxy-runbook.md" "$keyword"
done

echo "docs i18n tests passed"
