# Handoff

## Current State
Repository audit finished the first cleanup pass after Spec Kit preparation.

## Important Context
Use repo-native AI development workflow as active standard. Official GitHub Spec Kit remains sandbox-only until reviewed.

Production gate now self-checks the AI development gate and accepts `AI_DEV_FEATURE_DIR` for validating a planned feature directory. Local development port defaults are aligned on host port `3100`; New API still listens on container port `3000`.

## Verification
- `bash ops/ai-dev-check.sh docs/ai-dev/2026-05-08-repo-workflow-audit`
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
Live `ops/e2e-api-billing.sh` and full `ops/production-gate.sh` were not run in this audit pass because they require a real test token, GPG recipient, and live upstream quota.

## Risks
Avoid broad refactors without failing tests or concrete conflict evidence. Do not run `specify init --here` until the sandbox review in `docs/spec-kit-integration-runbook.md` is complete.
