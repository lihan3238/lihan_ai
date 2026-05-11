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

assert_text_contains() {
  text="$1"
  pattern="$2"
  label="$3"
  printf '%s' "$text" | grep -q -- "$pattern" || fail "$label missing pattern: $pattern in $text"
}

assert_text_not_contains() {
  text="$1"
  pattern="$2"
  label="$3"
  if printf '%s' "$text" | grep -q -- "$pattern"; then
    fail "$label contains forbidden pattern: $pattern in $text"
  fi
}

assert_file "docs/release-deployment-runbook.md"
assert_file "docs/zh-CN/release-deployment-runbook.md"
assert_executable "ops/deploy-release.sh"

assert_contains ".env.production.example" "DEPLOY_ROOT=/opt/lihan_ai_deploy"
assert_contains ".env.production.example" "DEPLOY_COMPOSE_PROJECT=lihan_ai"
assert_contains ".env.production.example" "DEPLOY_INCLUDE_CPA=0"
assert_contains ".env.production.example" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0"
assert_contains ".env.production.example" "RELEASE_KEEP=5"
assert_contains "ops/deploy-release.sh" "git worktree add --detach"
assert_contains "ops/deploy-release.sh" "docker compose -p"
assert_contains "ops/deploy-release.sh" "COMPOSE_PROJECT_NAME"
assert_contains "ops/deploy-release.sh" "ALLOW_NON_MAIN_PROD_DEPLOY"
assert_contains "ops/deploy-release.sh" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL"
assert_contains "ops/deploy-release.sh" "DEPLOY_INCLUDE_CPA_EXPLICIT"
assert_contains "ops/deploy-release.sh" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL_EXPLICIT"
assert_contains "ops/deploy-release.sh" "resolve_deploy_config"
assert_contains "ops/deploy-release.sh" "old_target"
assert_contains "ops/deploy-release.sh" "candidate_link"
assert_contains "ops/deploy-release.sh" "candidate_target"
assert_contains "ops/deploy-release.sh" "set_candidate_to"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$fake_bin/ssh" <<'SSH'
#!/usr/bin/env sh
echo "ssh should not be called during dry-run tests" >&2
exit 99
SSH
chmod +x "$fake_bin/ssh"

remote_defaults_env="$tmp_dir/.env.production"
cat > "$remote_defaults_env" <<'ENV'
DEPLOY_COMPOSE_PROJECT=lihan_ai_env
DEPLOY_INCLUDE_CPA=1
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
ENV

set +e
missing_output="$(DEPLOY_HOST= "$ROOT_DIR/ops/deploy-release.sh" prepare 2>&1)"
missing_status="$?"
set -e
[ "$missing_status" -eq 2 ] || fail "missing host should exit 2, got $missing_status: $missing_output"
printf '%s' "$missing_output" | grep -q "DEPLOY_HOST is not set" || fail "missing host message was unclear: $missing_output"

set +e
bad_ref_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example DEPLOY_REF=feature/test "$ROOT_DIR/ops/deploy-release.sh" prepare 2>&1)"
bad_ref_status="$?"
set -e
[ "$bad_ref_status" -eq 2 ] || fail "non-main production prepare should fail, got $bad_ref_status: $bad_ref_output"
printf '%s' "$bad_ref_output" | grep -q "production release deploy requires DEPLOY_REF=main" || fail "non-main guard message was unclear: $bad_ref_output"

prepare_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-release.sh" prepare)"
assert_text_contains "$prepare_output" "DRY RUN release prepare" "prepare dry-run"
assert_text_contains "$prepare_output" "/opt/lihan_ai_deploy/repo.git" "prepare dry-run"
assert_text_contains "$prepare_output" "git worktree add --detach" "prepare dry-run"
assert_text_contains "$prepare_output" "candidate -> releases/<timestamp>-<sha>" "prepare dry-run"
assert_text_contains "$prepare_output" "docker compose -p lihan_ai" "prepare dry-run"
assert_text_contains "$prepare_output" "ops/preflight.sh" "prepare dry-run"

prepare_cpa_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example DEPLOY_INCLUDE_CPA=1 "$ROOT_DIR/ops/deploy-release.sh" prepare)"
printf '%s' "$prepare_cpa_output" | grep -q "docker-compose.cpa.yml" || fail "CPA dry-run missing CPA compose file: $prepare_cpa_output"

prepare_tunnel_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 "$ROOT_DIR/ops/deploy-release.sh" prepare)"
printf '%s' "$prepare_tunnel_output" | grep -q "docker-compose.cloudflare-tunnel.yml" || fail "tunnel dry-run missing tunnel compose file: $prepare_tunnel_output"

smoke_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example RELEASE_ID=20260510T000000Z-deadbee "$ROOT_DIR/ops/deploy-release.sh" smoke)"
printf '%s' "$smoke_output" | grep -q "DRY RUN release smoke" || fail "smoke dry-run missing title: $smoke_output"
printf '%s' "$smoke_output" | grep -q "ops/drill-restore-stack.sh" || fail "smoke dry-run missing stack drill: $smoke_output"
if printf '%s' "$smoke_output" | grep -q "switch current"; then
  fail "smoke dry-run should not switch current: $smoke_output"
fi

smoke_candidate_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-release.sh" smoke)"
printf '%s' "$smoke_candidate_output" | grep -q "cd /opt/lihan_ai_deploy/candidate" || fail "smoke dry-run should default to prepared candidate: $smoke_candidate_output"
printf '%s' "$smoke_candidate_output" | grep -q "prepared candidate release" || fail "smoke dry-run should explain candidate default: $smoke_candidate_output"

