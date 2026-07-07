#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/dev-gate.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
log_file="$tmp_dir/dev-gate.log"
feature_dir="$tmp_dir/feature"
mkdir -p "$fake_bin" "$feature_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$fake_bin/bash" <<'BASH'
#!/usr/bin/env sh
log="${DEV_GATE_TEST_LOG:?}"
printf 'bash %s\n' "$*" >> "$log"
case "$*" in
  "-n "*)
    exit 0
    ;;
  *".env.production"*|*"production-gate.sh"*|*"deploy-release.sh"*)
    echo "forbidden production command: bash $*" >&2
    exit 92
    ;;
  *"tests/"*|*"ops/feature-completion-check.sh "*|*"ops/ai-dev-check.sh "*)
    exit 0
    ;;
esac
exit 0
BASH
chmod +x "$fake_bin/bash"

cat > "$fake_bin/docker" <<'DOCKER'
#!/usr/bin/env sh
printf 'docker %s\n' "$*" >> "$DEV_GATE_TEST_LOG"
case "$*" in
  *"--env-file .env.example"*" config"*) exit 0 ;;
  *"--env-file .env.production.example"*" config"*) exit 0 ;;
  *".env.production "*) echo "forbidden production env" >&2; exit 94 ;;
esac
echo "unexpected docker args: $*" >&2
exit 95
DOCKER
chmod +x "$fake_bin/docker"

cat > "$fake_bin/git" <<'GIT'
#!/usr/bin/env sh
printf 'git %s\n' "$*" >> "$DEV_GATE_TEST_LOG"
case "$*" in
  "diff --check") exit 0 ;;
esac
echo "unexpected git args: $*" >&2
exit 96
GIT
chmod +x "$fake_bin/git"

: > "$log_file"
PATH="$fake_bin:$PATH" DEV_GATE_TEST_LOG="$log_file" "$SCRIPT" "$feature_dir"

grep -Eq "bash -n .*ops/.*\\.sh.*scripts/.*\\.sh.*tests/.*\\.test\\.sh" "$log_file" || fail "dev gate did not run shell syntax check"
grep -q "bash tests/.*\\.test\\.sh" "$log_file" || fail "dev gate did not run shell tests"
grep -q "bash scripts/verify-repo.sh --skip-docker" "$log_file" || fail "dev gate did not run shell repo verifier"
grep -q "git diff --check" "$log_file" || fail "dev gate did not run whitespace check"
grep -q "docker compose --env-file .env.production.example" "$log_file" || fail "dev gate did not render production compose"
grep -q "bash ops/feature-completion-check.sh $feature_dir" "$log_file" || fail "dev gate did not run feature completion check"

if grep -Eq 'NEW_API_TEST_TOKEN|CONFIG_SNAPSHOT_GPG_RECIPIENT|^bash ops/production-gate\.sh($| )|^bash ops/deploy-release\.sh($| )|\.env.production([^.]|$)' "$log_file"; then
  fail "dev gate invoked secret/live-production path: $(cat "$log_file")"
fi
if grep -Eq 'powershell|pwsh|verify-repo\.ps1' "$log_file"; then
  fail "dev gate should not invoke PowerShell verifier: $(cat "$log_file")"
fi

: > "$log_file"
PATH="$fake_bin:$PATH" DEV_GATE_TEST_LOG="$log_file" "$SCRIPT"
if grep -q "^bash ops/feature-completion-check.sh" "$log_file"; then
  fail "dev gate should only run feature completion check when feature dir is provided"
fi
grep -q "bash scripts/verify-repo.sh --skip-docker" "$log_file" || fail "dev gate did not run shell repo verifier without feature dir"

echo "dev gate tests passed"
