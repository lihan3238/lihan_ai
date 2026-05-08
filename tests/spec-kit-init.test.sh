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

assert_file ".specify/integration.json"
assert_file ".specify/init-options.json"
assert_file ".specify/scripts/bash/create-new-feature.sh"
assert_file ".specify/scripts/bash/setup-plan.sh"
assert_file ".specify/scripts/bash/setup-tasks.sh"
assert_file ".specify/templates/spec-template.md"
assert_file ".specify/templates/plan-template.md"
assert_file ".specify/templates/tasks-template.md"
assert_file ".specify/memory/constitution.md"
assert_file ".agents/skills/speckit-specify/SKILL.md"
assert_file ".agents/skills/speckit-plan/SKILL.md"
assert_file ".agents/skills/speckit-tasks/SKILL.md"
assert_file ".agents/skills/speckit-implement/SKILL.md"
assert_file "AGENTS.md"

assert_contains ".specify/integration.json" '"integration": "codex"'
assert_contains ".specify/integration.json" '"skills": true'
assert_contains ".specify/init-options.json" '"speckit_version": "0.8.7"'
assert_contains "AGENTS.md" "SPECKIT START"
assert_contains ".gitignore" "^\\.agents/\\*\\*$"
assert_contains ".gitignore" "^!\\.agents/skills/\\*\\*$"

bad_agent_files="$(find "$ROOT_DIR/.agents" -mindepth 1 -type f ! -path "$ROOT_DIR/.agents/skills/*" -print)"
[ -z "$bad_agent_files" ] || fail "unexpected non-skill files under .agents: $bad_agent_files"

if grep -RIEq 'sk-[A-Za-z0-9]{20,}|(password|secret|token)[[:space:]]*=[[:space:]]*[^[:space:]]+' "$ROOT_DIR/.agents" "$ROOT_DIR/.specify"; then
  fail "secret-looking value found in generated Spec Kit assets"
fi

echo "spec-kit init tests passed"
