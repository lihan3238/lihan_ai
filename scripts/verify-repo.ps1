param(
    [switch]$SkipDocker
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Assert-File {
    param([string]$Path)
    $full = Join-Path $root $Path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Missing required file: $Path"
    }
}

function Assert-NotFile {
    param([string]$Path)
    $full = Join-Path $root $Path
    if (Test-Path -LiteralPath $full -PathType Leaf) {
        throw "Removed file is still present: $Path"
    }
}

function Assert-Directory {
    param([string]$Path)
    $full = Join-Path $root $Path
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw "Missing required directory: $Path"
    }
}

function Assert-Contains {
    param([string]$Path, [string]$Pattern, [string]$Description)
    $full = Join-Path $root $Path
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $full
    if ($content -notmatch $Pattern) {
        throw "$Path does not contain required content: $Description"
    }
}

function Assert-NotContains {
    param([string]$Path, [string]$Pattern, [string]$Description)
    $full = Join-Path $root $Path
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $full
    if ($content -match $Pattern) {
        throw "$Path contains forbidden content: $Description"
    }
}

Assert-File "README.md"
Assert-File "README.zh-CN.md"
Assert-File "docker-compose.yml"
Assert-File "docker-compose.dev.yml"
Assert-File "docker-compose.prod.yml"
Assert-File "docker-compose.edge.yml"
Assert-File "docker-compose.cpa.yml"
Assert-File "docker-compose.cpa.ui.yml"
Assert-File "docker-compose.cloudflare-tunnel.yml"
Assert-File ".env.example"
Assert-File ".env.production.example"
Assert-File ".gitmodules"
Assert-Contains ".gitmodules" "lihan3238/new-api" "temporary New API fork submodule"
Assert-File "Caddyfile"
Assert-File "Caddyfile.edge.example"
Assert-File ".gitignore"
Assert-File "AGENTS.md"
Assert-Directory ".github/workflows"
Assert-File ".github/pull_request_template.md"
Assert-Directory "docs"
Assert-Directory "docs/zh-CN"
Assert-Directory "ops"
Assert-Directory "vendor/new-api"
Assert-Directory "vendor/cli-proxy-api"
Assert-Directory ".specify"
Assert-Directory ".agents/skills"

Assert-File "docs/operations-runbook.md"
Assert-File "docs/new-api-code-map.md"
Assert-File "docs/new-api-full-research.md"
Assert-File "docs/local-development-state.md"
Assert-File "docs/backup-strategy.md"
Assert-File "docs/server-buying-guide.md"
Assert-File "docs/development-workflow.md"
Assert-File "docs/spec-kit-integration-runbook.md"
Assert-File "docs/wrapper-infra-runbook.md"
Assert-File "docs/browser-e2e-runbook.md"
Assert-File "docs/production-deployment-runbook.md"
Assert-File "docs/release-deployment-runbook.md"
Assert-File "docs/cloudflare-saas-runbook.md"
Assert-File "docs/edge-proxy-runbook.md"
Assert-File "docs/migration-runbook.md"
Assert-File "docs/disaster-recovery-runbook.md"
Assert-File "docs/git-branching-runbook.md"
Assert-File "docs/cpa-runbook.md"
Assert-File "docs/i18n-map.md"
Assert-File "docs/ops-quick-reference.md"
Assert-File "docs/zh-CN/production-deployment-runbook.md"
Assert-File "docs/zh-CN/release-deployment-runbook.md"
Assert-File "docs/zh-CN/cloudflare-saas-runbook.md"
Assert-File "docs/zh-CN/edge-proxy-runbook.md"
Assert-File "docs/zh-CN/migration-runbook.md"
Assert-File "docs/zh-CN/disaster-recovery-runbook.md"
Assert-File "docs/zh-CN/git-branching-runbook.md"
Assert-File "docs/zh-CN/cpa-runbook.md"
Assert-File "docs/zh-CN/backup-strategy.md"
Assert-File "docs/zh-CN/operations-runbook.md"
Assert-File "docs/zh-CN/ops-quick-reference.md"
Assert-File "docs/zh-CN/server-buying-guide.md"
Assert-File "docs/new-api-small-circle-launch-runbook.md"
Assert-File "docs/zh-CN/new-api-small-circle-launch-runbook.md"

