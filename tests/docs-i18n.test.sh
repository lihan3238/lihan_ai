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
  grep -q -- "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -q -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

assert_file "README.md"
assert_file "README.zh-CN.md"
assert_file "docs/i18n-map.md"
assert_contains "README.md" "README.zh-CN.md"
assert_contains "README.zh-CN.md" "README.md"

docs="
production-deployment-runbook.md
release-deployment-runbook.md
cloudflare-saas-runbook.md
edge-proxy-runbook.md
migration-runbook.md
disaster-recovery-runbook.md
git-branching-runbook.md
cpa-runbook.md
backup-strategy.md
operations-runbook.md
ops-quick-reference.md
maintainer-release-runbook.md
user-quickstart.md
user-guide.md
server-buying-guide.md
new-api-small-circle-launch-runbook.md
new-api-small-circle-promo-ops.md
"

for doc in $docs; do
  assert_file "docs/$doc"
  assert_file "docs/zh-CN/$doc"
  assert_contains "docs/i18n-map.md" "docs/$doc"
  assert_contains "docs/i18n-map.md" "docs/zh-CN/$doc"

  if grep -Eiq '\b(TBD|TODO|FIXME)\b|待定|未定' "$ROOT_DIR/docs/zh-CN/$doc"; then
    fail "docs/zh-CN/$doc contains placeholder text"
  fi
done

assert_not_file "docs/kuma-status-runbook.md"

for keyword in ".github/workflows/ci.yml" "GitHub Actions PR CI" "ops/backup-cron.sh" "ops/dev-gate.sh" "ops/relayctl.sh" "E2E Coverage Matrix" "vendor/cli-proxy-api" "new-api-small-circle-launch-runbook.md"; do
  assert_contains "README.md" "$keyword"
  assert_contains "README.zh-CN.md" "$keyword"
done

for keyword in "ops/relayctl.sh" "release-check" "deploy-prepare" "deploy-promote" "GitHub Actions" "manual"; do
  assert_contains "docs/maintainer-release-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/maintainer-release-runbook.md" "$keyword"
done

for keyword in "https://api.lihan3238.com/v1" "OpenAI-compatible" "API Key" "station quota"; do
  assert_contains "docs/user-quickstart.md" "$keyword"
  assert_contains "docs/user-guide.md" "$keyword"
  assert_contains "docs/zh-CN/user-quickstart.md" "$keyword"
  assert_contains "docs/zh-CN/user-guide.md" "$keyword"
done

for keyword in "ops/backup-cron.sh" "ops/backup-postgres.sh" "ops/verify-postgres-backup.sh" "ops/drill-restore-stack.sh" "ops/restore-postgres.sh" "ops/prune-runtime-storage.sh" "BACKUP_KEEP" "BACKUP_MAX_TOTAL_MB" "scp"; do
  assert_contains "docs/backup-strategy.md" "$keyword"
  assert_contains "docs/zh-CN/backup-strategy.md" "$keyword"
  assert_contains "docs/ops-quick-reference.md" "$keyword"
  assert_contains "docs/zh-CN/ops-quick-reference.md" "$keyword"
done

for keyword in "manually downloaded dump" "ops/deploy-release.sh bootstrap" "SMOKE_BACKUP_PATH" "ops/restore-postgres.sh"; do
  assert_contains "docs/disaster-recovery-runbook.md" "$keyword"
done

for keyword in "手动下载" "ops/deploy-release.sh bootstrap" "SMOKE_BACKUP_PATH" "ops/restore-postgres.sh"; do
  assert_contains "docs/zh-CN/disaster-recovery-runbook.md" "$keyword"
done

for keyword in "ops/sync-env-template.sh" "ops/check-production-runtime.sh" "ops/backup-cron.sh" "ops/prune-runtime-storage.sh" "ops/deploy-release.sh status" "ops/deploy-release.sh recover" "default" "vip" "docker inspect relay-cpa"; do
  assert_contains "docs/operations-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/operations-runbook.md" "$keyword"
done

for keyword in "/opt/lihan_ai_deploy" "candidate" "SMOKE_BACKUP_PATH" "lihan_ai_runtime" "docker inspect relay-cpa" "disaster-recovery-runbook.md" "sync-env-template.sh" "promote.state" "last_healthy" "ops/deploy-release.sh status" "ops/deploy-release.sh recover"; do
  assert_contains "docs/release-deployment-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/release-deployment-runbook.md" "$keyword"
done

for keyword in "Firewall Baseline" "Troubleshooting" "URL-safe" "Caddy"; do
  assert_contains "docs/production-deployment-runbook.md" "$keyword"
done

for keyword in "防火墙基线" "排障" "URL-safe" "Caddy"; do
  assert_contains "docs/zh-CN/production-deployment-runbook.md" "$keyword"
done

for keyword in "api.lihan3238.com" "origin.lihan3238.top" "Cloudflare Tunnel" "cloudflared" "--scale caddy=0" "config.yml is file" "tunnel.json is file" "chmod 644" "cannot be hand-written"; do
  assert_contains "docs/cloudflare-saas-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "$keyword"
