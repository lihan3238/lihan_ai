#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/cpa-ui.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
env_file="$tmp_dir/.env.production"
docker_log="$tmp_dir/docker.log"
mkdir -p "$fake_bin"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$env_file" <<'EOF'
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=1
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
CPA_UI_PORT=8317
EOF

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
exit 0
DOCKER
chmod +x "$fake_bin/docker"

assert_contains() {
  text="$1"
  pattern="$2"
  printf '%s' "$text" | grep -q -- "$pattern" || fail "missing pattern: $pattern in $text"
}

assert_not_contains() {
  text="$1"
  pattern="$2"
  if printf '%s' "$text" | grep -q -- "$pattern"; then
    fail "forbidden pattern: $pattern in $text"
  fi
}

: > "$docker_log"
PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" ENV_FILE="$env_file" "$SCRIPT" open
open_args="$(cat "$docker_log")"
assert_contains "$open_args" "compose -p lihan_ai"
assert_contains "$open_args" "--env-file $env_file"
assert_contains "$open_args" "docker-compose.cpa.yml"
assert_contains "$open_args" "docker-compose.cloudflare-tunnel.yml"
assert_contains "$open_args" "docker-compose.cpa.ui.yml"
assert_contains "$open_args" "up -d --force-recreate --no-deps cli-proxy-api"
assert_not_contains "$open_args" "--scale caddy=0"
assert_not_contains "$open_args" "--remove-orphans"

: > "$docker_log"
PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" ENV_FILE="$env_file" "$SCRIPT" close
close_args="$(cat "$docker_log")"
assert_contains "$close_args" "compose -p lihan_ai"
assert_contains "$close_args" "docker-compose.cpa.yml"
assert_contains "$close_args" "docker-compose.cloudflare-tunnel.yml"
assert_contains "$close_args" "up -d --force-recreate --no-deps cli-proxy-api"
assert_not_contains "$close_args" "docker-compose.cpa.ui.yml"
assert_not_contains "$close_args" "--scale caddy=0"
assert_not_contains "$close_args" "--remove-orphans"

: > "$docker_log"
PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" ENV_FILE="$env_file" "$SCRIPT" ps
ps_args="$(cat "$docker_log")"
assert_contains "$ps_args" "ps cli-proxy-api"

no_tunnel_env="$tmp_dir/.env.no-tunnel"
cat > "$no_tunnel_env" <<'EOF'
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=1
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0
EOF

: > "$docker_log"
PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" ENV_FILE="$no_tunnel_env" "$SCRIPT" open
no_tunnel_args="$(cat "$docker_log")"
assert_not_contains "$no_tunnel_args" "docker-compose.cloudflare-tunnel.yml"
assert_contains "$no_tunnel_args" "docker-compose.cpa.ui.yml"

echo "cpa ui script tests passed"
