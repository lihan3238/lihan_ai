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

assert_file "docs/cloudflare-saas-runbook.md"
assert_file "docs/zh-CN/cloudflare-saas-runbook.md"

for file in docs/cloudflare-saas-runbook.md docs/zh-CN/cloudflare-saas-runbook.md; do
  assert_contains "$file" "api.lihan3238.com"
  assert_contains "$file" "origin.lihan3238.top"
  assert_contains "$file" "72.60.124.21"
  assert_contains "$file" "CLOUDFLARE_SAAS_FALLBACK_ORIGIN"
  assert_contains "$file" "CLOUDFLARE_SAAS_ORIGIN_IP"
  assert_contains "$file" "curl -vk --resolve api.lihan3238.com:443:72.60.124.21"
  assert_contains "$file" "DOMAIN=api.lihan3238.com"
  assert_contains "$file" "DOMAIN=origin.lihan3238.top"
done

assert_contains ".env.production.example" "CLOUDFLARE_SAAS_FALLBACK_ORIGIN="
assert_contains ".env.production.example" "CLOUDFLARE_SAAS_ORIGIN_IP="
assert_contains "ops/preflight.sh" "DOMAIN must be the public custom hostname"
assert_contains "ops/check-production-runtime.sh" "CLOUDFLARE_SAAS_ORIGIN_IP"
assert_contains "ops/check-production-runtime.sh" "--resolve"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
if [ "$1" = "compose" ]; then
  exit 0
fi
echo "unexpected docker args: $*" >&2
exit 1
DOCKER
chmod +x "$fake_bin/docker"

write_env() {
  path="$1"
  domain="$2"
  cat > "$path" <<EOF
DEPLOY_ENV=production
DOMAIN=$domain
ACME_EMAIL=ops@example.com
SESSION_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
POSTGRES_USER=newapi
POSTGRES_PASSWORD=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
POSTGRES_DB=newapi
REDIS_PASSWORD=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
CLOUDFLARE_SAAS_FALLBACK_ORIGIN=origin.lihan3238.top
CLOUDFLARE_SAAS_ORIGIN_IP=72.60.124.21
EOF
}

bad_env="$tmp_dir/bad.env"
good_env="$tmp_dir/good.env"
write_env "$bad_env" "origin.lihan3238.top"
write_env "$good_env" "api.lihan3238.com"

set +e
bad_output="$(PATH="$fake_bin:$PATH" ENV_FILE="$bad_env" "$ROOT_DIR/ops/preflight.sh" 2>&1)"
bad_status="$?"
set -e
[ "$bad_status" -ne 0 ] || fail "preflight should reject DOMAIN=fallback origin"
printf '%s' "$bad_output" | grep -q "DOMAIN must be the public custom hostname" || fail "fallback-origin error was unclear: $bad_output"

PATH="$fake_bin:$PATH" ENV_FILE="$good_env" "$ROOT_DIR/ops/preflight.sh" >/dev/null

echo "cloudflare saas domain tests passed"
