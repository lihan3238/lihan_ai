#!/usr/bin/env sh
set -eu

skip_docker=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-docker|-SkipDocker)
      skip_docker=1
      shift
      ;;
    -h|--help)
      echo "usage: scripts/verify-repo.sh [--skip-docker]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$ROOT_DIR/$1" ] || fail "missing required file: $1"
}

assert_not_file() {
  [ ! -f "$ROOT_DIR/$1" ] || fail "removed file is still present: $1"
}

assert_dir() {
  [ -d "$ROOT_DIR/$1" ] || fail "missing required directory: $1"
}

assert_contains() {
  file="$1"
  pattern="$2"
  description="${3:-$pattern}"
  grep -Eq -- "$pattern" "$ROOT_DIR/$file" || fail "$file does not contain required content: $description"
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  description="${3:-$pattern}"
  if grep -Eq -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden content: $description"
  fi
}

while IFS= read -r path; do
  [ -n "$path" ] && assert_file "$path"
done <<'EOF'
README.md
README.zh-CN.md
docker-compose.yml
docker-compose.dev.yml
docker-compose.prod.yml
docker-compose.edge.yml
docker-compose.cpa.yml
docker-compose.cpa.ui.yml
docker-compose.cloudflare-tunnel.yml
.env.example
.env.production.example
.gitmodules
Caddyfile
Caddyfile.edge.example
.gitignore
AGENTS.md
.github/pull_request_template.md
.github/workflows/ci.yml
.github/workflows/cd.yml
.pre-commit-config.yaml
CONTRIBUTING.md
SECURITY.md
docs/operations-runbook.md
docs/new-api-code-map.md
docs/new-api-full-research.md
docs/local-development-state.md
docs/backup-strategy.md
docs/server-buying-guide.md
docs/development-workflow.md
docs/spec-kit-integration-runbook.md
docs/wrapper-infra-runbook.md
docs/browser-e2e-runbook.md
docs/production-deployment-runbook.md
docs/release-deployment-runbook.md
docs/cloudflare-saas-runbook.md
docs/edge-proxy-runbook.md
docs/migration-runbook.md
docs/disaster-recovery-runbook.md
docs/git-branching-runbook.md
docs/cpa-runbook.md
docs/i18n-map.md
docs/ops-quick-reference.md
docs/zh-CN/production-deployment-runbook.md
docs/zh-CN/release-deployment-runbook.md
docs/zh-CN/cloudflare-saas-runbook.md
docs/zh-CN/edge-proxy-runbook.md
docs/zh-CN/migration-runbook.md
docs/zh-CN/disaster-recovery-runbook.md
docs/zh-CN/git-branching-runbook.md
docs/zh-CN/cpa-runbook.md
docs/zh-CN/backup-strategy.md
docs/zh-CN/operations-runbook.md
docs/zh-CN/ops-quick-reference.md
docs/zh-CN/server-buying-guide.md
docs/new-api-small-circle-launch-runbook.md
docs/zh-CN/new-api-small-circle-launch-runbook.md
docs/maintainer-release-runbook.md
docs/zh-CN/maintainer-release-runbook.md
docs/user-quickstart.md
docs/user-guide.md
docs/zh-CN/user-quickstart.md
docs/zh-CN/user-guide.md
ops/preflight.sh
ops/dev-gate.sh
ops/feature-completion-check.sh
ops/backup-postgres.sh
ops/backup-cron.sh
ops/prune-runtime-storage.sh
ops/verify-postgres-backup.sh
ops/restore-postgres.sh
ops/e2e-api-billing.sh
ops/build-local-new-api.sh
ops/start-local-new-api.sh
ops/export-config-snapshot.sh
ops/drill-restore-postgres.sh
ops/drill-restore-stack.sh
ops/production-gate.sh
ops/ai-dev-check.sh
ops/validate-ops-profile.sh
ops/channel-health-advisor.sh
ops/live-e2e-billing-from-db-token.sh
ops/check-local-ports.sh
ops/bootstrap-server.sh
ops/deploy-prod.sh
ops/deploy-release.sh
ops/verify-remote-prod.sh
ops/migration-preflight.sh
ops/migrate-prod.sh
ops/check-production-runtime.sh
ops/sync-env-template.sh
ops/sync-cpa-upstream-assets.sh
ops/cpa-ui.sh
ops/check-new-api-admin-frontend.sh
ops/local-new-api-e2e.sh
ops/pre-commit.sh
ops/relayctl.sh
ops/release-readiness.sh
scripts/verify-repo.sh
tests/e2e-api-billing.test.sh
tests/dev-gate.test.sh
tests/feature-completion-check.test.sh
tests/wrapper-infra.test.sh
tests/ai-dev-check.test.sh
tests/ops-profile.test.sh
tests/spec-kit-init.test.sh
tests/channel-health-advisor.test.sh
tests/live-e2e-token-wrapper.test.sh
tests/check-local-ports.test.sh
tests/browser-e2e-scaffold.test.sh
tests/github-actions-ci.test.sh
tests/cloudflare-saas-domain.test.sh
tests/cloudflare-tunnel-compose.test.sh
tests/prod-deploy-migration.test.sh
tests/prod-deploy-hardening.test.sh
tests/local-new-api-build.test.sh
tests/cpa-compose.test.sh
tests/cpa-ui-script.test.sh
tests/docs-i18n.test.sh
tests/git-branching-policy.test.sh
tests/release-deploy.test.sh
tests/backup-cron.test.sh
tests/storage-retention.test.sh
tests/env-template-sync.test.sh
tests/new-api-small-circle-launch.test.sh
tests/ci-cd-pipeline.test.sh
tests/local-new-api-e2e.test.sh
tests/formal-release.test.sh
config/ops-profiles/glm-default.example.json
config/ops-profiles/glm-default-health.example.json
package.json
playwright.config.ts
e2e/new-api-smoke.spec.ts
e2e/new-api-admin-users.spec.ts
vendor/new-api/README.md
vendor/cli-proxy-api/docker-compose.yml
vendor/cli-proxy-api/config.example.yaml
EOF

