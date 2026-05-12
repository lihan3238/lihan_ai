# Small Circle Launch Configuration Plan

## Change Impact

- Documentation: New launch runbook, README links, quick reference, browser E2E guidance.
- E2E: New admin user-management Playwright spec and wrapper check script.
- Ops: Official-image-first policy with temporary `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` fallback from the `lihan3238/new-api` submodule.

## E2E Coverage Matrix

| Path | Command | Status | Notes |
| --- | --- | --- | --- |
| Admin Users actions | `NEW_API_BASE_URL=... NEW_API_ADMIN_USERNAME=... NEW_API_ADMIN_PASSWORD=... bash ops/check-new-api-admin-frontend.sh` | manual | Requires live admin credentials. |
| Local patch build | `CHECK_LOCAL_NEW_API_PATCH=1 ... bash ops/check-new-api-admin-frontend.sh` | manual | Reason: requires local patched New API dependencies and admin account; Rerun: start local stack and run command. |
| Billing/accounting | `NEW_API_TEST_TOKEN=... bash ops/e2e-api-billing.sh` | manual | Reason: consumes live quota; Rerun: create low-quota token and run command. |
| Docs contract | `bash tests/new-api-small-circle-launch.test.sh` | automated | Verifies runbook, scripts, E2E entrypoint, and wording. |

## Documentation Impact

- `docs/new-api-small-circle-launch-runbook.md`
- `docs/zh-CN/new-api-small-circle-launch-runbook.md`
- README, quick reference, browser E2E runbook, i18n map.

## Usage/Test Guide

1. Configure New API site settings and packages from the runbook.
2. Run `bash ops/check-new-api-admin-frontend.sh` with live admin credentials.
3. Keep official image unless the admin E2E fails on the official image.
4. If using the temporary custom image, record `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` and rerun the same E2E after deploy.
