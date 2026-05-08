#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/ops/e2e-api-billing.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -x "$SCRIPT" ] || fail "missing executable $SCRIPT"

set +e
output="$(env -u NEW_API_TEST_TOKEN NEW_API_BASE_URL="http://127.0.0.1:9" "$SCRIPT" 2>&1)"
status="$?"
set -e

[ "$status" -eq 2 ] || fail "expected exit 2 without NEW_API_TEST_TOKEN, got $status: $output"
printf '%s' "$output" | grep -q "NEW_API_TEST_TOKEN is not set" || fail "missing no-token message: $output"
printf '%s' "$output" | grep -q "API billing e2e" || fail "missing e2e banner: $output"

echo "e2e-api-billing tests passed"
