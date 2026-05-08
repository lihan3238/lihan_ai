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
    $content = Get-Content -Raw -LiteralPath $full
    if ($content -notmatch $Pattern) {
        throw "$Path does not contain required content: $Description"
    }
}

function Assert-NotContains {
    param([string]$Path, [string]$Pattern, [string]$Description)
    $full = Join-Path $root $Path
    $content = Get-Content -Raw -LiteralPath $full
    if ($content -match $Pattern) {
        throw "$Path contains forbidden content: $Description"
    }
}

Assert-File "README.md"
Assert-File "docker-compose.yml"
Assert-File "docker-compose.dev.yml"
Assert-File ".env.example"
Assert-File ".gitmodules"
Assert-File "Caddyfile"
Assert-File "Caddyfile.status.example"
Assert-File ".gitignore"
Assert-File "AGENTS.md"
Assert-Directory "docs"
Assert-Directory "ops"
Assert-Directory "vendor/new-api"
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
Assert-File "docs/kuma-status-runbook.md"
Assert-Directory "docs/ai-dev/2026-05-08-spec-kit-codex-init"
Assert-Directory "docs/ai-dev/2026-05-08-dual-health-monitoring"
Assert-Directory "docs/templates/ai-dev"
Assert-File "docs/templates/ai-dev/research.md"
Assert-File "docs/templates/ai-dev/spec.md"
Assert-File "docs/templates/ai-dev/plan.md"
Assert-File "docs/templates/ai-dev/tasks.md"
Assert-File "docs/templates/ai-dev/handoff.md"
Assert-File "ops/preflight.sh"
Assert-File "ops/backup-postgres.sh"
Assert-File "ops/verify-postgres-backup.sh"
Assert-File "ops/restore-postgres.sh"
Assert-File "ops/e2e-api-billing.sh"
Assert-File "ops/build-local-new-api.sh"
Assert-File "ops/start-local-new-api.sh"
Assert-File "ops/export-config-snapshot.sh"
Assert-File "ops/drill-restore-postgres.sh"
Assert-File "ops/production-gate.sh"
Assert-File "ops/ai-dev-check.sh"
Assert-File "ops/validate-ops-profile.sh"
Assert-File "ops/channel-health-advisor.sh"
Assert-File "tests/e2e-api-billing.test.sh"
Assert-File "tests/wrapper-infra.test.sh"
Assert-File "tests/ai-dev-check.test.sh"
Assert-File "tests/ops-profile.test.sh"
Assert-File "tests/spec-kit-init.test.sh"
Assert-File "tests/channel-health-advisor.test.sh"
Assert-File "config/ops-profiles/glm-standard.example.json"
Assert-File "config/ops-profiles/glm-standard-health.example.json"
Assert-File "vendor/new-api/README.md"
Assert-File ".specify/integration.json"
Assert-File ".specify/init-options.json"
Assert-File ".specify/scripts/bash/create-new-feature.sh"
Assert-File ".specify/scripts/bash/setup-plan.sh"
Assert-File ".specify/scripts/bash/setup-tasks.sh"
Assert-File ".specify/templates/spec-template.md"
Assert-File ".specify/templates/plan-template.md"
Assert-File ".specify/templates/tasks-template.md"
Assert-File ".specify/memory/constitution.md"
Assert-File ".agents/skills/speckit-specify/SKILL.md"
Assert-File ".agents/skills/speckit-plan/SKILL.md"
Assert-File ".agents/skills/speckit-tasks/SKILL.md"
Assert-File ".agents/skills/speckit-implement/SKILL.md"

