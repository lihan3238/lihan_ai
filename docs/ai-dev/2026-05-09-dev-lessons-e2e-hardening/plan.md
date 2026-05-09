# Plan

## Approach
Use TDD for the two new scripts. Add deterministic tests with fake `docker` and fake E2E commands, then implement minimal POSIX shell scripts. Update docs and gates after the script behavior is covered.

## Files
- Add `ops/check-local-ports.sh`.
- Add `ops/live-e2e-billing-from-db-token.sh`.
- Add `tests/check-local-ports.test.sh`.
- Add `tests/live-e2e-token-wrapper.test.sh`.
- Add `docs/development-lessons.md`.
- Add `docs/e2e-strategy.md`.
- Add `docs/manual-web-test-runbook.md`.
- Update `README.md`, `docs/development-workflow.md`, `docs/templates/ai-dev/handoff.md`, `docs/operations-runbook.md`, `tests/wrapper-infra.test.sh`, `scripts/verify-repo.ps1`, `.env.example`, and `ops/production-gate.sh`.

## Compatibility
No API, database schema, Docker service, or New API source changes. `.env` remains untracked and unchanged. `.env.example` may move Kuma's example host port from `3001` to `3011` to avoid the observed local conflict.

## Rollback
Revert the commit. Since the change is wrapper/docs only, rollback does not touch runtime state or database data.

## Verification
- `bash tests/check-local-ports.test.sh`
- `bash tests/live-e2e-token-wrapper.test.sh`
- `bash tests/wrapper-infra.test.sh`
- `bash tests/spec-kit-init.test.sh`
- `bash tests/e2e-api-billing.test.sh`
- `bash tests/channel-health-advisor.test.sh`
- `bash tests/ops-profile.test.sh`
- `bash tests/ai-dev-check.test.sh`
- `bash ops/preflight.sh`
- `./scripts/verify-repo.ps1`
- `git diff --check`
- Optional live: `bash ops/check-local-ports.sh`
- Optional live billing: `bash ops/live-e2e-billing-from-db-token.sh test_2505081251`