while IFS= read -r path; do
  [ -n "$path" ] && assert_dir "$path"
done <<'EOF'
.github/workflows
docs
docs/zh-CN
ops
public
vendor/new-api
vendor/cli-proxy-api
.specify
.agents/skills
EOF

while IFS= read -r path; do
  [ -n "$path" ] && assert_not_file "$path"
done <<'EOF'
scripts/verify-repo.ps1
docker-compose.kuma.ui.yml
docker-compose.ops-dashboard.yml
Caddyfile.status.example
docs/kuma-status-runbook.md
ops/offsite-backup.sh
ops/production-monitor.sh
ops/ops-health-report.sh
ops/kuma-ui.sh
ops/ops-dashboard.sh
tests/production-monitor.test.sh
tests/ops-health-report.test.sh
tests/kuma-ui-script.test.sh
tests/ops-dashboard.test.sh
e2e/kuma-status.spec.ts
config/ops-profiles/glm-standard.example.json
config/ops-profiles/glm-standard-health.example.json
Caddyfile.cpa-quota
ops/cpa-quota-snapshot.sh
tests/cpa-quota-snapshot.test.sh
public/cpa-quota/widget.html
EOF

assert_contains ".gitmodules" "lihan3238/new-api" "New API submodule"
assert_contains ".gitmodules" "router-for-me/CLIProxyAPI" "CLIProxyAPI submodule"
assert_contains "docker-compose.yml" "calciumion/new-api" "New API image"
assert_contains "docker-compose.yml" "postgres" "PostgreSQL service"
assert_contains "docker-compose.yml" "redis" "Redis service"
assert_contains "docker-compose.yml" "caddy" "HTTPS reverse proxy"
assert_not_contains "docker-compose.yml" "uptime-kuma" "removed monitoring service"
assert_contains "docker-compose.dev.yml" "NEW_API_DEV_PORT" "development port override"
assert_contains "docker-compose.prod.yml" "max-size" "production log rotation"
assert_contains "docker-compose.prod.yml" "command:[[:space:]]*--log-dir=" "production disables duplicate New API file logs"
assert_contains "docker-compose.edge.yml" "relay-edge-caddy" "edge Caddy service"
assert_contains "docker-compose.cpa.yml" "relay-cpa" "CPA internal service"
assert_not_contains "docker-compose.cpa.yml" "cpa-quota-static" "removed CPA quota static service"
assert_not_contains "docker-compose.cpa.yml" "CPA_PUBLIC_PATH" "removed CPA public quota snapshot path"
assert_contains "docker-compose.cpa.yml" "max-size:[[:space:]]*\"20m\"" "CPA Docker log max-size"
assert_contains "docker-compose.cpa.yml" "max-file:[[:space:]]*\"5\"" "CPA Docker log max-file"
assert_contains "docker-compose.cpa.ui.yml" "127.0.0.1" "CPA UI localhost bind"
assert_contains "docker-compose.cloudflare-tunnel.yml" "relay-cloudflared" "Cloudflare Tunnel service"
assert_contains "docker-compose.cloudflare-tunnel.yml" "cloudflare/cloudflared" "official cloudflared image"
assert_not_contains "Caddyfile" "cpa-quota-static" "removed public CPA quota upstream"
assert_not_contains "Caddyfile" "/cpa-quota" "removed public CPA quota route"
assert_contains "Caddyfile.edge.example" "ORIGIN_UPSTREAM" "edge origin upstream"

