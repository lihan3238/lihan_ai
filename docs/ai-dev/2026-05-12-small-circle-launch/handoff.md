# Handoff

## How To Use And Test

- Read `docs/new-api-small-circle-launch-runbook.md`.
- Configure station quota, packages, `default` / `vip`, and manual activation in New API.
- While upstream official image lacks the dropdown fix, keep `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` in production env so release deploys build from the pinned `lihan3238/new-api` commit `5741c359`.
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

- Official New API image may still lack the dropdown `onSelect` fix until upstream PR #4787 lands in a published image; use the local build toggle only during that window.
- Subscription reset behavior must be validated in the live New API admin console before selling packages.
