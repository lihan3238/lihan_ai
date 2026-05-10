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

assert_file "docker-compose.cloudflare-tunnel.yml"
assert_file "docs/cloudflare-saas-runbook.md"
assert_file "docs/zh-CN/cloudflare-saas-runbook.md"

assert_contains "docker-compose.cloudflare-tunnel.yml" "relay-cloudflared"
assert_contains "docker-compose.cloudflare-tunnel.yml" "cloudflare/cloudflared"
assert_contains "docker-compose.cloudflare-tunnel.yml" "tunnel --config /etc/cloudflared/config.yml run"
assert_contains "docker-compose.cloudflare-tunnel.yml" "CLOUDFLARED_CONFIG_PATH"
assert_contains "docker-compose.cloudflare-tunnel.yml" "CLOUDFLARED_CREDENTIALS_PATH"
assert_contains "docker-compose.cloudflare-tunnel.yml" "relay-internal"

assert_contains ".env.production.example" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0"
assert_contains ".env.production.example" "CLOUDFLARED_CONFIG_PATH="
assert_contains ".env.production.example" "CLOUDFLARED_CREDENTIALS_PATH="

assert_contains "ops/deploy-release.sh" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL"
assert_contains "ops/deploy-release.sh" "docker-compose.cloudflare-tunnel.yml"
assert_contains "ops/deploy-release.sh" "--scale caddy=0"
assert_contains "ops/check-production-runtime.sh" "relay-cloudflared"
assert_contains "ops/check-production-runtime.sh" "CLOUDFLARE_TUNNEL"

assert_contains "docs/cloudflare-saas-runbook.md" "Cloudflare Tunnel"
assert_contains "docs/cloudflare-saas-runbook.md" "cloudflared"
assert_contains "docs/cloudflare-saas-runbook.md" "--scale caddy=0"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "Cloudflare Tunnel"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "cloudflared"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "--scale caddy=0"

if command -v docker >/dev/null 2>&1; then
  cd "$ROOT_DIR"
  docker compose --env-file .env.production.example \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    -f docker-compose.cloudflare-tunnel.yml \
    config >/dev/null

  docker compose --env-file .env.production.example \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    -f docker-compose.cpa.yml \
    -f docker-compose.cloudflare-tunnel.yml \
    config >/dev/null
fi

echo "cloudflare tunnel compose tests passed"
