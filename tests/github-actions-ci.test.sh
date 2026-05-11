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

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -q "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

workflow=".github/workflows/ci.yml"

assert_file "$workflow"
assert_contains "$workflow" "pull_request:"
assert_contains "$workflow" "branches:"
assert_contains "$workflow" "main"
assert_contains "$workflow" "submodules: recursive"
assert_contains "$workflow" "git diff --check"
assert_contains "$workflow" "find ops tests"
assert_contains "$workflow" "tests/\\*.test.sh"
assert_contains "$workflow" "AI dev docs"
assert_contains "$workflow" "docs/ai-dev/\\*"
assert_contains "$workflow" "ops/ai-dev-check.sh"
assert_contains "$workflow" "docker compose --env-file .env.example"
assert_contains "$workflow" "docker-compose.cpa.yml"
assert_contains "$workflow" "docker-compose.cpa.ui.yml"
assert_contains "$workflow" "docker-compose.kuma.ui.yml"
assert_contains "$workflow" "docker-compose.ops-dashboard.yml"
assert_contains "$workflow" "docker-compose.edge.yml"
assert_contains "$workflow" "verify-repo.ps1 -SkipDocker"
assert_not_contains "$workflow" "production-gate.sh"
assert_not_contains "$workflow" "NEW_API_TEST_TOKEN"
assert_not_contains "$workflow" "CONFIG_SNAPSHOT_GPG_RECIPIENT"
assert_not_contains "$workflow" "DEPLOY_HOST"

echo "github actions ci tests passed"
