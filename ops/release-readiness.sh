#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN="${RELEASE_READINESS_DRY_RUN:-0}"
SKIP_LOCAL_E2E="${SKIP_LOCAL_E2E:-0}"
RUN_PRODUCTION_RUNTIME="${RUN_PRODUCTION_RUNTIME:-0}"
ENV_FILE="${ENV_FILE:-.env.production}"

run() {
  echo "+ $*"
  if [ "$DRY_RUN" != "1" ]; then
    "$@"
  fi
}

run_env_file() {
  echo "+ ENV_FILE=$ENV_FILE $*"
  if [ "$DRY_RUN" != "1" ]; then
    ENV_FILE="$ENV_FILE" "$@"
  fi
}

tracked_runtime_artifact_scan() {
  echo "+ tracked runtime artifact scan"
  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  matches="$(
    git ls-files |
      grep -E '(^|/)(\.env|data|logs|backups|snapshots|tmp|test-results|playwright-report|node_modules|reference_file)(/|$)|\.(dump|sql|tar|tar\.gz|zip|log)$' || true
  )"
  if [ -n "$matches" ]; then
    echo "tracked runtime artifacts found:" >&2
    printf '%s\n' "$matches" >&2
    exit 1
  fi
}

sensitive_pattern_scan() {
  echo "+ sensitive pattern scan"
  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  scan_pattern='BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|srv[0-9]{6}|72[.]60[.]124[.]21'

  matches="$(git grep -n -E "$scan_pattern" -- . \
    ':(exclude)vendor/**' \
    ':(exclude)node_modules/**' \
    ':(exclude)docs/ai-dev/**' \
    ':(exclude)test-results/**' \
    ':(exclude)playwright-report/**' \
    ':(exclude)backups/**' \
    ':(exclude)logs/**' \
    ':(exclude)snapshots/**' \
    ':(exclude)tmp/**' \
    ':(exclude)reference_file/**' \
    ':(exclude)tests/cloudflare-saas-domain.test.sh' || true)"

  if [ -n "$matches" ]; then
    echo "sensitive or private pattern found:" >&2
    printf '%s\n' "$matches" >&2
    exit 1
  fi
}

local_notes_ignore_check() {
  echo "+ local AI notes ignore check"
  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  if ! git check-ignore -q docs/ai-dev/private-note.md; then
    echo "docs/ai-dev/ must stay ignored" >&2
    exit 1
  fi
}

cd "$ROOT_DIR"

run bash ops/pre-commit.sh
run bash ops/dev-gate.sh
tracked_runtime_artifact_scan
sensitive_pattern_scan
local_notes_ignore_check

if [ "$SKIP_LOCAL_E2E" = "1" ]; then
  echo "+ SKIP local New API E2E"
else
  run bash ops/local-new-api-e2e.sh
fi

if [ "$RUN_PRODUCTION_RUNTIME" = "1" ]; then
  run_env_file bash ops/check-production-runtime.sh
fi

echo "release readiness passed"
