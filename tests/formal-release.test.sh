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
  grep -q -- "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_text_contains() {
  text="$1"
  pattern="$2"
  label="$3"
  printf '%s' "$text" | grep -q -- "$pattern" || fail "$label missing pattern: $pattern"
}

assert_executable "ops/relayctl.sh"
assert_executable "ops/release-readiness.sh"
assert_file "docs/user-quickstart.md"
assert_file "docs/user-guide.md"
assert_file "docs/zh-CN/user-quickstart.md"
assert_file "docs/zh-CN/user-guide.md"
assert_file "docs/maintainer-release-runbook.md"
assert_file "CONTRIBUTING.md"
assert_file "SECURITY.md"

status_output="$(RELAYCTL_DRY_RUN=1 ENV_FILE=.env.production "$ROOT_DIR/ops/relayctl.sh" status)"
assert_text_contains "$status_output" "ENV_FILE=.env.production bash ops/check-production-runtime.sh" "relayctl status"

maintain_output="$(RELAYCTL_DRY_RUN=1 ENV_FILE=.env.production "$ROOT_DIR/ops/relayctl.sh" maintain)"
assert_text_contains "$maintain_output" "ENV_FILE=.env.production bash ops/backup-cron.sh" "relayctl maintain"
assert_text_contains "$maintain_output" "ENV_FILE=.env.production bash ops/prune-runtime-storage.sh all" "relayctl maintain"
assert_text_contains "$maintain_output" "ENV_FILE=.env.production bash ops/check-production-runtime.sh" "relayctl maintain"

deploy_output="$(RELAYCTL_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/relayctl.sh" deploy-prepare)"
assert_text_contains "$deploy_output" "bash ops/deploy-release.sh prepare" "relayctl deploy prepare"

promote_output="$(RELAYCTL_DRY_RUN=1 DEPLOY_HOST=root@example "$ROOT_DIR/ops/relayctl.sh" deploy-promote)"
assert_text_contains "$promote_output" "bash ops/deploy-release.sh promote" "relayctl deploy promote"

e2e_output="$(RELAYCTL_DRY_RUN=1 "$ROOT_DIR/ops/relayctl.sh" local-e2e)"
assert_text_contains "$e2e_output" "bash ops/local-new-api-e2e.sh" "relayctl local e2e"

readiness_output="$(RELEASE_READINESS_DRY_RUN=1 SKIP_LOCAL_E2E=0 "$ROOT_DIR/ops/release-readiness.sh")"
assert_text_contains "$readiness_output" "bash ops/pre-commit.sh" "release readiness"
assert_text_contains "$readiness_output" "bash ops/dev-gate.sh" "release readiness"
assert_text_contains "$readiness_output" "tracked runtime artifact scan" "release readiness"
assert_text_contains "$readiness_output" "sensitive pattern scan" "release readiness"
assert_text_contains "$readiness_output" "bash ops/local-new-api-e2e.sh" "release readiness"

skip_e2e_output="$(RELEASE_READINESS_DRY_RUN=1 SKIP_LOCAL_E2E=1 "$ROOT_DIR/ops/release-readiness.sh")"
assert_text_contains "$skip_e2e_output" "SKIP local New API E2E" "release readiness skip e2e"

assert_contains "README.md" "ops/relayctl.sh"
assert_contains "README.md" "docs/user-quickstart.md"
assert_contains "README.md" "CONTRIBUTING.md"
assert_contains "README.zh-CN.md" "ops/relayctl.sh"
assert_contains "README.zh-CN.md" "docs/zh-CN/user-quickstart.md"
assert_contains "README.zh-CN.md" "CONTRIBUTING.md"
assert_contains "docs/i18n-map.md" "docs/zh-CN/user-quickstart.md"
assert_contains ".github/pull_request_template.md" "Community PR boundary"
assert_contains "CONTRIBUTING.md" "No production secrets"
assert_contains "SECURITY.md" "Do not open public issues for secrets"

echo "formal release tests passed"
