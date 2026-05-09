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
  grep -q "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_file "docs/git-branching-runbook.md"
assert_file "docs/zh-CN/git-branching-runbook.md"
assert_file "docs/ai-dev/2026-05-10-git-branching-policy/research.md"
assert_file "docs/ai-dev/2026-05-10-git-branching-policy/spec.md"
assert_file "docs/ai-dev/2026-05-10-git-branching-policy/plan.md"
assert_file "docs/ai-dev/2026-05-10-git-branching-policy/tasks.md"
assert_file "docs/ai-dev/2026-05-10-git-branching-policy/handoff.md"

assert_contains "docs/git-branching-runbook.md" "main = production"
assert_contains "docs/git-branching-runbook.md" "codex/<topic>"
assert_contains "docs/git-branching-runbook.md" "hotfix/<topic>"
assert_contains "docs/git-branching-runbook.md" "ALLOW_NON_MAIN_PROD_DEPLOY=1"
assert_contains "docs/zh-CN/git-branching-runbook.md" "main = production"
assert_contains "docs/zh-CN/git-branching-runbook.md" "codex/<topic>"
assert_contains "docs/i18n-map.md" "docs/git-branching-runbook.md"
assert_contains "docs/i18n-map.md" "docs/zh-CN/git-branching-runbook.md"
assert_contains ".env.production.example" "DEPLOY_REF=main"
assert_contains ".env.production.example" "ALLOW_NON_MAIN_PROD_DEPLOY=0"
assert_contains "ops/deploy-prod.sh" "ALLOW_NON_MAIN_PROD_DEPLOY"
assert_contains "ops/production-gate.sh" "tests/git-branching-policy.test.sh"

set +e
blocked_output="$(DEPLOY_ENV=production DEPLOY_REF=codex/test DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-prod.sh" 2>&1)"
blocked_status="$?"
set -e
[ "$blocked_status" -eq 2 ] || fail "expected non-main production deploy to exit 2, got $blocked_status: $blocked_output"
printf '%s' "$blocked_output" | grep -q "production deploy requires DEPLOY_REF=main" || fail "missing non-main production deploy failure message: $blocked_output"

main_output="$(DEPLOY_ENV=production DEPLOY_REF=main DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-prod.sh")"
printf '%s' "$main_output" | grep -q "DRY RUN deploy to root@example" || fail "main dry-run did not pass: $main_output"

override_output="$(ALLOW_NON_MAIN_PROD_DEPLOY=1 DEPLOY_ENV=production DEPLOY_REF=codex/test DEPLOY_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/deploy-prod.sh" 2>&1)"
printf '%s' "$override_output" | grep -q "WARN non-main production deploy override" || fail "override dry-run missing warning: $override_output"
printf '%s' "$override_output" | grep -q "DRY RUN deploy to root@example" || fail "override dry-run did not continue: $override_output"

if printf '%s\n%s\n%s' "$blocked_output" "$main_output" "$override_output" | grep -Eiq 'sk-[A-Za-z0-9]|SESSION_SECRET|POSTGRES_PASSWORD|REDIS_PASSWORD|RESTIC_PASSWORD'; then
  fail "branch policy output contains secret-looking content"
fi

echo "git branching policy tests passed"
