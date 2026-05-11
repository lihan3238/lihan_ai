#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${NEW_API_TEST_TOKEN:-}" ]; then
  echo "NEW_API_TEST_TOKEN is not set" >&2
  exit 2
fi

if [ -z "${CONFIG_SNAPSHOT_GPG_RECIPIENT:-}" ]; then
  echo "CONFIG_SNAPSHOT_GPG_RECIPIENT is not set" >&2
  exit 2
fi

run() {
  echo "+ $*"
  "$@"
}

cd "$ROOT_DIR"

run git diff --check
run bash -n ops/preflight.sh
run bash -n ops/backup-postgres.sh
run bash -n ops/backup-cron.sh
run bash -n ops/verify-postgres-backup.sh
run bash -n ops/restore-postgres.sh
run bash -n ops/relay-diagnostics.sh
run bash -n ops/e2e-api-billing.sh
run bash -n ops/build-local-new-api.sh
run bash -n ops/start-local-new-api.sh
run bash -n ops/export-config-snapshot.sh
run bash -n ops/drill-restore-postgres.sh
run bash -n ops/drill-restore-stack.sh
run bash -n ops/ai-dev-check.sh
run bash -n ops/validate-ops-profile.sh
run bash -n ops/check-production-runtime.sh
run bash -n ops/sync-env-template.sh
run bash -n ops/sync-cpa-upstream-assets.sh
run bash -n ops/cpa-ui.sh
run bash -n ops/bootstrap-server.sh
run bash -n ops/deploy-prod.sh
run bash -n ops/deploy-release.sh
run bash -n ops/verify-remote-prod.sh
run bash -n ops/migration-preflight.sh
run bash -n ops/migrate-prod.sh
run bash tests/backup-cron.test.sh
run bash tests/env-template-sync.test.sh
run bash tests/ai-dev-check.test.sh
run bash tests/spec-kit-init.test.sh
run bash tests/channel-health-advisor.test.sh
run bash tests/live-e2e-token-wrapper.test.sh
run bash tests/check-local-ports.test.sh
run bash tests/browser-e2e-scaffold.test.sh
run bash tests/github-actions-ci.test.sh
run bash tests/cloudflare-saas-domain.test.sh
run bash tests/cloudflare-tunnel-compose.test.sh
run bash tests/prod-deploy-migration.test.sh
run bash tests/prod-deploy-hardening.test.sh
run bash tests/release-deploy.test.sh
run bash tests/cpa-compose.test.sh
run bash tests/cpa-ui-script.test.sh
run bash tests/docs-i18n.test.sh
run bash tests/git-branching-policy.test.sh
run bash tests/e2e-api-billing.test.sh
run bash tests/wrapper-infra.test.sh
run bash tests/ops-profile.test.sh
if [ -n "${AI_DEV_FEATURE_DIR:-}" ]; then
  run bash ops/ai-dev-check.sh "$AI_DEV_FEATURE_DIR"
fi
if [ -n "${OPS_PROFILE_FILE:-}" ]; then
  run bash ops/validate-ops-profile.sh "$OPS_PROFILE_FILE"
fi
if [ -n "${OPS_HEALTH_PROFILE_FILE:-}" ]; then
  run bash ops/channel-health-advisor.sh "$OPS_HEALTH_PROFILE_FILE"
fi
run bash ops/preflight.sh
run docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml config
run docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local-build.yml config
run docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.prod.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cloudflare-tunnel.yml config
run docker compose --env-file .env.production.example -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cloudflare-tunnel.yml config
run docker compose --env-file .env.production.example -f docker-compose.edge.yml config

backup="$(bash ops/backup-postgres.sh)"
run bash ops/verify-postgres-backup.sh "$backup"
run bash ops/drill-restore-postgres.sh "$backup"
run bash ops/export-config-snapshot.sh
run bash ops/export-config-snapshot.sh --private
run bash ops/relay-diagnostics.sh
run bash ops/e2e-api-billing.sh

echo "production gate passed"
