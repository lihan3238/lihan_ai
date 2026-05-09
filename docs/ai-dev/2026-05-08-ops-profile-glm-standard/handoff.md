# Handoff

## Current State
GLM standard ops profile work is implemented in the wrapper layer.

## Important Context
The validator is intentionally read-only. It may warn about missing users, tokens, subscriptions, or `NEW_API_TEST_TOKEN`, but the core failure condition is missing enabled channel ability for the profile group/model.

## Verification
- `bash ops/ai-dev-check.sh docs/ai-dev/2026-05-08-ops-profile-glm-standard`
- `bash tests/ops-profile.test.sh`
- `bash tests/ai-dev-check.test.sh`
- `bash tests/wrapper-infra.test.sh`
- `bash tests/e2e-api-billing.test.sh`
- `bash ops/preflight.sh`
- `./scripts/verify-repo.ps1`
- `bash -lc 'for f in ops/*.sh tests/*.sh; do bash -n "$f" || exit 1; done'`
- `docker compose --env-file .env.example config`
- `docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.dev.yml config`
- `docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local-build.yml config`
- `git diff --check`

## Remaining Work
The live local command `bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json` currently reports `FAIL enabled channels` because the database does not have an enabled `standard` + `glm-5.1` channel ability. Configure that in the New API admin console before treating this profile as satisfied.

Full `ops/production-gate.sh` was not run because it requires `NEW_API_TEST_TOKEN`, `CONFIG_SNAPSHOT_GPG_RECIPIENT`, and live upstream quota.

## Risks
The payment-option check is heuristic because New API option keys can change upstream. Treat payment warnings as prompts for admin-console review, not proof of enabled automatic payment.