Assert-File "ops/preflight.sh"
Assert-File "ops/dev-gate.sh"
Assert-File "ops/feature-completion-check.sh"
Assert-File "ops/backup-postgres.sh"
Assert-File "ops/backup-cron.sh"
Assert-File "ops/prune-runtime-storage.sh"
Assert-File "ops/verify-postgres-backup.sh"
Assert-File "ops/restore-postgres.sh"
Assert-File "ops/e2e-api-billing.sh"
Assert-File "ops/build-local-new-api.sh"
Assert-File "ops/start-local-new-api.sh"
Assert-File "ops/export-config-snapshot.sh"
Assert-File "ops/drill-restore-postgres.sh"
Assert-File "ops/drill-restore-stack.sh"
Assert-File "ops/production-gate.sh"
Assert-File "ops/ai-dev-check.sh"
Assert-File "ops/validate-ops-profile.sh"
Assert-File "ops/channel-health-advisor.sh"
Assert-File "ops/live-e2e-billing-from-db-token.sh"
Assert-File "ops/check-local-ports.sh"
Assert-File "ops/bootstrap-server.sh"
Assert-File "ops/deploy-prod.sh"
Assert-File "ops/deploy-release.sh"
Assert-File "ops/verify-remote-prod.sh"
Assert-File "ops/migration-preflight.sh"
Assert-File "ops/migrate-prod.sh"
Assert-File "ops/check-production-runtime.sh"
Assert-File "ops/sync-env-template.sh"
Assert-File "ops/sync-cpa-upstream-assets.sh"
Assert-File "ops/cpa-ui.sh"
Assert-File "ops/check-new-api-admin-frontend.sh"

Assert-File "tests/e2e-api-billing.test.sh"
Assert-File "tests/dev-gate.test.sh"
Assert-File "tests/feature-completion-check.test.sh"
Assert-File "tests/wrapper-infra.test.sh"
Assert-File "tests/ai-dev-check.test.sh"
Assert-File "tests/ops-profile.test.sh"
Assert-File "tests/spec-kit-init.test.sh"
Assert-File "tests/channel-health-advisor.test.sh"
Assert-File "tests/live-e2e-token-wrapper.test.sh"
Assert-File "tests/check-local-ports.test.sh"
Assert-File "tests/browser-e2e-scaffold.test.sh"
Assert-File "tests/github-actions-ci.test.sh"
Assert-File "tests/cloudflare-saas-domain.test.sh"
Assert-File "tests/cloudflare-tunnel-compose.test.sh"
Assert-File "tests/prod-deploy-migration.test.sh"
Assert-File "tests/prod-deploy-hardening.test.sh"
Assert-File "tests/local-new-api-build.test.sh"
Assert-File "tests/cpa-compose.test.sh"
Assert-File "tests/cpa-ui-script.test.sh"
Assert-File "tests/docs-i18n.test.sh"
Assert-File "tests/git-branching-policy.test.sh"
Assert-File "tests/release-deploy.test.sh"
Assert-File "tests/backup-cron.test.sh"
Assert-File "tests/storage-retention.test.sh"
Assert-File "tests/env-template-sync.test.sh"
Assert-File "tests/new-api-small-circle-launch.test.sh"

Assert-File "config/ops-profiles/glm-default.example.json"
Assert-File "config/ops-profiles/glm-default-health.example.json"
Assert-File "package.json"
Assert-File "playwright.config.ts"
Assert-File "e2e/new-api-smoke.spec.ts"
Assert-File "e2e/new-api-admin-users.spec.ts"
Assert-File "vendor/new-api/README.md"
Assert-File "vendor/cli-proxy-api/docker-compose.upstream.yml"
Assert-File "vendor/cli-proxy-api/config.example.yaml"
Assert-File ".github/workflows/ci.yml"

Assert-NotFile "docker-compose.kuma.ui.yml"
Assert-NotFile "docker-compose.ops-dashboard.yml"
Assert-NotFile "Caddyfile.status.example"
Assert-NotFile "docs/kuma-status-runbook.md"
Assert-NotFile "ops/offsite-backup.sh"
Assert-NotFile "ops/production-monitor.sh"
Assert-NotFile "ops/ops-health-report.sh"
Assert-NotFile "ops/kuma-ui.sh"
Assert-NotFile "ops/ops-dashboard.sh"
Assert-NotFile "tests/production-monitor.test.sh"
Assert-NotFile "tests/ops-health-report.test.sh"
Assert-NotFile "tests/kuma-ui-script.test.sh"
Assert-NotFile "tests/ops-dashboard.test.sh"
Assert-NotFile "e2e/kuma-status.spec.ts"
Assert-NotFile "config/ops-profiles/glm-standard.example.json"
Assert-NotFile "config/ops-profiles/glm-standard-health.example.json"

