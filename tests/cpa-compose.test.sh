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

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -q -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

assert_file "vendor/cli-proxy-api/docker-compose.yml"
assert_file "vendor/cli-proxy-api/config.example.yaml"
assert_file "docker-compose.cpa.yml"
assert_file "docker-compose.cpa.ui.yml"
assert_file "Caddyfile.cpa-quota"
assert_file "public/cpa-quota/widget.html"
assert_file "ops/cpa-ui.sh"
assert_file "ops/cpa-quota-snapshot.sh"
assert_file "ops/sync-cpa-upstream-assets.sh"
assert_file "docs/cpa-runbook.md"
assert_file "docs/zh-CN/cpa-runbook.md"

assert_contains ".gitmodules" "router-for-me/CLIProxyAPI"
assert_contains ".gitmodules" "path = vendor/cli-proxy-api"
assert_contains "vendor/cli-proxy-api/docker-compose.yml" "eceasy/cli-proxy-api"
assert_contains "vendor/cli-proxy-api/docker-compose.yml" "\"8317:8317\""
assert_contains "vendor/cli-proxy-api/config.example.yaml" "remote-management:"
assert_contains "vendor/cli-proxy-api/config.example.yaml" "secret-key:"
assert_contains "vendor/cli-proxy-api/config.example.yaml" "panel-github-repository:"

assert_contains "docker-compose.cpa.yml" "container_name: relay-cpa"
assert_contains "docker-compose.cpa.yml" "relay-internal"
assert_contains "docker-compose.cpa.yml" "/opt/lihan_ai/data/cpa/config.yaml"
assert_contains "docker-compose.cpa.yml" "driver: json-file"
assert_contains "docker-compose.cpa.yml" "max-size: \"20m\""
assert_contains "docker-compose.cpa.yml" "max-file: \"5\""
assert_contains "docker-compose.cpa.yml" "cpa-quota-static"
assert_contains "docker-compose.cpa.yml" "relay-cpa-quota-static"
assert_contains "docker-compose.cpa.yml" "./Caddyfile.cpa-quota:/etc/caddy/Caddyfile:ro"
assert_contains "docker-compose.cpa.yml" "./public/cpa-quota:/srv/cpa-quota:ro"
assert_contains "docker-compose.cpa.yml" "CPA_PUBLIC_PATH"
assert_not_contains "docker-compose.cpa.yml" "8317:8317"
assert_not_contains "docker-compose.cpa.yml" "0.0.0.0:8317"
assert_not_contains "docker-compose.cpa.yml" "8080:8080"
assert_contains "Caddyfile.cpa-quota" "handle_path /cpa-quota/*"
assert_contains "Caddyfile.cpa-quota" "/srv/cpa-quota"
assert_contains "Caddyfile" "handle_path /cpa-quota/*"
assert_contains "Caddyfile" "cpa-quota-static:8080"

assert_contains "docker-compose.cpa.ui.yml" "127.0.0.1:"
assert_contains "docker-compose.cpa.ui.yml" "CPA_UI_PORT"

assert_contains "docs/cpa-runbook.md" "ssh -L 8317"
assert_contains "docs/cpa-runbook.md" "Do not expose"
assert_contains "docs/cpa-runbook.md" "/opt/lihan_ai/data/cpa"
assert_contains "docs/cpa-runbook.md" "/opt/lihan_ai_deploy/shared/data/cpa"
assert_contains "docs/cpa-runbook.md" "docker compose -p lihan_ai"
assert_contains "docs/cpa-runbook.md" "docker-compose.cloudflare-tunnel.yml"
assert_contains "docs/cpa-runbook.md" "ops/cpa-ui.sh open"
assert_contains "docs/cpa-runbook.md" "ops/cpa-ui.sh close"
assert_contains "docs/cpa-runbook.md" "ops/cpa-quota-snapshot.sh"
assert_contains "docs/cpa-runbook.md" "cpa-quota/home.html"
assert_contains "docs/cpa-runbook.md" "cpa-quota/widget.html"
assert_contains "docs/cpa-runbook.md" "quota-snapshot.json"
assert_contains "docs/cpa-runbook.md" "cpa-quota-static"
assert_contains "docs/cpa-runbook.md" "--no-deps"
assert_not_contains "docs/cpa-runbook.md" "scale_args=\"--scale caddy=0\""
assert_contains "docs/cpa-runbook.md" "--force-recreate"
assert_contains "docs/cpa-runbook.md" "Do not run"
assert_contains "docs/zh-CN/cpa-runbook.md" "ssh -L 8317"
assert_contains "docs/zh-CN/cpa-runbook.md" "/opt/lihan_ai/data/cpa"
assert_contains "docs/zh-CN/cpa-runbook.md" "/opt/lihan_ai_deploy/shared/data/cpa"
assert_contains "docs/zh-CN/cpa-runbook.md" "docker compose -p lihan_ai"
assert_contains "docs/zh-CN/cpa-runbook.md" "docker-compose.cloudflare-tunnel.yml"
assert_contains "docs/zh-CN/cpa-runbook.md" "ops/cpa-ui.sh open"
assert_contains "docs/zh-CN/cpa-runbook.md" "ops/cpa-ui.sh close"
assert_contains "docs/zh-CN/cpa-runbook.md" "ops/cpa-quota-snapshot.sh"
assert_contains "docs/zh-CN/cpa-runbook.md" "cpa-quota/home.html"
assert_contains "docs/zh-CN/cpa-runbook.md" "cpa-quota/widget.html"
assert_contains "docs/zh-CN/cpa-runbook.md" "quota-snapshot.json"
assert_contains "docs/zh-CN/cpa-runbook.md" "cpa-quota-static"
assert_contains "docs/zh-CN/cpa-runbook.md" "--no-deps"
assert_not_contains "docs/zh-CN/cpa-runbook.md" "scale_args=\"--scale caddy=0\""
assert_contains "docs/zh-CN/cpa-runbook.md" "--force-recreate"

assert_contains "ops/sync-cpa-upstream-assets.sh" "submodule update --init --remote vendor/cli-proxy-api"
assert_contains "ops/sync-cpa-upstream-assets.sh" "git diff --submodule vendor/cli-proxy-api"

if command -v docker >/dev/null 2>&1; then
  cd "$ROOT_DIR"
  docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml config >/dev/null
  docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cpa.ui.yml config >/dev/null

  ui_config="$(docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cpa.ui.yml config)"
  printf '%s\n' "$ui_config" | grep -q 'max-size: 20m' || fail "CPA UI compose should preserve CPA Docker log max-size"
  printf '%s\n' "$ui_config" | grep -q 'max-file: "5"' || fail "CPA UI compose should preserve CPA Docker log max-file"
  printf '%s\n' "$ui_config" | awk '
    /target: \/CLIProxyAPI\/config.yaml/ { in_config = 1; next }
    in_config && /read_only: true/ { exit 42 }
    in_config && /target:/ { in_config = 0 }
  ' || fail "CPA UI override must mount /CLIProxyAPI/config.yaml writable so the management UI can save config"
fi

echo "cpa compose tests passed"