assert_contains ".env.example" "CHANGE_ME" "placeholder secrets"
assert_contains ".env.example" "CONFIG_SNAPSHOT_KEEP=30" "config snapshot retention"
assert_not_contains ".env.example" "STATUS_DOMAIN=" "removed status domain variable"
assert_not_contains ".env.example" "KUMA_PORT=" "removed Kuma port variable"
assert_not_contains ".env.example" "RESTIC_" "removed restic variables"
assert_not_contains ".env.example" "sk-[A-Za-z0-9]" "real-looking API keys"
assert_contains ".env.production.example" "DEPLOY_ENV=production" "production env template"
assert_contains ".env.production.example" "DEPLOY_ROOT=/opt/lihan_ai_deploy" "release deploy root"
assert_contains ".env.production.example" "DEPLOY_COMPOSE_PROJECT=lihan_ai" "fixed release compose project"
assert_contains ".env.production.example" "DEPLOY_INCLUDE_CPA=0" "optional CPA toggle"
assert_not_contains ".env.production.example" "CPA_PUBLIC_PATH" "removed CPA public quota snapshot path"
assert_contains ".env.production.example" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0" "optional tunnel toggle"
assert_contains ".env.production.example" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0" "optional local build toggle"
assert_not_contains ".env.production.example" "RESTIC_" "removed restic variables"
assert_not_contains ".env.production.example" "MONITOR_" "removed monitor variables"
assert_not_contains ".env.production.example" "OPS_DASHBOARD" "removed ops dashboard variables"

assert_contains "README.md" "README.zh-CN.md" "Chinese README link"
assert_contains "README.md" "ops/dev-gate\\.sh" "README dev gate"
assert_contains "README.md" "ops/relayctl\\.sh" "README formal operations"
assert_contains "README.md" "new-api-small-circle-launch-runbook\\.md" "small circle launch runbook"
assert_contains "README.md" "vendor/cli-proxy-api" "CLIProxyAPI submodule guidance"
assert_contains "README.md" "GitHub Actions PR CI" "CI guidance"
assert_contains "README.zh-CN.md" "ops/dev-gate\\.sh" "Chinese README dev gate"
assert_contains "README.zh-CN.md" "ops/relayctl\\.sh" "Chinese README formal operations"
assert_contains "README.zh-CN.md" "GitHub Actions PR CI" "Chinese CI guidance"