Assert-Contains "docker-compose.yml" "calciumion/new-api" "New API image"
Assert-Contains "docker-compose.yml" "postgres" "PostgreSQL service"
Assert-Contains "docker-compose.yml" "redis" "Redis service"
Assert-Contains "docker-compose.yml" "caddy" "HTTPS reverse proxy"
Assert-NotContains "docker-compose.yml" "uptime-kuma" "removed monitoring service"
Assert-Contains "docker-compose.dev.yml" "NEW_API_DEV_PORT" "development port override"
Assert-Contains "docker-compose.prod.yml" "max-size" "production override configures log rotation"
Assert-Contains "docker-compose.prod.yml" "command:\s*--log-dir=" "production disables duplicate New API file logs"
Assert-Contains "docker-compose.edge.yml" "relay-edge-caddy" "edge Caddy service"
Assert-Contains "docker-compose.cpa.yml" "relay-cpa" "CPA internal service"
Assert-Contains "docker-compose.cpa.yml" "max-size:\s*`"20m`"" "CPA Docker log max-size"
Assert-Contains "docker-compose.cpa.yml" "max-file:\s*`"5`"" "CPA Docker log max-file"
Assert-Contains "docker-compose.cpa.ui.yml" "127.0.0.1" "CPA UI localhost bind"
Assert-Contains "docker-compose.cloudflare-tunnel.yml" "relay-cloudflared" "Cloudflare Tunnel service"
Assert-Contains "docker-compose.cloudflare-tunnel.yml" "cloudflare/cloudflared" "official cloudflared image"
Assert-Contains "Caddyfile.edge.example" "ORIGIN_UPSTREAM" "edge origin upstream"

Assert-Contains ".env.example" "CHANGE_ME" "explicit placeholder secrets"
Assert-Contains ".env.example" "BACKUP_CRON_LOG_DIR=" "local backup cron log directory"
Assert-Contains ".env.example" "BACKUP_KEEP=30" "backup count retention default"
Assert-Contains ".env.example" "BACKUP_MAX_TOTAL_MB=2048" "backup total-size retention default"
Assert-Contains ".env.example" "BACKUP_CRON_LOG_MAX_MB=10" "backup cron log rotation max size"
Assert-Contains ".env.example" "BACKUP_CRON_LOG_KEEP=5" "backup cron log rotation count"
Assert-Contains ".env.example" "CONFIG_SNAPSHOT_KEEP=30" "config snapshot count retention default"
Assert-Contains ".env.example" "CONFIG_SNAPSHOT_MAX_TOTAL_MB=256" "config snapshot total-size retention default"
Assert-NotContains ".env.example" "STATUS_DOMAIN=" "removed status domain variable"
Assert-NotContains ".env.example" "KUMA_PORT=" "removed Kuma port variable"
Assert-NotContains ".env.example" "RESTIC_" "removed restic variables"
Assert-Contains ".env.production.example" "DEPLOY_ENV=production" "production env template"
Assert-Contains ".env.production.example" "DEPLOY_ROOT=/opt/lihan_ai_deploy" "release deploy root"
Assert-Contains ".env.production.example" "DEPLOY_COMPOSE_PROJECT=lihan_ai" "fixed release compose project"
Assert-Contains ".env.production.example" "DEPLOY_INCLUDE_CPA=0" "optional CPA release deploy toggle"
Assert-Contains ".env.production.example" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0" "optional Cloudflare Tunnel deploy toggle"
Assert-Contains ".env.production.example" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0" "optional local New API build deploy toggle"
Assert-Contains ".env.production.example" "DEPLOY_LOCAL_NEW_API_BUILD_MODE=build" "local New API build mode default"
Assert-Contains ".env.production.example" "BACKUP_CRON_LOG_DIR=logs" "backup cron log dir"
Assert-Contains ".env.production.example" "BACKUP_KEEP=30" "backup count retention default"
Assert-Contains ".env.production.example" "BACKUP_MAX_TOTAL_MB=2048" "backup total-size retention default"
Assert-Contains ".env.production.example" "BACKUP_CRON_LOG_MAX_MB=10" "backup cron log rotation max size"
Assert-Contains ".env.production.example" "BACKUP_CRON_LOG_KEEP=5" "backup cron log rotation count"
Assert-Contains ".env.production.example" "CONFIG_SNAPSHOT_KEEP=30" "config snapshot count retention default"
Assert-Contains ".env.production.example" "CONFIG_SNAPSHOT_MAX_TOTAL_MB=256" "config snapshot total-size retention default"
Assert-Contains ".env.production.example" "CLOUDFLARE_SAAS_FALLBACK_ORIGIN=" "Cloudflare SaaS fallback origin variable"
Assert-Contains ".env.production.example" "CLOUDFLARE_SAAS_ORIGIN_IP=" "Cloudflare SaaS origin IP variable"
Assert-NotContains ".env.production.example" "RESTIC_" "removed restic variables"
Assert-NotContains ".env.production.example" "MONITOR_" "removed monitor variables"
Assert-NotContains ".env.production.example" "OPS_DASHBOARD" "removed ops dashboard variables"

