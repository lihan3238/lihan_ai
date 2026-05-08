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
Assert-File ".gitignore"
Assert-Directory "docs"
Assert-Directory "ops"
Assert-Directory "vendor/new-api"

Assert-File "docs/operations-runbook.md"
Assert-File "docs/new-api-code-map.md"
Assert-File "docs/new-api-full-research.md"
Assert-File "docs/local-development-state.md"
Assert-File "docs/backup-strategy.md"
Assert-File "docs/server-buying-guide.md"
Assert-File "docs/development-workflow.md"
Assert-File "docs/wrapper-infra-runbook.md"
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
Assert-File "tests/e2e-api-billing.test.sh"
Assert-File "tests/wrapper-infra.test.sh"
Assert-File "vendor/new-api/README.md"

Assert-Contains "docker-compose.yml" "calciumion/new-api" "New API image"
Assert-Contains "docker-compose.dev.yml" "NEW_API_DEV_PORT" "development port override"
Assert-Contains "docker-compose.local-build.yml" "vendor/new-api" "local New API build context"
Assert-Contains ".gitmodules" "QuantumNous/new-api" "New API upstream submodule"
Assert-Contains "docker-compose.yml" "postgres" "PostgreSQL service"
Assert-Contains "docker-compose.yml" "redis" "Redis service"
Assert-Contains "docker-compose.yml" "caddy" "HTTPS reverse proxy"
Assert-Contains "docker-compose.yml" "uptime-kuma" "monitoring service"
Assert-Contains ".env.example" "CHANGE_ME" "explicit placeholder secrets"
Assert-Contains "docs/new-api-code-map.md" "New API" "upstream feature map"
Assert-Contains "docs/new-api-full-research.md" "BillingSession" "billing research"
Assert-Contains "docs/local-development-state.md" "docker compose down -v" "state deletion warning"
Assert-Contains "docs/backup-strategy.md" "off-server" "off-server backup guidance"
Assert-Contains "docs/phase1-new-api-validation-runbook.md" "e2e-api-billing" "API billing e2e runbook"
Assert-Contains "docs/development-workflow.md" "Research Gate" "research workflow"
Assert-Contains ".gitignore" "snapshots/" "configuration snapshots ignored"

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