Assert-Contains "docker-compose.yml" "calciumion/new-api" "New API image"
Assert-Contains "docker-compose.dev.yml" "NEW_API_DEV_PORT" "development port override"
Assert-Contains "docker-compose.dev.yml" "3100" "development host port default"
Assert-Contains "docker-compose.local-build.yml" "vendor/new-api" "local New API build context"
Assert-Contains ".gitmodules" "QuantumNous/new-api" "New API upstream submodule"
Assert-Contains "docker-compose.yml" "postgres" "PostgreSQL service"
Assert-Contains "docker-compose.yml" "redis" "Redis service"
Assert-Contains "docker-compose.yml" "caddy" "HTTPS reverse proxy"
Assert-Contains "docker-compose.yml" "uptime-kuma" "monitoring service"
Assert-Contains "Caddyfile.status.example" "STATUS_DOMAIN" "optional status domain"
Assert-Contains "Caddyfile.status.example" "uptime-kuma:3001" "Uptime Kuma reverse proxy target"
Assert-Contains ".env.example" "CHANGE_ME" "explicit placeholder secrets"
Assert-Contains ".env.example" "STATUS_DOMAIN=" "optional status domain variable"
Assert-Contains "docs/new-api-code-map.md" "New API" "upstream feature map"
Assert-Contains "docs/new-api-full-research.md" "BillingSession" "billing research"
Assert-Contains "docs/local-development-state.md" "docker compose down -v" "state deletion warning"
Assert-Contains "docs/backup-strategy.md" "off-server" "off-server backup guidance"
Assert-Contains "docs/phase1-new-api-validation-runbook.md" "e2e-api-billing" "API billing e2e runbook"
Assert-Contains "docs/development-workflow.md" "Research Gate" "research workflow"
Assert-Contains "docs/development-workflow.md" "Research -> Spec -> Plan -> Tasks -> Implement -> Verify -> Commit" "spec-driven workflow"
Assert-Contains "docs/development-workflow.md" "speckit-specify" "Spec Kit Codex workflow"
Assert-Contains "docs/spec-kit-integration-runbook.md" "spec-kit.git@v0.8.7" "pinned Spec Kit install"
Assert-Contains "docs/spec-kit-integration-runbook.md" "specify init --here --offline --integration codex" "repository Spec Kit init"
Assert-Contains "docs/kuma-status-runbook.md" "API Gateway" "public status component"
Assert-Contains "docs/kuma-status-runbook.md" "GLM Standard" "public status model pool"
Assert-Contains "AGENTS.md" "SPECKIT START" "Spec Kit context marker"
Assert-Contains ".specify/integration.json" '"integration": "codex"' "Codex Spec Kit integration"
Assert-Contains ".specify/integration.json" '"skills": true' "Codex skills integration"
Assert-Contains ".specify/init-options.json" '"speckit_version": "0.8.7"' "pinned Spec Kit version"
Assert-Contains "docs/templates/ai-dev/tasks.md" "Approved for implementation: no" "implementation approval default"
Assert-Contains "ops/ai-dev-check.sh" "Approved for implementation: yes" "implementation approval gate"
Assert-Contains "ops/production-gate.sh" "AI_DEV_FEATURE_DIR" "feature document production gate"
Assert-Contains "ops/production-gate.sh" "OPS_PROFILE_FILE" "ops profile production gate"
Assert-Contains "ops/production-gate.sh" "OPS_HEALTH_PROFILE_FILE" "channel health production gate"
Assert-Contains "ops/production-gate.sh" "tests/spec-kit-init.test.sh" "Spec Kit production gate test"
Assert-Contains "ops/production-gate.sh" "tests/channel-health-advisor.test.sh" "channel health production gate test"
Assert-Contains "config/ops-profiles/glm-standard.example.json" "glm-5.1" "GLM standard ops profile model"
Assert-Contains "config/ops-profiles/glm-standard-health.example.json" "max_error_rate" "GLM standard health threshold"
Assert-Contains ".gitignore" "snapshots/" "configuration snapshots ignored"
Assert-Contains ".gitignore" "\.agents/\*\*" "agent private artifacts ignored"

Assert-NotContains ".env.example" "sk-[A-Za-z0-9]" "real-looking API keys"

if (-not $SkipDocker) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
        Push-Location $root
        try {
            docker compose --env-file .env.example config | Out-Null
        }
        finally {
            Pop-Location
        }
    }
}

Write-Host "Repository verification passed."