Assert-Contains "README.md" "README.zh-CN.md" "Chinese README link"
Assert-Contains "README.md" "Local backup cron" "README local backup section"
Assert-Contains "README.md" "ops/backup-cron\.sh" "README backup cron command"
Assert-Contains "README.md" "sync-env-template\.sh" "README env sync guidance"
Assert-Contains "README.md" "ops/dev-gate\.sh" "README dev gate guidance"
Assert-Contains "README.md" "E2E Coverage Matrix" "README E2E matrix guidance"
Assert-Contains "README.md" "new-api-small-circle-launch-runbook\.md" "README small circle launch runbook"
Assert-Contains "README.md" "default" "README default group guidance"
Assert-Contains "README.md" "vip" "README vip group guidance"
Assert-Contains "README.zh-CN.md" "ops/backup-cron\.sh" "Chinese README backup cron command"
Assert-Contains "README.zh-CN.md" "sync-env-template\.sh" "Chinese README env sync guidance"
Assert-Contains "README.zh-CN.md" "ops/dev-gate\.sh" "Chinese README dev gate guidance"
Assert-Contains "README.zh-CN.md" "E2E Coverage Matrix" "Chinese README E2E matrix guidance"
Assert-Contains "README.zh-CN.md" "new-api-small-circle-launch-runbook\.md" "Chinese README small circle launch runbook"
Assert-Contains "README.zh-CN.md" "default" "Chinese README default group guidance"
Assert-Contains "README.zh-CN.md" "vip" "Chinese README vip group guidance"

