# Handoff

## How To Use And Test

- Read `docs/new-api-small-circle-launch-runbook.md`.
- Configure station quota, packages, `default` / `vip`, and manual activation in New API.
- Upstream New API `v1.0.0-rc.5` includes the dropdown fix, so keep production on `calciumion/new-api:latest` with `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0` after local E2E passes. Use the pinned `lihan3238/new-api` commit `f80e8ea6` only as a rollback path if official latest fails the same admin E2E.
- Verify admin frontend actions:

```bash
NEW_API_BASE_URL=https://api.lihan3238.com \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
bash ops/check-new-api-admin-frontend.sh
```

## E2E Results

- Automated docs/script contract: pending final verification.
- Live admin frontend E2E: skipped. Reason: requires production admin credentials; Rerun: use the command above.
- Live billing E2E: skipped. Reason: requires live token and consumes quota; Rerun: `NEW_API_TEST_TOKEN=... bash ops/e2e-api-billing.sh`.

## Documentation Updated

- Launch runbook in English and Chinese.
- README, quick reference, and browser E2E runbook.
- Feature docs for plan/handoff traceability.

## Residual Risk

- Keep the local-build toggle documented as a rollback path, but default operational guidance now points at official New API `v1.0.0-rc.5`.
- Subscription reset behavior must be validated in the live New API admin console before selling packages.
