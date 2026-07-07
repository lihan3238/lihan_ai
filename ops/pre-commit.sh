#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

run() {
  echo "+ $*"
  "$@"
}

cd "$ROOT_DIR"

run git diff --check
run bash -n ops/*.sh scripts/*.sh tests/*.test.sh
run bash tests/github-actions-ci.test.sh
run bash tests/ci-cd-pipeline.test.sh
run bash tests/browser-e2e-scaffold.test.sh
run bash tests/local-new-api-e2e.test.sh
run bash tests/formal-release.test.sh
run bash tests/new-api-small-circle-launch.test.sh
run bash tests/new-api-small-circle-promo-ops.test.sh
run bash tests/docs-i18n.test.sh

echo "pre-commit gate passed"