assert_contains "docs/i18n-map.md" "docs/cpa-runbook.md" "CPA i18n map"
assert_contains "docs/development-workflow.md" "scripts/verify-repo\\.sh --skip-docker" "shell verifier docs"
assert_not_contains "docs/development-workflow.md" "verify-repo\\.ps1" "old PowerShell verifier docs"
assert_contains "docs/cloudflare-saas-runbook.md" "api.lihan3238.com" "Cloudflare SaaS public hostname"
assert_contains "docs/cloudflare-saas-runbook.md" "origin.lihan3238.top" "Cloudflare SaaS fallback origin"
assert_not_contains "docs/cloudflare-saas-runbook.md" "cpa-quota-static" "removed Cloudflare Tunnel CPA quota static route"
assert_not_contains "docs/cloudflare-saas-runbook.md" "/cpa-quota" "removed Cloudflare Tunnel CPA quota path"
assert_contains "docs/edge-proxy-runbook.md" "ORIGIN_UPSTREAM" "edge upstream variable"
assert_contains "docs/cpa-runbook.md" "ssh -L 8317" "CPA SSH tunnel"
assert_contains "docs/cpa-runbook.md" "logs-max-total-size-mb" "CPA file log cap"
assert_contains "docs/cpa-runbook.md" "error-logs-max-files" "CPA error log cap"
assert_not_contains "docs/cpa-runbook.md" "ops/cpa-quota-snapshot\\.sh" "removed CPA quota snapshot command"
assert_not_contains "docs/cpa-runbook.md" "cpa-quota/widget\\.html" "removed CPA quota widget URL"
assert_not_contains "docs/cpa-runbook.md" "cpa-quota-static" "removed CPA quota static docs"
assert_not_contains "docs/zh-CN/cpa-runbook.md" "ops/cpa-quota-snapshot\\.sh" "removed Chinese CPA quota snapshot command"
assert_not_contains "docs/zh-CN/cpa-runbook.md" "cpa-quota/widget\\.html" "removed Chinese CPA quota widget URL"
assert_not_contains "docs/zh-CN/cpa-runbook.md" "cpa-quota-static" "removed Chinese CPA quota static docs"
assert_contains "docs/new-api-code-map.md" "New API" "upstream feature map"
assert_contains "docs/new-api-full-research.md" "BillingSession" "billing research"
assert_contains "docs/browser-e2e-runbook.md" "NEW_API_BASE_URL" "browser E2E New API URL"
assert_contains "docs/git-branching-runbook.md" "main = production" "branch policy"
assert_contains "docs/zh-CN/git-branching-runbook.md" "main = production" "Chinese branch policy"

assert_contains "ops/dev-gate.sh" "scripts/verify-repo\\.sh --skip-docker" "dev gate shell verifier"
assert_not_contains "ops/dev-gate.sh" "powershell|pwsh|verify-repo\\.ps1" "dev gate PowerShell verifier"
assert_not_contains "ops/production-gate.sh" "tests/cpa-quota-snapshot.test.sh" "removed CPA quota snapshot gate test"
assert_not_contains "ops/production-gate.sh" "ops/cpa-quota-snapshot.sh" "removed CPA quota snapshot shell check"
assert_not_contains "ops/deploy-release.sh" "shared_dir/data/cpa/public" "removed release shared CPA public quota dir"
assert_contains "ops/deploy-release.sh" "shared_dir/data/cpa" "release shared CPA data dir"
assert_contains "ops/deploy-release.sh" "docker compose -p" "fixed release compose project"
assert_contains "ops/verify-remote-prod.sh" "/opt/lihan_ai_deploy/current" "remote verifier release path"
assert_contains "ops/check-production-runtime.sh" "relay-cloudflared" "runtime Cloudflare Tunnel check"
assert_contains "ops/preflight.sh" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD" "preflight local New API build toggle"
assert_contains "ops/cpa-ui.sh" "--no-deps" "CPA UI helper only recreates CPA"
assert_contains "ops/sync-cpa-upstream-assets.sh" "submodule update --init --remote vendor/cli-proxy-api" "CPA submodule sync"