done

for keyword in "ORIGIN_UPSTREAM" "docker-compose.edge.yml" ".env.edge"; do
  assert_contains "docs/edge-proxy-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/edge-proxy-runbook.md" "$keyword"
done

for keyword in "CONFIRM_FINAL_CUTOVER=yes" "ops/migrate-prod.sh" "SOURCE_SSH" "TARGET_SSH"; do
  assert_contains "docs/migration-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/migration-runbook.md" "$keyword"
done

for keyword in "docker-compose.cpa.yml" "docker-compose.cpa.ui.yml" "ssh -L 8317" "ops/sync-cpa-upstream-assets.sh" "/opt/lihan_ai_deploy/shared/data/cpa" "docker compose -p lihan_ai" "docker-compose.cloudflare-tunnel.yml" "ops/cpa-ui.sh" "--no-deps" "logs-max-total-size-mb" "error-logs-max-files"; do
  assert_contains "docs/cpa-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/cpa-runbook.md" "$keyword"
done

for keyword in "cpa-quota-static" "/cpa-quota/*" "ops/cpa-quota-snapshot.sh" "cpa-quota/widget.html"; do
  assert_not_contains "docs/cloudflare-saas-runbook.md" "$keyword"
  assert_not_contains "docs/zh-CN/cloudflare-saas-runbook.md" "$keyword"
  assert_not_contains "docs/cpa-runbook.md" "$keyword"
  assert_not_contains "docs/zh-CN/cpa-runbook.md" "$keyword"
done

for keyword in "CPA Upstream Egress Proxy" "proxy-url" "socks5://newapi" "Proxy Address: empty" "systemctl is-enabled gost" "permission denied" "docker restart relay-cpa"; do
  assert_contains "docs/cpa-runbook.md" "$keyword"
done

for keyword in "CPA 上游出站代理" "proxy-url" "socks5://newapi" "Proxy Address：留空" "systemctl is-enabled gost" "permission denied" "docker restart relay-cpa"; do
  assert_contains "docs/zh-CN/cpa-runbook.md" "$keyword"
done

for keyword in "NEW_API_BASE_URL" "npm run e2e:web:new-api" "ops/check-local-ports.sh"; do
  assert_contains "docs/browser-e2e-runbook.md" "$keyword"
done

for keyword in "Small Circle Launch" "station quota" "not official USD" "ops/check-new-api-admin-frontend.sh" "#4787" "v1.0.0-rc.5" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1" "rollback" "lihan3238/new-api"; do
  assert_contains "docs/new-api-small-circle-launch-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/new-api-small-circle-launch-runbook.md" "$keyword"
done

for keyword in "Lihan AI Relay" "HomePageContent" "console_setting.api_info" "console_setting.faq" "https://api.lihan3238.com/v1" "station quota is not official USD balance" "WeChat Moments" "QQ Zone" "Fault report"; do
  assert_contains "docs/new-api-small-circle-promo-ops.md" "$keyword"
done

for keyword in "Lihan AI Relay" "HomePageContent" "console_setting.api_info" "console_setting.faq" "https://api.lihan3238.com/v1" "station quota is not official USD balance"; do
  assert_contains "docs/zh-CN/new-api-small-circle-promo-ops.md" "$keyword"
done

for keyword in "Layered E2E Policy" "ops/dev-gate.sh" "E2E Coverage Matrix" "Reason:" "Rerun:"; do
  assert_contains "docs/development-workflow.md" "$keyword"
done

for keyword in "main = production" "codex/<topic>" "hotfix/<topic>" "GitHub Actions PR CI" "production-gate" "live databases"; do
  assert_contains "docs/git-branching-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/git-branching-runbook.md" "$keyword"
done

for file in \
  README.md README.zh-CN.md \
  docs/backup-strategy.md docs/zh-CN/backup-strategy.md \
  docs/disaster-recovery-runbook.md docs/zh-CN/disaster-recovery-runbook.md \
  docs/operations-runbook.md docs/zh-CN/operations-runbook.md \
  docs/ops-quick-reference.md docs/zh-CN/ops-quick-reference.md \
  docs/release-deployment-runbook.md docs/zh-CN/release-deployment-runbook.md \
  docs/production-deployment-runbook.md docs/zh-CN/production-deployment-runbook.md \
  docs/maintainer-release-runbook.md docs/zh-CN/maintainer-release-runbook.md \
  docs/cpa-runbook.md docs/zh-CN/cpa-runbook.md \
  docs/edge-proxy-runbook.md docs/zh-CN/edge-proxy-runbook.md \
  docs/browser-e2e-runbook.md
do
  assert_not_contains "$file" "Uptime Kuma"
  assert_not_contains "$file" "kuma-status"
  assert_not_contains "$file" "production-monitor"
  assert_not_contains "$file" "ops-dashboard"
  assert_not_contains "$file" "ops-health"
  assert_not_contains "$file" "offsite-backup"
  assert_not_contains "$file" "RESTIC_"
  assert_not_contains "$file" "MONITOR_PUSH"
done

echo "docs i18n tests passed"
