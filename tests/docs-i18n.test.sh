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

assert_file "README.zh-CN.md"
assert_file "docs/i18n-map.md"
assert_contains "README.md" "README.zh-CN.md"

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

for keyword in ".github/workflows/ci.yml" "GitHub Actions PR CI"; do
  assert_contains "README.md" "$keyword"
  assert_contains "README.zh-CN.md" "$keyword"
done

for keyword in "Common Production Commands" "Initial production deployment" "Update production to latest main" "Open and close CPA UI" "ops/deploy-release.sh bootstrap" "ops/deploy-release.sh prepare" "ops/deploy-release.sh smoke" "ops/deploy-release.sh promote" 'remote `.env.production`' "DEPLOY_INCLUDE_*" "ops/cpa-ui.sh open" "ops/cpa-ui.sh close" "ssh -L 8317"; do
  assert_contains "README.md" "$keyword"
done

for keyword in "Production Cron monitoring" "ops/production-monitor.sh runtime" "ops/production-monitor.sh backup" "ops/production-monitor.sh offsite" "ops/production-monitor.sh audit" "ops/production-monitor.sh restore-drill" "MONITOR_ALERT_WEBHOOK_URL" "MONITOR_PUSH_AUDIT_URL" "ops-dashboard.sh open"; do
  assert_contains "README.md" "$keyword"
done

for keyword in "生产常用命令" "初始部署" "更新最新版本到生产环境" "打开和关闭 CPA UI" "ops/deploy-release.sh bootstrap" "ops/deploy-release.sh prepare" "ops/deploy-release.sh smoke" "ops/deploy-release.sh promote" "DEPLOY_INCLUDE_*" "ops/cpa-ui.sh open" "ops/cpa-ui.sh close" "ssh -L 8317"; do
  assert_contains "README.zh-CN.md" "$keyword"
done

for keyword in "ops/production-monitor.sh runtime" "ops/production-monitor.sh backup" "ops/production-monitor.sh offsite" "ops/production-monitor.sh audit" "ops/production-monitor.sh restore-drill" "MONITOR_ALERT_WEBHOOK_URL" "MONITOR_PUSH_AUDIT_URL" "ops-dashboard.sh open"; do
  assert_contains "README.zh-CN.md" "$keyword"
done

for keyword in "CONFIRM_FINAL_CUTOVER=yes" "ops/migrate-prod.sh" "SOURCE_SSH" "TARGET_SSH"; do
  assert_contains "docs/migration-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/migration-runbook.md" "$keyword"
done

for keyword in "RESTIC_REPOSITORY" "ops/offsite-backup.sh" "ops/restore-postgres.sh" "ops/production-monitor.sh backup" "ops/production-monitor.sh offsite" "ops/production-monitor.sh audit" "ops/production-monitor.sh restore-drill" "MONITOR_PUSH_RESTORE_DRILL_URL"; do
  assert_contains "docs/disaster-recovery-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/disaster-recovery-runbook.md" "$keyword"
done

for keyword in "ORIGIN_UPSTREAM" "docker-compose.edge.yml" ".env.edge"; do
  assert_contains "docs/edge-proxy-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/edge-proxy-runbook.md" "$keyword"
done

for keyword in "api.lihan3238.com" "origin.lihan3238.top" "Cloudflare Tunnel" "cloudflared" "--scale caddy=0" "config.yml is file" "tunnel.json is file" "chmod 644" "cannot be hand-written"; do
  assert_contains "docs/cloudflare-saas-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "$keyword"
done

for keyword in "docker-compose.cpa.yml" "docker-compose.cpa.ui.yml" "ssh -L 8317" "ops/sync-cpa-upstream-assets.sh" "/opt/lihan_ai/data/cpa" "docker compose -p lihan_ai" "docker-compose.cloudflare-tunnel.yml" "ops/cpa-ui.sh" "--no-deps" "Ops Dashboard" "Uptime Kuma Push monitors"; do
  assert_contains "docs/cpa-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/cpa-runbook.md" "$keyword"
done

for keyword in "CPA Upstream Egress Proxy" "proxy-url" "socks5://newapi" "Proxy Address: empty" "systemctl is-enabled gost" "permission denied" "docker restart relay-cpa"; do
  assert_contains "docs/cpa-runbook.md" "$keyword"
done

for keyword in "CPA 上游出站代理" "proxy-url" "socks5://newapi" "Proxy Address：留空" "systemctl is-enabled gost" "permission denied" "docker restart relay-cpa"; do
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

for keyword in "ops/production-monitor.sh runtime" "ops/production-monitor.sh backup" "ops/production-monitor.sh offsite" "ops/production-monitor.sh audit" "ops/production-monitor.sh restore-drill" "MONITOR_ALERT_WEBHOOK_URL" "MONITOR_PUSH_AUDIT_URL" "ops-dashboard.sh open" "production-monitor-runtime.log"; do
  assert_contains "docs/backup-strategy.md" "$keyword"
  assert_contains "docs/zh-CN/backup-strategy.md" "$keyword"
  assert_contains "docs/operations-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/operations-runbook.md" "$keyword"
done

for keyword in "/opt/lihan_ai_deploy" "ops/deploy-release.sh" "docker compose -p" "DEPLOY_INCLUDE_CPA" "rollback" "PM2" "SMOKE_BACKUP_PATH" "candidate" "lihan_ai_runtime" "docker inspect relay-cpa" "disaster-recovery-runbook.md"; do
  assert_contains "docs/release-deployment-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/release-deployment-runbook.md" "$keyword"
done

for keyword in "ops/production-monitor.sh runtime" "ops/production-monitor.sh backup" "ops/production-monitor.sh offsite" "ops/production-monitor.sh audit" "ops/production-monitor.sh restore-drill"; do
  assert_contains "docs/release-deployment-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/release-deployment-runbook.md" "$keyword"
done

for keyword in "Daily quick check" "Arch Linux" "cronie" "systemctl is-active cronie" "production-monitor.sh runtime" "production-monitor.sh audit" "ops/deploy-release.sh promote" "ops/verify-remote-prod.sh" "set -a; . ./.env.production; set +a" "restic snapshots" "restore-postgres.sh" "df -Pi" "inode_status"; do
  assert_contains "docs/ops-quick-reference.md" "$keyword"
done

for keyword in "Arch Linux" "cronie" "systemctl is-active cronie" "production-monitor.sh runtime" "production-monitor.sh audit" "ops/deploy-release.sh promote" "ops/verify-remote-prod.sh" "set -a; . ./.env.production; set +a" "restic snapshots" "restore-postgres.sh" "df -Pi" "inode_status"; do
  assert_contains "docs/zh-CN/ops-quick-reference.md" "$keyword"
done

for keyword in "remote-management.allow-remote" "Base URL" "docker run -p 8317:8317" "/CLIProxyAPI/config.yaml"; do
  assert_contains "docs/cpa-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/cpa-runbook.md" "$keyword"
done

for keyword in "GitHub Actions PR CI" "production-gate" "live databases"; do
  assert_contains "docs/git-branching-runbook.md" "$keyword"
  assert_contains "docs/zh-CN/git-branching-runbook.md" "$keyword"
done

echo "docs i18n tests passed"
