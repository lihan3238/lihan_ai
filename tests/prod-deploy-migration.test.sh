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

assert_executable() {
  [ -x "$ROOT_DIR/$1" ] || fail "missing executable: $1"
}

assert_contains() {
  file="$1"
  pattern="$2"
  grep -q "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_file "docker-compose.prod.yml"
assert_file "docker-compose.edge.yml"
assert_file "Caddyfile.edge.example"
assert_file ".env.production.example"
assert_file "docs/production-deployment-runbook.md"
assert_file "docs/edge-proxy-runbook.md"
assert_file "docs/migration-runbook.md"
assert_file "docs/disaster-recovery-runbook.md"
assert_file "docs/ai-dev/2026-05-10-prod-deploy-migration-kit/research.md"
assert_file "docs/ai-dev/2026-05-10-prod-deploy-migration-kit/spec.md"
assert_file "docs/ai-dev/2026-05-10-prod-deploy-migration-kit/plan.md"
assert_file "docs/ai-dev/2026-05-10-prod-deploy-migration-kit/tasks.md"
assert_file "docs/ai-dev/2026-05-10-prod-deploy-migration-kit/handoff.md"
assert_executable "ops/bootstrap-server.sh"
assert_executable "ops/deploy-prod.sh"
assert_executable "ops/verify-remote-prod.sh"
assert_executable "ops/migration-preflight.sh"
assert_executable "ops/migrate-prod.sh"

assert_contains ".gitignore" "!.env.production.example"
assert_contains ".env.production.example" "DEPLOY_ENV=production"
assert_contains ".env.production.example" "EDGE_DOMAIN="
assert_contains "docker-compose.prod.yml" "max-size"
assert_contains "docker-compose.prod.yml" "new-api"
assert_contains "docker-compose.edge.yml" "caddy"
assert_contains "Caddyfile.edge.example" "ORIGIN_UPSTREAM"
assert_contains "docs/ai-dev/2026-05-10-prod-deploy-migration-kit/tasks.md" "Approved for implementation: yes"

set +e
deploy_output="$(DEPLOY_HOST= "$ROOT_DIR/ops/deploy-prod.sh" 2>&1)"
deploy_status="$?"
set -e
[ "$deploy_status" -eq 2 ] || fail "expected deploy missing host exit 2, got $deploy_status: $deploy_output"
printf '%s' "$deploy_output" | grep -q "DEPLOY_HOST is not set" || fail "deploy missing host message: $deploy_output"

set +e
verify_output="$(DEPLOY_HOST= "$ROOT_DIR/ops/verify-remote-prod.sh" 2>&1)"
verify_status="$?"
set -e
[ "$verify_status" -eq 2 ] || fail "expected verify missing host exit 2, got $verify_status: $verify_output"
printf '%s' "$verify_output" | grep -q "DEPLOY_HOST is not set" || fail "verify missing host message: $verify_output"

set +e
preflight_output="$(SOURCE_SSH= TARGET_SSH=root@new "$ROOT_DIR/ops/migration-preflight.sh" 2>&1)"
preflight_status="$?"
set -e
[ "$preflight_status" -eq 2 ] || fail "expected migration preflight missing source exit 2, got $preflight_status: $preflight_output"
printf '%s' "$preflight_output" | grep -q "SOURCE_SSH is not set" || fail "migration preflight missing source message: $preflight_output"

set +e
cutover_output="$(SOURCE_SSH=root@old TARGET_SSH=root@new "$ROOT_DIR/ops/migrate-prod.sh" 2>&1)"
cutover_status="$?"
set -e
[ "$cutover_status" -eq 2 ] || fail "expected migrate without confirmation exit 2, got $cutover_status: $cutover_output"
printf '%s' "$cutover_output" | grep -q "CONFIRM_FINAL_CUTOVER must be yes" || fail "migration confirmation message: $cutover_output"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/ssh" <<'SSH'
#!/usr/bin/env sh
echo "ssh should not be called in dry-run tests" >&2
exit 99
SSH
chmod +x "$fake_bin/ssh"

dry_deploy_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example DEPLOY_PATH=/opt/lihan_ai "$ROOT_DIR/ops/deploy-prod.sh")"
printf '%s' "$dry_deploy_output" | grep -q "DRY RUN" || fail "deploy dry-run did not announce dry run: $dry_deploy_output"
printf '%s' "$dry_deploy_output" | grep -q "ssh root@example" || fail "deploy dry-run did not show ssh target: $dry_deploy_output"