Assert-Contains "docs/backup-strategy.md" "ops/backup-cron\.sh" "backup cron docs"
Assert-Contains "docs/backup-strategy.md" "ops/prune-runtime-storage\.sh" "runtime storage pruning docs"
Assert-Contains "docs/backup-strategy.md" "BACKUP_KEEP" "backup count retention docs"
Assert-Contains "docs/backup-strategy.md" "BACKUP_MAX_TOTAL_MB" "backup total retention docs"
Assert-Contains "docs/backup-strategy.md" "scp" "manual backup download"
Assert-Contains "docs/backup-strategy.md" "ops/drill-restore-stack\.sh" "restore drill docs"
Assert-Contains "docs/zh-CN/backup-strategy.md" "ops/backup-cron\.sh" "Chinese backup cron docs"
Assert-Contains "docs/zh-CN/backup-strategy.md" "ops/prune-runtime-storage\.sh" "Chinese runtime storage pruning docs"
Assert-Contains "docs/zh-CN/backup-strategy.md" "BACKUP_KEEP" "Chinese backup count retention docs"
Assert-Contains "docs/zh-CN/backup-strategy.md" "BACKUP_MAX_TOTAL_MB" "Chinese backup total retention docs"
Assert-Contains "docs/zh-CN/backup-strategy.md" "scp" "Chinese manual backup download"
Assert-Contains "docs/disaster-recovery-runbook.md" "manually downloaded dump" "manual disaster recovery source"
Assert-Contains "docs/zh-CN/disaster-recovery-runbook.md" "scp" "Chinese manual disaster recovery source"
Assert-Contains "docs/operations-runbook.md" "default" "operations group guidance"
Assert-Contains "docs/operations-runbook.md" "vip" "operations group guidance"
Assert-Contains "docs/operations-runbook.md" "ops/sync-env-template\.sh" "env sync operations guidance"
Assert-Contains "docs/operations-runbook.md" "ops/prune-runtime-storage\.sh" "runtime storage pruning operations guidance"
Assert-Contains "docs/operations-runbook.md" "ops/deploy-release\.sh status" "deploy status operations guidance"
Assert-Contains "docs/operations-runbook.md" "ops/deploy-release\.sh recover" "deploy recover operations guidance"
Assert-Contains "docs/zh-CN/operations-runbook.md" "default" "Chinese operations default group guidance"
Assert-Contains "docs/zh-CN/operations-runbook.md" "vip" "Chinese operations vip group guidance"
Assert-Contains "docs/zh-CN/operations-runbook.md" "ops/prune-runtime-storage\.sh" "Chinese runtime storage pruning operations guidance"
Assert-Contains "docs/zh-CN/operations-runbook.md" "ops/deploy-release\.sh status" "Chinese deploy status operations guidance"
Assert-Contains "docs/zh-CN/operations-runbook.md" "ops/deploy-release\.sh recover" "Chinese deploy recover operations guidance"
Assert-Contains "docs/ops-quick-reference.md" "Daily quick check" "ops quick reference daily checks"
Assert-Contains "docs/ops-quick-reference.md" "ops/backup-cron\.sh" "ops quick reference backup cron"
Assert-Contains "docs/ops-quick-reference.md" "ops/prune-runtime-storage\.sh" "ops quick reference storage prune"
Assert-Contains "docs/ops-quick-reference.md" "ops/deploy-release\.sh status" "ops quick reference deploy status"
Assert-Contains "docs/ops-quick-reference.md" "ops/deploy-release\.sh recover" "ops quick reference deploy recover"
Assert-Contains "docs/ops-quick-reference.md" "Small Circle Launch" "ops quick reference small circle launch"
Assert-Contains "docs/ops-quick-reference.md" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1" "ops quick reference local New API build"
Assert-Contains "docs/ops-quick-reference.md" "DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull" "ops quick reference local New API pull mode"
Assert-Contains "docs/ops-quick-reference.md" "scp" "ops quick reference manual download"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "ops/backup-cron\.sh" "Chinese ops quick reference backup cron"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "ops/prune-runtime-storage\.sh" "Chinese ops quick reference storage prune"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "ops/deploy-release\.sh status" "Chinese ops quick reference deploy status"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "ops/deploy-release\.sh recover" "Chinese ops quick reference deploy recover"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "Small Circle Launch" "Chinese ops quick reference small circle launch"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1" "Chinese ops quick reference local New API build"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull" "Chinese ops quick reference local New API pull mode"
Assert-Contains "docs/zh-CN/ops-quick-reference.md" "scp" "Chinese ops quick reference manual download"

