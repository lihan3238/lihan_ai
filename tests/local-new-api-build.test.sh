#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q -- "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_contains "vendor/new-api/.dockerignore" "/web/default/node_modules"
assert_contains "vendor/new-api/.dockerignore" "/web/classic/node_modules"
assert_contains "vendor/new-api/.dockerignore" "/web/default/dist"
assert_contains "vendor/new-api/.dockerignore" "/web/classic/dist"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
env_file="$tmp_dir/.env.production"
docker_log="$tmp_dir/docker.log"
mkdir -p "$fake_bin"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$env_file" <<'EOF'
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
DEPLOY_COMPOSE_PROJECT=lihan_ai
NEW_API_IMAGE=calciumion/new-api:latest
LOCAL_NEW_API_IMAGE=lihan-ai/new-api:local
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
    *".Config.Image"*"relay-new-api"*) printf '%s\n' "${FAKE_NEW_API_IMAGE:-calciumion/new-api:latest}"; exit 0 ;;
    *"relay-new-api"*) printf 'healthy\n'; exit 0 ;;
    *"relay-cloudflared"*) printf 'running\n'; exit 0 ;;
  esac
fi

if [ "$1" = "port" ] && [ "$2" = "relay-caddy" ]; then
  exit 1
fi

if [ "$1" = "logs" ]; then
  printf 'registered tunnel connection\n'
  exit 0
fi

if [ "$1" = "compose" ]; then
  printf 'ENV_NEW_API_IMAGE=%s\n' "${NEW_API_IMAGE:-}" >> "$FAKE_DOCKER_LOG"
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

cat > "$fake_bin/curl" <<'CURL'
#!/usr/bin/env sh
printf '{"success":true}\n'
CURL
chmod +x "$fake_bin/curl"

cat > "$fake_bin/ss" <<'SS'
#!/usr/bin/env sh
exit 0
SS
chmod +x "$fake_bin/ss"

set +e
bad_output="$(PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" FAKE_NEW_API_IMAGE=calciumion/new-api:latest ENV_FILE="$env_file" RUNTIME_EXTERNAL_RETRIES=1 RUNTIME_EXTERNAL_RETRY_SECONDS=0 "$ROOT_DIR/ops/check-production-runtime.sh" 2>&1)"
bad_status="$?"
set -e
[ "$bad_status" -ne 0 ] || fail "runtime check should fail when local build is enabled but official image is running"
printf '%s' "$bad_output" | grep -q "FAIL new-api image" || fail "runtime check should report new-api image failure: $bad_output"
printf '%s' "$bad_output" | grep -q "expected lihan-ai/new-api:local, got calciumion/new-api:latest" || fail "runtime check should show expected and actual image: $bad_output"

good_output="$(PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" FAKE_NEW_API_IMAGE=lihan-ai/new-api:local ENV_FILE="$env_file" RUNTIME_EXTERNAL_RETRIES=1 RUNTIME_EXTERNAL_RETRY_SECONDS=0 "$ROOT_DIR/ops/check-production-runtime.sh")"
printf '%s' "$good_output" | grep -q "PASS new-api image" || fail "runtime check should pass when local image is running: $good_output"

pull_env_file="$tmp_dir/.env.pull.production"
cat > "$pull_env_file" <<'EOF'
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull
DEPLOY_COMPOSE_PROJECT=lihan_ai
NEW_API_IMAGE=calciumion/new-api:latest
LOCAL_NEW_API_IMAGE=ghcr.io/lihan3238/new-api:f80e8ea6-dropdown
DOMAIN=api.example.test
POSTGRES_USER=newapi
POSTGRES_DB=newapi
POSTGRES_PASSWORD=redacted
REDIS_PASSWORD=redacted
SESSION_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
EOF

: > "$docker_log"
pull_output="$(PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" FAKE_NEW_API_IMAGE=ghcr.io/lihan3238/new-api:f80e8ea6-dropdown ENV_FILE="$pull_env_file" RUNTIME_EXTERNAL_RETRIES=1 RUNTIME_EXTERNAL_RETRY_SECONDS=0 "$ROOT_DIR/ops/check-production-runtime.sh")"
printf '%s' "$pull_output" | grep -q "PASS new-api image" || fail "runtime check should pass for pulled patch image: $pull_output"
grep -q "ENV_NEW_API_IMAGE=ghcr.io/lihan3238/new-api:f80e8ea6-dropdown" "$docker_log" || fail "runtime compose should override NEW_API_IMAGE in pull mode"
if grep -q "docker-compose.local-build.yml" "$docker_log"; then
  fail "pull mode runtime check must not include local-build compose file"
fi

echo "local New API build tests passed"
