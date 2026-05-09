# Handoff

## Current State
The production deployment and no-loss migration kit is being implemented as a wrapper layer around upstream New API. It adds production/edge compose files, SSH deployment scripts, restic backup, migration scripts, tests, and runbooks.

## Important Context
New API core source remains untouched. Production origin uses `.env.production`; local development still uses `.env`. Edge nodes are stateless and should not contain database volumes or upstream API keys.

## Verification
Local verification run:
- `bash tests/prod-deploy-migration.test.sh`
- `bash tests/wrapper-infra.test.sh`
- `bash tests/ai-dev-check.test.sh`
- `bash tests/spec-kit-init.test.sh`
- `bash tests/channel-health-advisor.test.sh`
- `bash tests/live-e2e-token-wrapper.test.sh`
- `bash tests/check-local-ports.test.sh`
- `bash tests/browser-e2e-scaffold.test.sh`
- `bash tests/e2e-api-billing.test.sh`
- `bash tests/ops-profile.test.sh`
- `bash ops/ai-dev-check.sh docs/ai-dev/2026-05-10-prod-deploy-migration-kit`
- `docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.prod.yml config`
- `docker compose --env-file .env.production.example -f docker-compose.edge.yml config`
- `bash ops/preflight.sh`
- `./scripts/verify-repo.ps1`
- `git diff --check`

## Remaining Work
Real remote deployment, restic upload, browser checks against a public domain, and final migration require server credentials and must be run deliberately by the operator.

## Risks
Final migration is not zero downtime. The final dump must happen after stopping New API writes on the source. Restic recovery depends on preserving `RESTIC_PASSWORD` outside the production server.
