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
assert_contains "ops/check-production-runtime.sh" "RUNTIME_EXTERNAL_RETRIES"
assert_contains "ops/check-production-runtime.sh" "external_status_ok"

assert_contains "docs/cloudflare-saas-runbook.md" "Cloudflare Tunnel"
assert_contains "docs/cloudflare-saas-runbook.md" "cloudflared"
assert_contains "docs/cloudflare-saas-runbook.md" "--scale caddy=0"
assert_contains "docs/cloudflare-saas-runbook.md" "cpa-quota-static"
assert_contains "docs/cloudflare-saas-runbook.md" "/cpa-quota/*"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "Cloudflare Tunnel"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "cloudflared"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "--scale caddy=0"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "cpa-quota-static"
assert_contains "docs/zh-CN/cloudflare-saas-runbook.md" "/cpa-quota/*"

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

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
env_file="$tmp_dir/.env.production"
curl_count="$tmp_dir/curl-count"
docker_log="$tmp_dir/docker.log"
mkdir -p "$fake_bin"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$env_file" <<'EOF'
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
DEPLOY_COMPOSE_PROJECT=lihan_ai
DOMAIN=api.example.test
POSTGRES_USER=newapi
POSTGRES_DB=newapi
POSTGRES_PASSWORD=redacted
REDIS_PASSWORD=redacted
SESSION_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
EOF

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"

if [ "$1" = "inspect" ]; then
  case "$*" in
    *"relay-new-api"*) printf 'healthy\n'; exit 0 ;;
    *"relay-cloudflared"*) printf 'running\n'; exit 0 ;;
  esac
fi

if [ "$1" = "port" ] && [ "$2" = "relay-caddy" ]; then
  exit 1
fi

if [ "$1" = "logs" ] && [ "$4" = "relay-cloudflared" ]; then
  printf 'registered tunnel connection\n'
  exit 0
fi

if [ "$1" = "compose" ]; then
  case "$*" in
    *" config")
      exit 0
      ;;
    *" ps postgres")
      printf 'relay-postgres running\n'
      exit 0
      ;;
    *" ps redis")
      printf 'relay-redis running\n'
      exit 0
      ;;
    *" ps new-api")
      printf 'relay-new-api running\n'
      exit 0
      ;;
    *" ps cloudflared")
      printf 'relay-cloudflared running\n'
      exit 0
      ;;
    *" exec -T new-api wget"*)
      printf '{"success":true}\n'
      exit 0
      ;;
  esac
fi

echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

preflight_config_dir="$tmp_dir/config.yml"
preflight_credentials_file="$tmp_dir/tunnel.json"
preflight_env_file="$tmp_dir/.env.preflight"
mkdir -p "$preflight_config_dir"
printf '{"TunnelID":"example"}\n' > "$preflight_credentials_file"

cat > "$preflight_env_file" <<EOF
DEPLOY_ENV=production
DOMAIN=api.example.test
ACME_EMAIL=ops@example.test
POSTGRES_USER=newapi
POSTGRES_DB=newapi
POSTGRES_PASSWORD=redacted
REDIS_PASSWORD=redacted
SESSION_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
CLOUDFLARED_CONFIG_PATH=$preflight_config_dir
CLOUDFLARED_CREDENTIALS_PATH=$preflight_credentials_file
EOF

set +e
preflight_output="$(cd "$ROOT_DIR" && PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 ENV_FILE="$preflight_env_file" bash ops/preflight.sh 2>&1)"
preflight_status="$?"
set -e
[ "$preflight_status" -ne 0 ] || fail "preflight should fail when CLOUDFLARED_CONFIG_PATH is a directory"
printf '%s' "$preflight_output" | grep -q "must be a file, not a directory" || fail "preflight should explain directory-valued config path: $preflight_output"

rm -rf "$preflight_config_dir"
printf 'tunnel: example\ncredentials-file: /etc/cloudflared/tunnel.json\n' > "$preflight_config_dir"
preflight_ok_output="$(cd "$ROOT_DIR" && PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 ENV_FILE="$preflight_env_file" bash ops/preflight.sh)"
printf '%s' "$preflight_ok_output" | grep -q "preflight passed" || fail "preflight should pass when tunnel paths are files: $preflight_ok_output"

cat > "$fake_bin/curl" <<'CURL'
#!/usr/bin/env sh
count_file="$FAKE_CURL_COUNT"
count=0
[ -f "$count_file" ] && count="$(cat "$count_file")"
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"

if [ "$count" -lt 2 ]; then
  exit 22
fi

printf '{"success":true}\n'
CURL
chmod +x "$fake_bin/curl"

cat > "$fake_bin/ss" <<'SS'
#!/usr/bin/env sh
exit 0
SS
chmod +x "$fake_bin/ss"

: > "$docker_log"
printf '0\n' > "$curl_count"
runtime_output="$(PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" FAKE_CURL_COUNT="$curl_count" ENV_FILE="$env_file" RUNTIME_EXTERNAL_RETRIES=2 RUNTIME_EXTERNAL_RETRY_SECONDS=0 "$ROOT_DIR/ops/check-production-runtime.sh")"
printf '%s' "$runtime_output" | grep -q "PASS external status" || fail "runtime check should pass after external retry: $runtime_output"
[ "$(cat "$curl_count")" -eq 2 ] || fail "external status should retry once before passing"

echo "cloudflare tunnel compose tests passed"