verify_ssh_log="$tmp_dir/verify-ssh.log"
verify_stdin_log="$tmp_dir/verify-stdin.sh"
cat > "$fake_bin/ssh" <<'SSH'
#!/usr/bin/env sh
printf '%s\n' "$*" > "$FAKE_VERIFY_SSH_LOG"
cat > "$FAKE_VERIFY_STDIN_LOG"
exit 0
SSH
chmod +x "$fake_bin/ssh"

PATH="$fake_bin:$PATH" FAKE_VERIFY_SSH_LOG="$verify_ssh_log" FAKE_VERIFY_STDIN_LOG="$verify_stdin_log" DEPLOY_HOST=root@example "$ROOT_DIR/ops/verify-remote-prod.sh"
verify_ssh_command="$(cat "$verify_ssh_log")"
verify_remote_script="$(cat "$verify_stdin_log")"
printf '%s' "$verify_ssh_command" | grep -q "DEPLOY_PATH=''" || fail "verify should not force legacy DEPLOY_PATH when unset: $verify_ssh_command"
printf '%s' "$verify_ssh_command" | grep -q "DEPLOY_PATH_EXPLICIT='0'" || fail "verify should mark DEPLOY_PATH as implicit: $verify_ssh_command"
printf '%s' "$verify_remote_script" | grep -q "/opt/lihan_ai_deploy/current" || fail "verify remote script should prefer release current path: $verify_remote_script"
printf '%s' "$verify_remote_script" | grep -q "docker-compose.cpa.yml" || fail "verify remote script should support CPA overlay: $verify_remote_script"
printf '%s' "$verify_remote_script" | grep -q "docker-compose.cloudflare-tunnel.yml" || fail "verify remote script should support Tunnel overlay: $verify_remote_script"
printf '%s' "$verify_remote_script" | grep -q "ops/check-production-runtime.sh" || fail "verify remote script should reuse runtime checker: $verify_remote_script"

PATH="$fake_bin:$PATH" FAKE_VERIFY_SSH_LOG="$verify_ssh_log" FAKE_VERIFY_STDIN_LOG="$verify_stdin_log" DEPLOY_HOST=root@example DEPLOY_PATH=/custom/current "$ROOT_DIR/ops/verify-remote-prod.sh"
verify_ssh_command="$(cat "$verify_ssh_log")"
printf '%s' "$verify_ssh_command" | grep -q "DEPLOY_PATH='/custom/current'" || fail "verify should pass explicit DEPLOY_PATH: $verify_ssh_command"
printf '%s' "$verify_ssh_command" | grep -q "DEPLOY_PATH_EXPLICIT='1'" || fail "verify should mark DEPLOY_PATH as explicit: $verify_ssh_command"

dry_migration_output="$(PATH="$fake_bin:$PATH" MIGRATION_DRY_RUN=1 CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new "$ROOT_DIR/ops/migrate-prod.sh")"
printf '%s' "$dry_migration_output" | grep -q "DRY RUN" || fail "migration dry-run did not announce dry run: $dry_migration_output"
printf '%s' "$dry_migration_output" | grep -q "final dump" || fail "migration dry-run missing final dump step: $dry_migration_output"

if printf '%s\n%s\n%s' "$dry_deploy_output" "$dry_migration_output" "$deploy_output" | grep -Eiq 'sk-[A-Za-z0-9]|SESSION_SECRET|POSTGRES_PASSWORD|REDIS_PASSWORD'; then
  fail "script output contains secret-looking content"
fi

echo "prod-deploy-migration tests passed"