Assert-Contains "docs/release-deployment-runbook.md" "sync-env-template\.sh" "release env sync"
Assert-Contains "docs/release-deployment-runbook.md" "candidate" "release candidate pointer"
Assert-Contains "docs/release-deployment-runbook.md" "promote\.state" "release promote state"
Assert-Contains "docs/release-deployment-runbook.md" "last_healthy" "release last healthy pointer"
Assert-Contains "docs/release-deployment-runbook.md" "ops/deploy-release\.sh status" "release status command"
Assert-Contains "docs/release-deployment-runbook.md" "ops/deploy-release\.sh recover" "release recover command"
Assert-Contains "docs/zh-CN/release-deployment-runbook.md" "sync-env-template\.sh" "Chinese release env sync"
Assert-Contains "docs/zh-CN/release-deployment-runbook.md" "promote\.state" "Chinese release promote state"
Assert-Contains "docs/zh-CN/release-deployment-runbook.md" "last_healthy" "Chinese release last healthy pointer"
Assert-Contains "docs/zh-CN/release-deployment-runbook.md" "ops/deploy-release\.sh status" "Chinese release status command"
Assert-Contains "docs/zh-CN/release-deployment-runbook.md" "ops/deploy-release\.sh recover" "Chinese release recover command"
Assert-Contains "docs/production-deployment-runbook.md" "New API, PostgreSQL, Redis" "production stack"
Assert-Contains "docs/zh-CN/production-deployment-runbook.md" "PostgreSQL" "Chinese production stack"
Assert-Contains "docs/cloudflare-saas-runbook.md" "api.lihan3238.com" "Cloudflare SaaS public hostname"
Assert-Contains "docs/cloudflare-saas-runbook.md" "origin.lihan3238.top" "Cloudflare SaaS fallback origin"
Assert-Contains "docs/edge-proxy-runbook.md" "ORIGIN_UPSTREAM" "edge upstream variable"
Assert-Contains "docs/migration-runbook.md" "CONFIRM_FINAL_CUTOVER=yes" "migration confirmation"
Assert-Contains "docs/cpa-runbook.md" "ssh -L 8317" "CPA SSH tunnel guidance"
Assert-Contains "docs/cpa-runbook.md" "docker-compose\.cloudflare-tunnel\.yml" "CPA docs preserve tunnel overlay"
Assert-Contains "docs/cpa-runbook.md" "ops/cpa-ui\.sh open" "CPA docs use helper to open UI"
Assert-Contains "docs/cpa-runbook.md" "ops/cpa-ui\.sh close" "CPA docs use helper to close UI"
Assert-Contains "docs/cpa-runbook.md" "logs-max-total-size-mb" "CPA file log retention cap"
Assert-Contains "docs/cpa-runbook.md" "error-logs-max-files" "CPA error log file cap"
Assert-Contains "docs/zh-CN/cpa-runbook.md" "logs-max-total-size-mb" "Chinese CPA file log retention cap"
Assert-Contains "docs/zh-CN/cpa-runbook.md" "error-logs-max-files" "Chinese CPA error log file cap"
Assert-Contains "docs/new-api-code-map.md" "New API" "upstream feature map"
Assert-Contains "docs/new-api-full-research.md" "BillingSession" "billing research"
Assert-Contains "docs/browser-e2e-runbook.md" "NEW_API_BASE_URL" "browser E2E New API URL"
Assert-Contains "docs/browser-e2e-runbook.md" "e2e:web:new-api-admin" "browser E2E admin user actions"
Assert-Contains "docs/browser-e2e-runbook.md" "E2E Coverage Matrix" "browser E2E matrix guidance"
Assert-NotContains "docs/browser-e2e-runbook.md" "KUMA_" "removed browser Kuma E2E"
Assert-Contains "docs/development-workflow.md" "Layered E2E Policy" "layered E2E workflow"
Assert-Contains "docs/development-workflow.md" "ops/dev-gate\.sh" "dev gate workflow"
Assert-Contains "docs/development-workflow.md" "Reason:" "skipped E2E reason guidance"
Assert-Contains "docs/development-workflow.md" "Rerun:" "skipped E2E rerun guidance"
Assert-Contains "docs/wrapper-infra-runbook.md" "ops/dev-gate\.sh" "wrapper runbook dev gate"
Assert-Contains "docs/wrapper-infra-runbook.md" "feature-completion-check\.sh" "wrapper runbook feature completion"
Assert-Contains "docs/templates/ai-dev/spec.md" "User Acceptance Path" "feature spec user acceptance path"
Assert-Contains "docs/templates/ai-dev/plan.md" "Change Impact" "feature plan change impact"
Assert-Contains "docs/templates/ai-dev/plan.md" "E2E Coverage Matrix" "feature plan E2E matrix"
Assert-Contains "docs/templates/ai-dev/plan.md" "Documentation Impact" "feature plan documentation impact"
Assert-Contains "docs/templates/ai-dev/plan.md" "Usage/Test Guide" "feature plan usage guide"
Assert-Contains "docs/templates/ai-dev/handoff.md" "How To Use And Test" "feature handoff usage guide"
Assert-Contains "docs/templates/ai-dev/handoff.md" "E2E Results" "feature handoff E2E results"
Assert-Contains "docs/templates/ai-dev/handoff.md" "Documentation Updated" "feature handoff docs updated"
Assert-Contains "docs/templates/ai-dev/handoff.md" "Residual Risk" "feature handoff residual risk"
Assert-Contains "docs/templates/ai-dev/tasks.md" "ops/dev-gate\.sh" "feature tasks dev gate"
Assert-Contains ".github/pull_request_template.md" "E2E Coverage" "PR E2E checklist"
Assert-Contains ".github/pull_request_template.md" "Reason:" "PR skipped E2E reason"
Assert-Contains ".github/pull_request_template.md" "Rerun:" "PR skipped E2E rerun"

