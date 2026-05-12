#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/feature-completion-check.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

write_feature() {
  feature="$1"
  mkdir -p "$feature"

  cat > "$feature/research.md" <<'EOF'
# Research

## Sources
- Official documentation: local workflow docs.

## Common Practice
Use a completion checklist before merge.

## Risks
Skipped live checks must be explicit.

## Decision
Use layered gates.
EOF

  cat > "$feature/spec.md" <<'EOF'
# Spec

## Goal
Strengthen feature completion gates.

## Success Criteria
- Dev gate catches missing E2E and docs handoff.
- User can test the feature from handoff instructions.

## User Acceptance Path
Run the documented dev gate and inspect the handoff.

## Scope
Workflow scripts and docs only.

## Interfaces
Shell scripts and feature docs.

## Data
No persisted production data changes.

## Failure Modes
Missing matrix entries fail before merge.
EOF

  cat > "$feature/plan.md" <<'EOF'
# Plan

## Approach
Add a no-secret local completion gate.

## Files
Update scripts, docs, and tests.

## Compatibility
No production secret or database dependency.

## Rollback
Revert the workflow scripts and docs.

## Change Impact
| Area | Impact |
| --- | --- |
| Workflow | Local feature completion gate |

## E2E Coverage Matrix
| Path | Command | Status | Evidence |
| --- | --- | --- | --- |
| Browser smoke | `NEW_API_BASE_URL=http://localhost:3100 npm run e2e:web:new-api` | skipped | Reason: docs-only planning change; Rerun: start local stack and run the command |
| API billing | `NEW_API_TEST_TOKEN=... bash ops/e2e-api-billing.sh` | skipped | Reason: requires live token; Rerun: create low-quota token and run the command |

## Documentation Impact
| Document | Update |
| --- | --- |
| `docs/development-workflow.md` | Add completion gate workflow |

## Usage/Test Guide
Run `bash ops/dev-gate.sh docs/ai-dev/example`.

## Verification
Run `bash ops/dev-gate.sh docs/ai-dev/example`.
EOF

  cat > "$feature/tasks.md" <<'EOF'
# Tasks

Approved for implementation: yes

## Implementation Tasks
- [x] Write failing tests first.
- [x] Update documentation.
- [x] Write usage instructions.
- [x] Run dev gate.

## High-Risk Stops
- [x] No production deployment.
EOF

  cat > "$feature/handoff.md" <<'EOF'
# Handoff

## Current State
Workflow gate is ready for validation.

## Important Context
No production secrets are required.

## How To Use And Test
Run `bash ops/dev-gate.sh docs/ai-dev/example`, then follow the E2E commands listed in the matrix when the affected service is available.

## E2E Results
| Path | Result |
| --- | --- |
| Browser smoke | skipped; Reason: no local stack in this test; Rerun: `NEW_API_BASE_URL=http://localhost:3100 npm run e2e:web:new-api` |

## Documentation Updated
| Document | Status |
| --- | --- |
| `docs/development-workflow.md` | updated |

## Verification
`bash ops/dev-gate.sh docs/ai-dev/example` passed in local validation.

## Remaining Work
None.

## Residual Risk
Live E2E still requires operator-provided secrets.
EOF
}

feature="$tmp_dir/feature-ok"
write_feature "$feature"
"$SCRIPT" "$feature" >/dev/null

missing_plan="$tmp_dir/missing-plan-section"
write_feature "$missing_plan"
awk 'BEGIN{drop=0} /^## E2E Coverage Matrix/{drop=1; next} /^## Documentation Impact/{drop=0} !drop{print}' "$missing_plan/plan.md" > "$missing_plan/plan.md.tmp"
mv "$missing_plan/plan.md.tmp" "$missing_plan/plan.md"
set +e
missing_output="$("$SCRIPT" "$missing_plan" 2>&1)"
missing_status="$?"
set -e
[ "$missing_status" -ne 0 ] || fail "missing E2E Coverage Matrix should fail"
printf '%s' "$missing_output" | grep -q "plan.md missing required section: E2E Coverage Matrix" || fail "missing matrix message unclear: $missing_output"

missing_handoff="$tmp_dir/missing-handoff-usage"
write_feature "$missing_handoff"
awk 'BEGIN{drop=0} /^## How To Use And Test/{drop=1; next} /^## E2E Results/{drop=0} !drop{print}' "$missing_handoff/handoff.md" > "$missing_handoff/handoff.md.tmp"
mv "$missing_handoff/handoff.md.tmp" "$missing_handoff/handoff.md"
set +e
usage_output="$("$SCRIPT" "$missing_handoff" 2>&1)"
usage_status="$?"
set -e
[ "$usage_status" -ne 0 ] || fail "missing How To Use And Test should fail"
printf '%s' "$usage_output" | grep -q "handoff.md missing required section: How To Use And Test" || fail "missing usage message unclear: $usage_output"

bad_skip="$tmp_dir/bad-skip"
write_feature "$bad_skip"
perl -0pi -e 's/skipped \| Reason: docs-only planning change; Rerun: start local stack and run the command/skipped | not available/g' "$bad_skip/plan.md"
set +e
skip_output="$("$SCRIPT" "$bad_skip" 2>&1)"
skip_status="$?"
set -e
[ "$skip_status" -ne 0 ] || fail "skipped E2E without reason and rerun should fail"
printf '%s' "$skip_output" | grep -q "skipped E2E entries must include Reason: and Rerun:" || fail "bad skipped message unclear: $skip_output"

echo "feature completion check tests passed"
