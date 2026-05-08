#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 docs/ai-dev/<YYYY-MM-DD-topic>" >&2
  exit 1
fi

feature_dir="$1"
fail_count=0

fail() {
  echo "FAIL: $*" >&2
  fail_count=$((fail_count + 1))
}

if [ ! -d "$feature_dir" ]; then
  echo "feature directory not found: $feature_dir" >&2
  exit 1
fi

required_files="research.md spec.md plan.md tasks.md handoff.md"

for file in $required_files; do
  path="$feature_dir/$file"
  if [ ! -f "$path" ]; then
    fail "missing required file: $file"
    continue
  fi

  if [ ! -s "$path" ]; then
    fail "$file is empty"
  fi

  if grep -Eiq '\b(TBD|TODO|FIXME)\b|待定|占位|稍后补|未定' "$path"; then
    fail "$file contains forbidden placeholder"
  fi

  if ! grep -Eq '^# |^## ' "$path"; then
    fail "$file must contain markdown headings"
  fi
done

if [ -f "$feature_dir/tasks.md" ] && ! grep -q '^Approved for implementation: yes$' "$feature_dir/tasks.md"; then
  fail "tasks.md must contain: Approved for implementation: yes"
fi

if [ "$fail_count" -ne 0 ]; then
  echo "ai-dev check failed: $fail_count issue(s)" >&2
  exit 1
fi

echo "ai-dev check passed: $feature_dir"
