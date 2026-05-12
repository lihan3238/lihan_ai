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
  grep -F -q -- "$pattern" "$ROOT_DIR/$file" || fail "$file missing pattern: $pattern"
}

assert_not_contains() {
  file="$1"
  pattern="$2"
  if grep -F -q -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$file contains forbidden pattern: $pattern"
  fi
}

assert_file ".pre-commit-config.yaml"
assert_file "ops/pre-commit.sh"
assert_file ".github/workflows/cd.yml"

assert_contains ".pre-commit-config.yaml" "repo: local"
assert_contains ".pre-commit-config.yaml" "ops/pre-commit.sh"

assert_contains "ops/pre-commit.sh" "git diff --check"
assert_contains "ops/pre-commit.sh" "bash -n ops/*.sh tests/*.test.sh"
assert_contains "ops/pre-commit.sh" "tests/github-actions-ci.test.sh"
assert_contains "ops/pre-commit.sh" "tests/browser-e2e-scaffold.test.sh"
assert_not_contains "ops/pre-commit.sh" "npm run e2e"
assert_not_contains "ops/pre-commit.sh" "docker compose"

assert_contains ".github/workflows/ci.yml" "pull_request:"
assert_not_contains ".github/workflows/ci.yml" "PROD_DEPLOY_"
assert_not_contains ".github/workflows/ci.yml" "npm run e2e"
assert_not_contains ".github/workflows/ci.yml" "playwright test"

assert_contains ".github/workflows/cd.yml" "push:"
assert_contains ".github/workflows/cd.yml" "branches:"
assert_contains ".github/workflows/cd.yml" "main"
assert_contains ".github/workflows/cd.yml" "workflow_dispatch:"
assert_contains ".github/workflows/cd.yml" "post-merge validation"
assert_contains ".github/workflows/cd.yml" "bash ops/dev-gate.sh"
assert_contains ".github/workflows/cd.yml" "Runner compose smoke"
assert_contains ".github/workflows/cd.yml" "up -d postgres redis new-api"
assert_contains ".github/workflows/cd.yml" "curl -fsS http://127.0.0.1:3100/api/status"
assert_not_contains ".github/workflows/cd.yml" "PROD_DEPLOY_"
assert_not_contains ".github/workflows/cd.yml" "ssh"
assert_not_contains ".github/workflows/cd.yml" "deploy-release.sh"
assert_not_contains ".github/workflows/cd.yml" "promote"
assert_not_contains ".github/workflows/cd.yml" "rollback"
assert_not_contains ".github/workflows/cd.yml" "DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1"

echo "ci/cd pipeline tests passed"
