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

assert_executable() {
  [ -x "$ROOT_DIR/$1" ] || fail "missing executable: $1"
  if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mode="$(git -C "$ROOT_DIR" ls-files -s -- "$1" | awk '{print $1}')"
    [ "$mode" = "100755" ] || fail "not executable in git index: $1 ($mode)"
  fi
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

assert_file "docker-compose.local-build.yml"
assert_file "docker-compose.prod.yml"
assert_file "docker-compose.edge.yml"
assert_file "docker-compose.cpa.yml"
assert_file "docker-compose.cpa.ui.yml"
assert_file "docker-compose.cloudflare-tunnel.yml"
assert_not_file "docker-compose.kuma.ui.yml"
assert_not_file "docker-compose.ops-dashboard.yml"
assert_file ".github/pull_request_template.md"
assert_contains ".gitmodules" "lihan3238/new-api"
assert_not_file "Caddyfile.status.example"
assert_file "Caddyfile.edge.example"
assert_file ".env.production.example"

assert_executable "ops/backup-cron.sh"
assert_executable "ops/dev-gate.sh"
assert_executable "ops/feature-completion-check.sh"
assert_executable "ops/prune-runtime-storage.sh"
assert_executable "ops/sync-env-template.sh"
assert_executable "ops/build-local-new-api.sh"
assert_executable "ops/start-local-new-api.sh"
assert_executable "ops/export-config-snapshot.sh"
assert_executable "ops/drill-restore-postgres.sh"
assert_executable "ops/drill-restore-stack.sh"
assert_executable "ops/production-gate.sh"
assert_executable "ops/validate-ops-profile.sh"
assert_executable "ops/channel-health-advisor.sh"
assert_executable "ops/live-e2e-billing-from-db-token.sh"
assert_executable "ops/check-local-ports.sh"
assert_executable "ops/bootstrap-server.sh"
assert_executable "ops/deploy-prod.sh"
assert_executable "ops/deploy-release.sh"
assert_executable "ops/verify-remote-prod.sh"
assert_executable "ops/migration-preflight.sh"
assert_executable "ops/migrate-prod.sh"
assert_executable "ops/check-production-runtime.sh"
assert_executable "ops/sync-cpa-upstream-assets.sh"
assert_executable "ops/cpa-ui.sh"
assert_executable "ops/check-new-api-admin-frontend.sh"
assert_not_file "ops/offsite-backup.sh"
assert_not_file "ops/production-monitor.sh"
assert_not_file "ops/ops-health-report.sh"
assert_not_file "ops/kuma-ui.sh"
assert_not_file "ops/ops-dashboard.sh"

assert_executable "tests/backup-cron.test.sh"
assert_executable "tests/dev-gate.test.sh"
assert_executable "tests/feature-completion-check.test.sh"
assert_executable "tests/storage-retention.test.sh"
assert_executable "tests/env-template-sync.test.sh"
assert_executable "tests/ops-profile.test.sh"
assert_executable "tests/channel-health-advisor.test.sh"
assert_executable "tests/live-e2e-token-wrapper.test.sh"
assert_executable "tests/check-local-ports.test.sh"
assert_executable "tests/browser-e2e-scaffold.test.sh"
assert_file "tests/github-actions-ci.test.sh"
assert_file "tests/cloudflare-saas-domain.test.sh"
assert_file "tests/cloudflare-tunnel-compose.test.sh"
assert_executable "tests/prod-deploy-migration.test.sh"
assert_executable "tests/prod-deploy-hardening.test.sh"
assert_executable "tests/cpa-compose.test.sh"
assert_executable "tests/cpa-ui-script.test.sh"
assert_executable "tests/new-api-small-circle-launch.test.sh"
assert_not_file "tests/production-monitor.test.sh"
assert_not_file "tests/ops-health-report.test.sh"
assert_not_file "tests/kuma-ui-script.test.sh"
assert_not_file "tests/ops-dashboard.test.sh"

assert_file "README.zh-CN.md"
assert_file "docs/i18n-map.md"
assert_file "docs/development-workflow.md"
assert_file "docs/wrapper-infra-runbook.md"
assert_not_file "docs/kuma-status-runbook.md"
assert_file "docs/production-deployment-runbook.md"
assert_file "docs/release-deployment-runbook.md"
assert_file "docs/cloudflare-saas-runbook.md"
assert_file "docs/edge-proxy-runbook.md"
assert_file "docs/migration-runbook.md"
assert_file "docs/disaster-recovery-runbook.md"
assert_file "docs/git-branching-runbook.md"
assert_file "docs/cpa-runbook.md"
assert_file "docs/zh-CN/production-deployment-runbook.md"
assert_file "docs/zh-CN/release-deployment-runbook.md"
assert_file "docs/zh-CN/cloudflare-saas-runbook.md"
assert_file "docs/zh-CN/edge-proxy-runbook.md"
assert_file "docs/zh-CN/migration-runbook.md"
assert_file "docs/zh-CN/disaster-recovery-runbook.md"
assert_file "docs/zh-CN/git-branching-runbook.md"
assert_file "docs/zh-CN/cpa-runbook.md"
assert_file "docs/zh-CN/backup-strategy.md"
assert_file "docs/zh-CN/operations-runbook.md"
assert_file "docs/ops-quick-reference.md"
assert_file "docs/zh-CN/ops-quick-reference.md"
assert_file "docs/zh-CN/server-buying-guide.md"
assert_file "docs/new-api-small-circle-launch-runbook.md"
assert_file "docs/zh-CN/new-api-small-circle-launch-runbook.md"
assert_file "config/ops-profiles/glm-default.example.json"
assert_file "config/ops-profiles/glm-default-health.example.json"
assert_not_file "config/ops-profiles/glm-standard.example.json"
assert_not_file "config/ops-profiles/glm-standard-health.example.json"

assert_contains ".gitignore" "^snapshots/$"
assert_contains ".env.example" "LOCAL_NEW_API_IMAGE="
assert_contains ".env.example" "CONFIG_SNAPSHOT_DIR="
assert_contains ".env.example" "CONFIG_SNAPSHOT_KEEP=30"
assert_contains ".env.example" "CONFIG_SNAPSHOT_MAX_TOTAL_MB=256"
assert_contains ".env.example" "CONFIG_SNAPSHOT_GPG_RECIPIENT="
assert_contains ".env.example" "BACKUP_KEEP=30"
assert_contains ".env.example" "BACKUP_MAX_TOTAL_MB=2048"
assert_contains ".env.example" "BACKUP_CRON_LOG_MAX_MB=10"
assert_contains ".env.example" "BACKUP_CRON_LOG_KEEP=5"
assert_contains ".env.example" "NEW_API_DEV_PORT=3100"
assert_not_contains ".env.example" "STATUS_DOMAIN="
assert_not_contains ".env.example" "KUMA_PORT="
assert_not_contains ".env.example" "RESTIC_"
assert_contains ".env.production.example" "DEPLOY_ENV=production"
assert_contains ".env.production.example" "CLOUDFLARE_SAAS_FALLBACK_ORIGIN="
assert_contains ".env.production.example" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0"
assert_contains ".env.production.example" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0"
assert_contains ".env.production.example" "DEPLOY_LOCAL_NEW_API_BUILD_MODE=build"
assert_contains ".env.production.example" "BACKUP_CRON_LOG_DIR="
assert_contains ".env.production.example" "BACKUP_KEEP=30"
assert_contains ".env.production.example" "BACKUP_MAX_TOTAL_MB=2048"
assert_contains ".env.production.example" "BACKUP_CRON_LOG_MAX_MB=10"
assert_contains ".env.production.example" "BACKUP_CRON_LOG_KEEP=5"
assert_contains ".env.production.example" "CONFIG_SNAPSHOT_KEEP=30"
assert_contains ".env.production.example" "CONFIG_SNAPSHOT_MAX_TOTAL_MB=256"
assert_not_contains ".env.production.example" "MONITOR_"
assert_not_contains ".env.production.example" "OPS_HEALTH_"
assert_not_contains ".env.production.example" "OPS_DASHBOARD"
assert_not_contains ".env.production.example" "RESTIC_"

assert_contains "README.md" "README.zh-CN.md"
assert_contains "README.zh-CN.md" "DEPLOY_HOST="
assert_contains "README.md" "ops/dev-gate.sh"
assert_contains "README.md" "E2E Coverage Matrix"
assert_contains "README.md" "new-api-small-circle-launch-runbook.md"
assert_contains "README.zh-CN.md" "ops/dev-gate.sh"
assert_contains "README.zh-CN.md" "E2E Coverage Matrix"
assert_contains "README.zh-CN.md" "new-api-small-circle-launch-runbook.md"
assert_contains "docs/i18n-map.md" "docs/zh-CN/production-deployment-runbook.md"
assert_contains "docs/i18n-map.md" "docs/zh-CN/release-deployment-runbook.md"
assert_contains "docs/i18n-map.md" "docs/zh-CN/new-api-small-circle-launch-runbook.md"
assert_contains "docs/git-branching-runbook.md" "main = production"
assert_contains "docs/zh-CN/git-branching-runbook.md" "main = production"
assert_contains "docker-compose.prod.yml" "max-size"
assert_contains "docker-compose.prod.yml" "command: --log-dir="
assert_contains "docker-compose.edge.yml" "relay-edge-caddy"
assert_contains "docker-compose.cpa.yml" "relay-cpa"
assert_contains "docker-compose.cpa.yml" "max-size: \"20m\""
assert_contains "docker-compose.cpa.yml" "max-file: \"5\""
assert_contains "docker-compose.cpa.ui.yml" "127.0.0.1"
assert_contains "docker-compose.cloudflare-tunnel.yml" "relay-cloudflared"
assert_not_contains "docker-compose.yml" "uptime-kuma"
assert_contains "Caddyfile.edge.example" "ORIGIN_UPSTREAM"
assert_contains "docker-compose.local-build.yml" "vendor/new-api"
assert_contains "docker-compose.local-build.yml" "LOCAL_NEW_API_IMAGE"
assert_contains "ops/deploy-release.sh" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD"
assert_contains "ops/deploy-release.sh" "DEPLOY_LOCAL_NEW_API_BUILD_MODE"
assert_contains "ops/check-production-runtime.sh" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD"
assert_contains "ops/check-production-runtime.sh" "new-api image"
assert_contains "ops/preflight.sh" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD"
assert_contains "ops/preflight.sh" "DEPLOY_LOCAL_NEW_API_BUILD_MODE"
assert_contains "ops/preflight.sh" "LOCAL_NEW_API_IMAGE must differ from NEW_API_IMAGE"
assert_contains "docs/development-workflow.md" "Research Gate"
assert_contains "docs/development-workflow.md" "Layered E2E Policy"
assert_contains "docs/development-workflow.md" "ops/dev-gate.sh"
assert_contains "docs/development-workflow.md" "Reason:"
assert_contains "docs/development-workflow.md" "Rerun:"
assert_contains "docs/wrapper-infra-runbook.md" "ops/dev-gate.sh"
assert_contains "docs/wrapper-infra-runbook.md" "feature-completion-check.sh"
assert_contains "docs/wrapper-infra-runbook.md" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1"
assert_contains "docs/browser-e2e-runbook.md" "e2e:web:new-api-admin"
assert_contains "docs/new-api-small-circle-launch-runbook.md" "station quota"
assert_contains "docs/new-api-small-circle-launch-runbook.md" "#4787"
assert_contains "docs/zh-CN/new-api-small-circle-launch-runbook.md" "station quota"
assert_contains "docs/zh-CN/new-api-small-circle-launch-runbook.md" "#4787"
assert_contains "docs/templates/ai-dev/spec.md" "User Acceptance Path"
assert_contains "docs/templates/ai-dev/plan.md" "E2E Coverage Matrix"
assert_contains "docs/templates/ai-dev/plan.md" "Documentation Impact"
assert_contains "docs/templates/ai-dev/plan.md" "Usage/Test Guide"
assert_contains "docs/templates/ai-dev/handoff.md" "How To Use And Test"
assert_contains "docs/templates/ai-dev/handoff.md" "E2E Results"
assert_contains "docs/templates/ai-dev/handoff.md" "Documentation Updated"
assert_contains "docs/templates/ai-dev/handoff.md" "Residual Risk"
assert_contains "docs/templates/ai-dev/tasks.md" "ops/dev-gate.sh"
assert_contains ".github/pull_request_template.md" "E2E Coverage"
assert_contains ".github/pull_request_template.md" "Reason:"
assert_contains ".github/pull_request_template.md" "Rerun:"
assert_contains "ops/production-gate.sh" "tests/backup-cron.test.sh"
assert_contains "ops/production-gate.sh" "ops/feature-completion-check.sh"
assert_contains "ops/production-gate.sh" "tests/storage-retention.test.sh"
assert_contains "ops/production-gate.sh" "tests/env-template-sync.test.sh"
assert_contains "ops/production-gate.sh" "AI_DEV_FEATURE_DIR"
assert_contains "ops/production-gate.sh" "OPS_PROFILE_FILE"
assert_contains "ops/production-gate.sh" "OPS_HEALTH_PROFILE_FILE"
assert_contains "ops/production-gate.sh" "tests/prod-deploy-migration.test.sh"
assert_contains "ops/production-gate.sh" "tests/docs-i18n.test.sh"
assert_contains "ops/production-gate.sh" "tests/git-branching-policy.test.sh"
assert_contains "ops/production-gate.sh" "tests/release-deploy.test.sh"
assert_contains "ops/production-gate.sh" "tests/github-actions-ci.test.sh"
assert_contains "ops/production-gate.sh" "tests/cloudflare-saas-domain.test.sh"
assert_contains "ops/production-gate.sh" "tests/cloudflare-tunnel-compose.test.sh"
assert_contains "ops/production-gate.sh" "tests/cpa-ui-script.test.sh"
assert_not_contains "ops/production-gate.sh" "production-monitor.test.sh"
assert_not_contains "ops/production-gate.sh" "ops-health-report.test.sh"
assert_not_contains "ops/production-gate.sh" "kuma-ui-script.test.sh"
assert_not_contains "ops/production-gate.sh" "ops-dashboard.test.sh"
assert_contains ".github/workflows/ci.yml" "pull_request:"
assert_contains ".github/workflows/ci.yml" "verify-repo.ps1 -SkipDocker"
assert_contains ".github/workflows/ci.yml" "docker-compose.cpa.yml"
assert_not_contains ".github/workflows/ci.yml" "docker-compose.kuma.ui.yml"
assert_not_contains ".github/workflows/ci.yml" "docker-compose.ops-dashboard.yml"
assert_contains "ops/live-e2e-billing-from-db-token.sh" "NEW_API_TEST_TOKEN_NAME"
assert_not_contains "ops/check-local-ports.sh" "KUMA_PORT"
assert_contains "ops/check-production-runtime.sh" "caddy port 443"
assert_contains "ops/check-production-runtime.sh" "relay-cloudflared"
assert_contains "ops/sync-cpa-upstream-assets.sh" "CLIProxyAPI/main/config.example.yaml"
assert_contains "docs/release-deployment-runbook.md" "deploy-release.sh"
assert_contains "docs/release-deployment-runbook.md" "/opt/lihan_ai_deploy"
assert_contains "docs/release-deployment-runbook.md" "promote.state"
assert_contains "docs/release-deployment-runbook.md" "last_healthy"
assert_contains "docs/release-deployment-runbook.md" "ops/deploy-release.sh status"
assert_contains "docs/release-deployment-runbook.md" "ops/deploy-release.sh recover"
assert_contains "docs/zh-CN/release-deployment-runbook.md" "/opt/lihan_ai_deploy"
assert_contains "docs/zh-CN/release-deployment-runbook.md" "promote.state"
assert_contains "docs/zh-CN/release-deployment-runbook.md" "last_healthy"
assert_contains "docs/ops-quick-reference.md" "Daily Quick Check"
assert_contains "docs/ops-quick-reference.md" "ops/backup-cron.sh"
assert_contains "docs/ops-quick-reference.md" "ops/prune-runtime-storage.sh"
assert_contains "docs/ops-quick-reference.md" "ops/deploy-release.sh promote"
assert_contains "docs/ops-quick-reference.md" "ops/deploy-release.sh status"
assert_contains "docs/ops-quick-reference.md" "ops/deploy-release.sh recover"
assert_contains "docs/ops-quick-reference.md" "scp"
assert_contains "docs/ops-quick-reference.md" "restore-postgres.sh"
assert_contains "docs/zh-CN/ops-quick-reference.md" "ops/backup-cron.sh"
assert_contains "docs/zh-CN/ops-quick-reference.md" "ops/prune-runtime-storage.sh"
assert_contains "docs/zh-CN/ops-quick-reference.md" "ops/deploy-release.sh promote"
assert_contains "docs/zh-CN/ops-quick-reference.md" "ops/deploy-release.sh status"
assert_contains "docs/zh-CN/ops-quick-reference.md" "ops/deploy-release.sh recover"
assert_contains "docs/zh-CN/ops-quick-reference.md" "scp"
assert_contains "docs/zh-CN/ops-quick-reference.md" "restore-postgres.sh"
assert_contains "docs/cloudflare-saas-runbook.md" "api.lihan3238.com"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "api.lihan3238.com"
assert_contains "docs/cpa-runbook.md" "logs-max-total-size-mb"
assert_contains "docs/cpa-runbook.md" "error-logs-max-files"
assert_contains "docs/zh-CN/cpa-runbook.md" "logs-max-total-size-mb"
assert_contains "docs/zh-CN/cpa-runbook.md" "error-logs-max-files"

test_tmp="$(mktemp -d)"
trap 'rm -rf "$test_tmp"' EXIT
test_env="$test_tmp/.env"
cat > "$test_env" <<'EOF'
POSTGRES_USER=newapi
POSTGRES_DB=newapi
POSTGRES_PASSWORD=redacted
NEW_API_DEV_PORT=3100
EOF

set +e
private_output="$(CONFIG_SNAPSHOT_GPG_RECIPIENT= ENV_FILE="$test_env" "$ROOT_DIR/ops/export-config-snapshot.sh" --private 2>&1)"
private_status="$?"
set -e
[ "$private_status" -eq 2 ] || fail "expected private snapshot exit 2 without recipient, got $private_status: $private_output"
printf '%s' "$private_output" | grep -q "CONFIG_SNAPSHOT_GPG_RECIPIENT is not set" || fail "missing private snapshot recipient message"

fake_bin="$test_tmp/bin"
tmp_out="$test_tmp/snapshots"
mkdir -p "$fake_bin" "$tmp_out"

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
if [ "$1" = "compose" ] && [ "$2" = "--env-file" ]; then
  cat <<'JSON'
{
  "snapshot_kind": "redacted",
  "generated_at": "2026-05-08T00:00:00Z",
  "database": "newapi",
  "data": {
    "channels": [
      {
        "id": 1,
        "name": "official",
        "type": 14,
        "status": 1,
        "models": "glm-5.1",
        "base_url": "https://example.invalid",
        "key_fingerprint": "sha256:abcd1234",
        "key_length": 96,
        "used_quota": 123
      }
    ],
    "tokens": [
      {
        "id": 1,
        "user_id": 1,
        "status": 1,
        "name": "test",
        "key_fingerprint": "sha256:ef567890",
        "key_length": 48,
        "remain_quota": 10,
        "used_quota": 20
      }
    ]
  }
}
JSON
  exit 0
fi
echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

snapshot_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$test_env" CONFIG_SNAPSHOT_DIR="$tmp_out" "$ROOT_DIR/ops/export-config-snapshot.sh")"
[ -f "$snapshot_output" ] || fail "snapshot output not found: $snapshot_output"
grep -q '"snapshot_kind": "redacted"' "$snapshot_output" || fail "snapshot missing redacted kind"
grep -q '"key_fingerprint"' "$snapshot_output" || fail "snapshot missing key fingerprint"
if grep -Eiq 'sk-[A-Za-z0-9]|password|SESSION_SECRET|POSTGRES_PASSWORD|REDIS_PASSWORD' "$snapshot_output"; then
  fail "redacted snapshot contains forbidden secret-looking content"
fi

set +e
gate_output="$(env -u NEW_API_TEST_TOKEN "$ROOT_DIR/ops/production-gate.sh" 2>&1)"
gate_status="$?"
set -e
[ "$gate_status" -eq 2 ] || fail "expected production gate exit 2 without token, got $gate_status: $gate_output"
printf '%s' "$gate_output" | grep -q "NEW_API_TEST_TOKEN is not set" || fail "missing production gate token message"

echo "wrapper-infra tests passed"
