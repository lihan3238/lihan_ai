#!/usr/bin/env sh
set -eu

usage() {
  echo "usage: $0 docs/ai-dev/<YYYY-MM-DD-topic>" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
feature_dir="$1"
fail_count=0

fail() {
  echo "FAIL: $*" >&2
  fail_count=$((fail_count + 1))
}

require_section() {
  file="$1"
  heading="$2"
  label="$3"

  path="$feature_dir/$file"
  if ! grep -q "^## $heading[[:space:]]*$" "$path"; then
    fail "$file missing required section: $heading"
    return
  fi

  if ! awk -v heading="## $heading" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "" && line !~ /^\|[[:space:]-]+\|?$/) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$path"; then
    fail "$file section is blank: $label"
  fi
}

check_skipped_entries() {
  file="$1"
  path="$feature_dir/$file"

  if ! awk '
    {
      line = tolower($0)
      if (line ~ /skipped/ && (line !~ /reason:/ || line !~ /rerun:/)) {
        print FILENAME ":" FNR ": " $0
        bad = 1
      }
    }
    END { exit bad ? 1 : 0 }
  ' "$path"; then
    fail "$file skipped E2E entries must include Reason: and Rerun:"
  fi
}

if [ ! -d "$feature_dir" ]; then
  echo "feature directory not found: $feature_dir" >&2
  exit 1
fi

bash "$ROOT_DIR/ops/ai-dev-check.sh" "$feature_dir"

require_section "plan.md" "Change Impact" "change impact"
require_section "plan.md" "E2E Coverage Matrix" "E2E coverage matrix"
require_section "plan.md" "Documentation Impact" "documentation impact"
require_section "plan.md" "Usage/Test Guide" "usage/test guide"

require_section "handoff.md" "How To Use And Test" "how to use and test"
require_section "handoff.md" "E2E Results" "E2E results"
require_section "handoff.md" "Documentation Updated" "documentation updated"
require_section "handoff.md" "Residual Risk" "residual risk"

check_skipped_entries "plan.md"
check_skipped_entries "handoff.md"

if [ "$fail_count" -ne 0 ]; then
  echo "feature completion check failed: $fail_count issue(s)" >&2
  exit 1
fi

echo "feature completion check passed: $feature_dir"