assert_contains ".github/workflows/ci.yml" "pull_request:" "CI pull request trigger"
assert_contains ".github/workflows/ci.yml" "submodules: recursive" "CI checks out submodules"
assert_contains ".github/workflows/ci.yml" "tests/\\*\\.test\\.sh" "CI runs shell tests"
assert_contains ".github/workflows/ci.yml" "scripts/verify-repo\\.sh --skip-docker" "CI runs shell verifier"
assert_not_contains ".github/workflows/ci.yml" "verify-repo\\.ps1|pwsh|powershell" "CI old PowerShell verifier"
assert_not_contains ".github/workflows/ci.yml" "PROD_DEPLOY_" "CI must not read production secrets"
assert_not_contains ".github/workflows/ci.yml" "npm run e2e" "CI must not run browser E2E"
assert_contains ".github/workflows/cd.yml" "post-merge validation" "CD post-merge validation"
assert_contains ".github/workflows/cd.yml" "ops/dev-gate\\.sh" "CD runs dev gate"
assert_not_contains ".github/workflows/cd.yml" "deploy-release\\.sh" "CD must not deploy production"

assert_contains "package.json" "e2e:web:new-api-admin" "admin frontend Playwright script"
assert_contains "e2e/new-api-admin-users.spec.ts" "Manage Bindings" "admin users E2E bindings"
assert_contains "e2e/new-api-admin-users.spec.ts" "Manage Subscriptions" "admin users E2E subscriptions"
assert_contains "config/ops-profiles/glm-default.example.json" '"group": "default"' "default profile group"
assert_not_contains "config/ops-profiles/glm-default.example.json" "standard" "old profile group"
assert_contains ".gitignore" "snapshots/" "configuration snapshots ignored"
assert_contains ".gitignore" "docs/ai-dev/" "local AI notes ignored"

while IFS= read -r path; do
  [ -n "$path" ] || continue
  assert_not_contains "$path" "Uptime Kuma|kuma-status|production-monitor|ops-dashboard|ops-health|offsite-backup|RESTIC_|restic snapshots|MONITOR_PUSH|MONITOR_ALERT" "removed monitoring/offsite operations"
done <<'EOF'
README.md
README.zh-CN.md
docs/backup-strategy.md
docs/zh-CN/backup-strategy.md
docs/disaster-recovery-runbook.md
docs/zh-CN/disaster-recovery-runbook.md
docs/operations-runbook.md
docs/zh-CN/operations-runbook.md
docs/ops-quick-reference.md
docs/zh-CN/ops-quick-reference.md
docs/release-deployment-runbook.md
docs/zh-CN/release-deployment-runbook.md
docs/production-deployment-runbook.md
docs/zh-CN/production-deployment-runbook.md
docs/cpa-runbook.md
docs/zh-CN/cpa-runbook.md
docs/edge-proxy-runbook.md
docs/zh-CN/edge-proxy-runbook.md
EOF

if [ "$skip_docker" -ne 1 ] && command -v docker >/dev/null 2>&1; then
  cd "$ROOT_DIR"
  docker compose --env-file .env.example config >/dev/null
  docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.prod.yml config >/dev/null
  docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml config >/dev/null
  docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cloudflare-tunnel.yml config >/dev/null
  docker compose --env-file .env.production.example -f docker-compose.edge.yml config >/dev/null
fi

echo "Repository verification passed."