Assert-Contains "ops/deploy-release.sh" "sync-env-template\.sh" "release prepare env sync"
Assert-Contains "ops/deploy-release.sh" "git worktree add --detach" "release worktree creation"
Assert-Contains "ops/deploy-release.sh" "docker compose -p" "fixed release compose project"
Assert-Contains "ops/verify-remote-prod.sh" "/opt/lihan_ai_deploy/current" "remote verifier prefers release current path"
Assert-Contains "ops/check-production-runtime.sh" "relay-cloudflared" "production runtime Cloudflare Tunnel check"
Assert-Contains "ops/backup-cron.sh" "verify-postgres-backup\.sh" "backup cron verifies dumps"
Assert-Contains "ops/dev-gate.sh" "feature-completion-check\.sh" "dev gate feature completion check"
Assert-Contains "ops/dev-gate.sh" "verify-repo\.ps1 -SkipDocker" "dev gate repo verifier"
Assert-Contains "ops/feature-completion-check.sh" "E2E Coverage Matrix" "feature completion E2E matrix"
Assert-Contains "ops/feature-completion-check.sh" "Documentation Impact" "feature completion docs impact"
Assert-Contains "ops/feature-completion-check.sh" "How To Use And Test" "feature completion usage guide"
Assert-Contains "ops/feature-completion-check.sh" "Reason:" "feature completion skipped reason"
Assert-Contains "ops/feature-completion-check.sh" "Rerun:" "feature completion skipped rerun"
Assert-Contains "ops/prune-runtime-storage.sh" "BACKUP_MAX_TOTAL_MB" "runtime pruning backup max total"
Assert-Contains "ops/prune-runtime-storage.sh" "CONFIG_SNAPSHOT_MAX_TOTAL_MB" "runtime pruning snapshot max total"
Assert-Contains "ops/prune-runtime-storage.sh" "BACKUP_CRON_LOG_MAX_MB" "runtime pruning backup cron log rotation"
Assert-Contains "ops/sync-env-template.sh" "deprecated" "env sync reports deprecated keys"
Assert-Contains "ops/production-gate.sh" "tests/backup-cron.test.sh" "backup cron gate test"
Assert-Contains "ops/production-gate.sh" "feature-completion-check\.sh" "production gate feature completion check"
Assert-Contains "ops/production-gate.sh" "tests/storage-retention.test.sh" "storage retention gate test"
Assert-Contains "ops/production-gate.sh" "tests/env-template-sync.test.sh" "env sync gate test"
Assert-Contains "ops/production-gate.sh" "tests/local-new-api-build.test.sh" "local New API image gate test"
Assert-NotContains "ops/production-gate.sh" "production-monitor" "removed production monitor gate"
Assert-NotContains "ops/production-gate.sh" "ops-health" "removed ops health gate"
Assert-NotContains "ops/production-gate.sh" "kuma" "removed Kuma gate"
Assert-NotContains "ops/check-local-ports.sh" "KUMA_PORT" "removed local Kuma port check"
Assert-Contains "ops/cpa-ui.sh" "--no-deps" "CPA UI helper only recreates CPA service"
Assert-Contains "ops/check-new-api-admin-frontend.sh" "e2e:web:new-api-admin" "admin frontend checker runs Playwright"
Assert-Contains "ops/check-new-api-admin-frontend.sh" "CHECK_LOCAL_NEW_API_PATCH" "admin frontend checker has local patch mode"
Assert-Contains "docs/new-api-small-circle-launch-runbook.md" "station quota" "small circle station quota wording"
Assert-Contains "docs/new-api-small-circle-launch-runbook.md" "#4787" "small circle upstream PR policy"
Assert-Contains "docs/new-api-small-circle-launch-runbook.md" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1" "small circle local patched build"
Assert-Contains "docs/zh-CN/new-api-small-circle-launch-runbook.md" "station quota" "Chinese small circle station quota wording"
Assert-Contains "docs/zh-CN/new-api-small-circle-launch-runbook.md" "#4787" "Chinese small circle upstream PR policy"
Assert-Contains "docs/zh-CN/new-api-small-circle-launch-runbook.md" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1" "Chinese small circle local patched build"
Assert-Contains "ops/deploy-release.sh" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD" "release deploy local New API build toggle"
Assert-Contains "ops/deploy-release.sh" "DEPLOY_LOCAL_NEW_API_BUILD_MODE" "release deploy local New API build mode"
Assert-Contains "ops/deploy-release.sh" "--force-recreate" "local New API build forces container recreation"
Assert-Contains "ops/check-production-runtime.sh" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD" "runtime check local New API build toggle"
Assert-Contains "ops/check-production-runtime.sh" "DEPLOY_LOCAL_NEW_API_BUILD_MODE" "runtime check local New API build mode"
Assert-Contains "ops/check-production-runtime.sh" "new-api image" "runtime check validates local New API image identity"
Assert-Contains "ops/preflight.sh" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD" "preflight local New API build toggle"
Assert-Contains "ops/preflight.sh" "LOCAL_NEW_API_IMAGE must differ from NEW_API_IMAGE" "preflight rejects local image tag collision"

