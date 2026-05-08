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
Assert-Directory "config"
Assert-Directory "vendor/new-api"

Assert-File "docs/relay-station-requirements.md"
Assert-File "docs/operations-runbook.md"
Assert-File "docs/payment-safety.md"
Assert-File "docs/cache-observability.md"
Assert-File "config/model-catalog.example.json"
Assert-File "config/packages.example.json"
Assert-File "ops/preflight.sh"
Assert-File "ops/backup-postgres.sh"
Assert-File "ops/restore-postgres.sh"
Assert-File "vendor/new-api/README.md"

Assert-Contains "docker-compose.yml" "calciumion/new-api" "New API image"
Assert-Contains "docker-compose.dev.yml" "NEW_API_DEV_PORT" "development port override"
Assert-Contains ".gitmodules" "QuantumNous/new-api" "New API upstream submodule"
Assert-Contains "docker-compose.yml" "postgres" "PostgreSQL service"
Assert-Contains "docker-compose.yml" "redis" "Redis service"
Assert-Contains "docker-compose.yml" "caddy" "HTTPS reverse proxy"
Assert-Contains "docker-compose.yml" "uptime-kuma" "monitoring service"
Assert-Contains ".env.example" "CHANGE_ME" "explicit placeholder secrets"
Assert-Contains ".env.example" "INVITE_ONLY=true" "invite-only operating default"
Assert-Contains "config/model-catalog.example.json" '"standard"' "standard channel pool"
Assert-Contains "config/model-catalog.example.json" '"economy"' "economy channel pool"
Assert-Contains "config/packages.example.json" '"expires_in_days": 30' "30-day monthly quota expiry"
Assert-Contains "docs/payment-safety.md" "manual confirmation" "phase-one manual payment flow"
Assert-Contains "docs/cache-observability.md" "cached_tokens" "upstream cache hit accounting"

Assert-NotContains ".env.example" "sk-[A-Za-z0-9]" "real-looking API keys"
Assert-NotContains "config/model-catalog.example.json" "sk-[A-Za-z0-9]" "real-looking API keys"

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
