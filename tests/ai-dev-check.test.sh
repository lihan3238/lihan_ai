#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/ai-dev-check.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

feature="$tmp_dir/feature"
mkdir -p "$feature"

set +e
missing_output="$("$SCRIPT" "$feature" 2>&1)"
missing_status="$?"
set -e
[ "$missing_status" -eq 1 ] || fail "expected missing files exit 1, got $missing_status: $missing_output"
printf '%s' "$missing_output" | grep -q "missing required file: research.md" || fail "missing research.md message"
printf '%s' "$missing_output" | grep -q "missing required file: tasks.md" || fail "missing tasks.md message"

cat > "$feature/research.md" <<'EOF'
# Research

## Sources
- Official docs checked.

## Common Practice
Use spec-driven development.

## Risks
Skipping research causes repeated work.

## Decision
Adopt a repo-native workflow.
EOF

cat > "$feature/spec.md" <<'EOF'
# Spec

## Goal
Create a stable AI development workflow.

## Success Criteria
- The workflow gate passes.

## Scope
Local documentation and gate scripts only.

## Interfaces
Command line checks.

## Failure Modes
Missing approval blocks implementation.
EOF

cat > "$feature/plan.md" <<'EOF'
# Plan

## Approach
Add templates and a check script.

## Files
Use docs templates and ops scripts.

## Compatibility
No runtime API changes.

## Rollback
Revert the commit.

## Verification
Run shell tests.
EOF

cat > "$feature/tasks.md" <<'EOF'
# Tasks

Approved for implementation: no

- [ ] Write failing tests.
- [ ] Implement scripts.
- [ ] Run verification.
EOF

cat > "$feature/handoff.md" <<'EOF'
# Handoff

## Current State
Planning complete.

## Next Step
Run implementation after approval.
EOF

set +e
approval_output="$("$SCRIPT" "$feature" 2>&1)"
approval_status="$?"
set -e
[ "$approval_status" -eq 1 ] || fail "expected approval exit 1, got $approval_status: $approval_output"
printf '%s' "$approval_output" | grep -q "tasks.md must contain: Approved for implementation: yes" || fail "missing approval message"

sed -i 's/Approved for implementation: no/Approved for implementation: yes/' "$feature/tasks.md"
echo "TODO: replace this" >> "$feature/plan.md"

set +e
todo_output="$("$SCRIPT" "$feature" 2>&1)"
todo_status="$?"
set -e
[ "$todo_status" -eq 1 ] || fail "expected TODO exit 1, got $todo_status: $todo_output"
printf '%s' "$todo_output" | grep -q "forbidden placeholder" || fail "missing TODO placeholder message"

grep -v "TODO:" "$feature/plan.md" > "$feature/plan.clean"
mv "$feature/plan.clean" "$feature/plan.md"

"$SCRIPT" "$feature" >/tmp/ai-dev-check-pass.out
grep -q "ai-dev check passed" /tmp/ai-dev-check-pass.out || fail "missing pass message"

echo "ai-dev-check tests passed"