Assert-Contains ".github/workflows/ci.yml" "pull_request:" "CI pull request trigger"
Assert-Contains ".github/workflows/ci.yml" "submodules: recursive" "CI checks out submodules"
Assert-Contains ".github/workflows/ci.yml" "tests/\*\.test\.sh" "CI runs shell tests"
Assert-Contains ".github/workflows/ci.yml" "docker-compose\.cloudflare-tunnel\.yml" "CI renders Cloudflare Tunnel compose"
Assert-Contains ".github/workflows/ci.yml" "docker-compose\.local-build\.yml" "CI renders local New API build compose"
Assert-NotContains ".github/workflows/ci.yml" "docker-compose\.kuma\.ui\.yml" "CI no longer renders Kuma UI compose"
Assert-NotContains ".github/workflows/ci.yml" "docker-compose\.ops-dashboard\.yml" "CI no longer renders ops dashboard compose"
Assert-Contains ".github/workflows/ci.yml" "verify-repo\.ps1 -SkipDocker" "CI runs repository verifier"
Assert-Contains "package.json" "e2e:web:new-api-admin" "admin frontend Playwright script"
Assert-Contains "e2e/new-api-admin-users.spec.ts" "Manage Bindings" "admin users E2E checks bindings"
Assert-Contains "e2e/new-api-admin-users.spec.ts" "Manage Subscriptions" "admin users E2E checks subscriptions"

Assert-Contains "config/ops-profiles/glm-default.example.json" '"group": "default"' "default profile group"
Assert-Contains "config/ops-profiles/glm-default-health.example.json" '"group": "default"' "default health profile group"
Assert-NotContains "config/ops-profiles/glm-default.example.json" "standard" "old group name"
Assert-NotContains "config/ops-profiles/glm-default-health.example.json" "standard" "old group name"
Assert-Contains ".gitignore" "snapshots/" "configuration snapshots ignored"
Assert-NotContains ".env.example" "sk-[A-Za-z0-9]" "real-looking API keys"

$forbiddenCurrent = @(
    "README.md",
    "README.zh-CN.md",
    "docs/backup-strategy.md",
    "docs/zh-CN/backup-strategy.md",
    "docs/disaster-recovery-runbook.md",
    "docs/zh-CN/disaster-recovery-runbook.md",
    "docs/operations-runbook.md",
    "docs/zh-CN/operations-runbook.md",
    "docs/ops-quick-reference.md",
    "docs/zh-CN/ops-quick-reference.md",
    "docs/release-deployment-runbook.md",
    "docs/zh-CN/release-deployment-runbook.md",
    "docs/production-deployment-runbook.md",
    "docs/zh-CN/production-deployment-runbook.md",
    "docs/cpa-runbook.md",
    "docs/zh-CN/cpa-runbook.md",
    "docs/edge-proxy-runbook.md",
    "docs/zh-CN/edge-proxy-runbook.md"
)

foreach ($path in $forbiddenCurrent) {
    Assert-NotContains $path "Uptime Kuma|kuma-status|production-monitor|ops-dashboard|ops-health|offsite-backup|RESTIC_|restic snapshots|MONITOR_PUSH|MONITOR_ALERT" "removed monitoring/offsite operations"
}

if (-not $SkipDocker) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
        Push-Location $root
        try {
            docker compose --env-file .env.example config | Out-Null
            docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.prod.yml config | Out-Null
            docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml config | Out-Null
            docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cloudflare-tunnel.yml config | Out-Null
            docker compose --env-file .env.production.example -f docker-compose.edge.yml config | Out-Null
        }
        finally {
            Pop-Location
        }
    }
}

Write-Host "Repository verification passed."
