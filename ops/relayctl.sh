#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env.production}"
DRY_RUN="${RELAYCTL_DRY_RUN:-0}"

usage() {
  cat >&2 <<'USAGE'
usage: ops/relayctl.sh <command> [release-id]

Daily operations:
  status          Check production runtime health with ops/check-production-runtime.sh.
  preflight       Validate the selected env file with ops/preflight.sh.
  backup          Run verified PostgreSQL backup via ops/backup-cron.sh.
  maintain        Run backup, storage pruning, and runtime health check.

Release operations:
  deploy-prepare  Prepare a main-branch release candidate on the server.
  deploy-smoke    Smoke-test the prepared candidate.
  deploy-promote  Promote the prepared candidate manually.
  deploy-status   Show remote release state.
  recover         Recover a stale promote state after interrupted SSH.
  rollback        Roll back to a release id; pass the release id as the second arg.

Local checks:
  local-e2e       Run the local New API smoke and admin browser E2E.
  release-check   Run the formal release-readiness gate.

Common env:
  ENV_FILE=.env.production
  DEPLOY_HOST=<deploy-user>@<origin-host>
  DEPLOY_REF=main
  RELAYCTL_DRY_RUN=1
USAGE
}

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

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

command="$1"
release_id="${2:-}"

if [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

cd "$ROOT_DIR"

case "$command" in
  help|-h|--help)
    usage
    ;;
  status)
    run_env_file bash ops/check-production-runtime.sh
    ;;
  preflight)
    run_env_file bash ops/preflight.sh
    ;;
  backup)
    run_env_file bash ops/backup-cron.sh
    ;;
  maintain)
    run_env_file bash ops/backup-cron.sh
    run_env_file bash ops/prune-runtime-storage.sh all
    run_env_file bash ops/check-production-runtime.sh
    ;;
  deploy-prepare)
    run bash ops/deploy-release.sh prepare
    ;;
  deploy-smoke)
    run bash ops/deploy-release.sh smoke
    ;;
  deploy-promote)
    run bash ops/deploy-release.sh promote
    ;;
  deploy-status)
    run bash ops/deploy-release.sh status
    ;;
  recover)
    run bash ops/deploy-release.sh recover
    ;;
  rollback|deploy-rollback)
    if [ -z "$release_id" ]; then
      echo "rollback requires a release id" >&2
      exit 2
    fi
    run bash ops/deploy-release.sh rollback "$release_id"
    ;;
  local-e2e)
    run bash ops/local-new-api-e2e.sh
    ;;
  release-check)
    run bash ops/release-readiness.sh
    ;;
  *)
    usage
    exit 2
    ;;
esac