promote_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example RELEASE_ID=20260510T000000Z-deadbee "$ROOT_DIR/ops/deploy-release.sh" promote)"
printf '%s' "$promote_output" | grep -q "DRY RUN release promote" || fail "promote dry-run missing title: $promote_output"
printf '%s' "$promote_output" | grep -q "backup-postgres.sh" || fail "promote dry-run missing backup: $promote_output"
printf '%s' "$promote_output" | grep -q "current -> releases/20260510T000000Z-deadbee" || fail "promote dry-run missing current switch: $promote_output"
printf '%s' "$promote_output" | grep -q "up -d --remove-orphans" || fail "promote dry-run missing compose up: $promote_output"
printf '%s' "$promote_output" | grep -q "check-production-runtime.sh" || fail "promote dry-run missing runtime check: $promote_output"

promote_tunnel_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example RELEASE_ID=20260510T000000Z-deadbee DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 "$ROOT_DIR/ops/deploy-release.sh" promote)"
assert_text_contains "$promote_tunnel_output" "--scale caddy=0" "tunnel promote dry-run"
assert_text_contains "$promote_tunnel_output" "docker-compose.cloudflare-tunnel.yml" "tunnel promote dry-run"

promote_remote_env_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example DEPLOY_ENV_FILE="$remote_defaults_env" RELEASE_ID=20260510T000000Z-deadbee "$ROOT_DIR/ops/deploy-release.sh" promote)"
assert_text_contains "$promote_remote_env_output" "DEPLOY_COMPOSE_PROJECT=lihan_ai_env (remote env default)" "remote-env promote dry-run"
assert_text_contains "$promote_remote_env_output" "DEPLOY_INCLUDE_CPA=1 (remote env default)" "remote-env promote dry-run"
assert_text_contains "$promote_remote_env_output" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 (remote env default)" "remote-env promote dry-run"
assert_text_contains "$promote_remote_env_output" "docker-compose.cpa.yml" "remote-env promote dry-run"
assert_text_contains "$promote_remote_env_output" "docker-compose.cloudflare-tunnel.yml" "remote-env promote dry-run"
assert_text_contains "$promote_remote_env_output" "--scale caddy=0" "remote-env promote dry-run"

promote_explicit_caddy_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example DEPLOY_ENV_FILE="$remote_defaults_env" RELEASE_ID=20260510T000000Z-deadbee DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0 "$ROOT_DIR/ops/deploy-release.sh" promote)"
assert_text_contains "$promote_explicit_caddy_output" "DEPLOY_INCLUDE_CPA=1 (remote env default)" "explicit-caddy promote dry-run"
assert_text_contains "$promote_explicit_caddy_output" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0 (explicit env)" "explicit-caddy promote dry-run"
assert_text_contains "$promote_explicit_caddy_output" "docker-compose.cpa.yml" "explicit-caddy promote dry-run"
assert_text_not_contains "$promote_explicit_caddy_output" "docker-compose.cloudflare-tunnel.yml" "explicit-caddy promote dry-run"
assert_text_not_contains "$promote_explicit_caddy_output" "--scale caddy=0" "explicit-caddy promote dry-run"

promote_candidate_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-release.sh" promote)"
printf '%s' "$promote_candidate_output" | grep -q "current -> candidate" || fail "promote dry-run should default to candidate: $promote_candidate_output"
printf '%s' "$promote_candidate_output" | grep -q "clear candidate after successful promote" || fail "promote dry-run should document candidate cleanup: $promote_candidate_output"

rollback_output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-release.sh" rollback)"
printf '%s' "$rollback_output" | grep -q "DRY RUN release rollback" || fail "rollback dry-run missing title: $rollback_output"
printf '%s' "$rollback_output" | grep -q "current -> previous" || fail "rollback dry-run missing previous switch: $rollback_output"

for command in bootstrap list current cleanup; do
  output="$(PATH="$fake_bin:$PATH" DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-release.sh" "$command")"
  printf '%s' "$output" | grep -q "DRY RUN release $command" || fail "$command dry-run missing title: $output"
done

ssh_log="$tmp_dir/ssh.log"
cat > "$fake_bin/ssh" <<'SSH'
#!/usr/bin/env sh
printf '%s\n' "$*" > "$FAKE_SSH_LOG"
cat >/dev/null
exit 0
SSH
chmod +x "$fake_bin/ssh"

PATH="$fake_bin:$PATH" FAKE_SSH_LOG="$ssh_log" DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-release.sh" list
ssh_command="$(cat "$ssh_log")"
assert_text_contains "$ssh_command" "DEPLOY_INCLUDE_CPA=''" "ssh command for implicit CPA"
assert_text_contains "$ssh_command" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=''" "ssh command for implicit tunnel"
assert_text_contains "$ssh_command" "DEPLOY_INCLUDE_CPA_EXPLICIT='0'" "ssh command for implicit CPA"
assert_text_contains "$ssh_command" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL_EXPLICIT='0'" "ssh command for implicit tunnel"

PATH="$fake_bin:$PATH" FAKE_SSH_LOG="$ssh_log" DEPLOY_HOST=root@example DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0 "$ROOT_DIR/ops/deploy-release.sh" list
ssh_command="$(cat "$ssh_log")"
assert_text_contains "$ssh_command" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL='0'" "ssh command for explicit tunnel"
assert_text_contains "$ssh_command" "DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL_EXPLICIT='1'" "ssh command for explicit tunnel"

echo "release deploy tests passed"
