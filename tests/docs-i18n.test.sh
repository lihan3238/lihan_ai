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
release-deployment-runbook.md
edge-proxy-runbook.md
migration-runbook.md
disaster-recovery-runbook.md
git-branching-runbook.md
cpa-runbook.md
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

for keyword in "docker-compose.cpa.yml" "docker-compose.cpa.ui.yml" "ssh -L 8317" "ops/sync-cpa-upstream-assets.sh" "/opt/lihan_ai/data/cpa"; do
  assert_contains "docs/cpa-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/cpa-runbook.md" "$keyword"
done

for keyword in "Firewall Baseline" "Troubleshooting" "URL-safe" "Caddy"; do
  assert_contains "docs/production-deployment-runbook.md" "$keyword"
done

for keyword in "防火墙基线" "排障" "URL-safe" "Caddy"; do
  assert_contains "docs/zh-CN/production-deployment-runbook.md" "$keyword"
done

for keyword in "drill-restore-stack.sh" "ENV_FILE=.env.production" "check-production-runtime.sh"; do
  assert_contains "docs/backup-strategy.md" "$keyword"
  assert_contains "docs/zh-CN/backup-strategy.md" "$keyword"
done

for keyword in "/opt/lihan_ai_deploy" "ops/deploy-release.sh" "docker compose -p" "DEPLOY_INCLUDE_CPA" "rollback" "PM2" "SMOKE_BACKUP_PATH" "lihan_ai_runtime" "docker inspect relay-cpa" "disaster-recovery-runbook.md"; do
  assert_contains "docs/release-deployment-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/release-deployment-runbook.md" "$keyword"
done

for keyword in "remote-management.allow-remote" "Base URL" "docker run -p 8317:8317" "/CLIProxyAPI/config.yaml"; do
  assert_contains "docs/cpa-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/cpa-runbook.md" "$keyword"
done

echo "docs i18n tests passed"
