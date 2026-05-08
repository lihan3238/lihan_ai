# Handoff

## Current State
Implementation complete pending commit. The feature adds wrapper scripts, tests, Playwright browser E2E scaffold, and workflow documentation for stricter E2E labeling.

## Important Context
- Do not modify `.env`.
- Do not modify `vendor/new-api`.
- Live billing E2E consumes a small amount of token quota and must be explicit.
- `@chrome` is interactive Web validation, not CI-grade browser E2E.

## Static/Script Verification
Passed:
- `bash tests/live-e2e-token-wrapper.test.sh`
- `bash tests/check-local-ports.test.sh`
- `bash tests/browser-e2e-scaffold.test.sh`
- `bash tests/wrapper-infra.test.sh`
- `bash tests/spec-kit-init.test.sh`
- `bash tests/e2e-api-billing.test.sh`
- `bash tests/ops-profile.test.sh`
- `bash tests/channel-health-advisor.test.sh`
- `bash tests/ai-dev-check.test.sh`
- `bash ops/ai-dev-check.sh docs/ai-dev/2026-05-09-dev-lessons-e2e-hardening`
- `bash ops/preflight.sh`
- `./scripts/verify-repo.ps1`
- `git diff --check`

## Live API/DB E2E
Passed with real upstream calls:

```bash
bash ops/live-e2e-billing-from-db-token.sh test_2505081251
```

Result: `pass=10 warn=1 fail=0`. The warning is the known New API behavior where a route miss may not persist a DB error log.

## Browser/Web Validation
Passed:
- `npm run e2e:web:kuma` against `http://localhost:3011`.
- `NEW_API_BASE_URL=http://localhost:3102 npm run e2e:web:new-api` against the actual currently published New API port.

Blocked on default port:
- `npm run e2e:web:new-api` against `http://localhost:3100` timed out because Windows host `wslrelay.exe` was holding `127.0.0.1:3100`, while Docker had New API published on `127.0.0.1:3102`.

## Manual Web Test Flow
After each feature:
1. Run `bash ops/check-local-ports.sh`.
2. Open New API at `http://localhost:3100`, or the current `NEW_API_BASE_URL` if the port was temporarily moved.
3. Confirm login still works.
4. Visit the related admin page.
5. Run the related wrapper command.
6. If public status is affected, open Uptime Kuma at `http://localhost:3011`.
7. Confirm public status exposes only coarse service names.

## Skipped Checks And Reasons
Skipped:
- In-app browser plugin validation. The plugin connection timed out twice; Playwright browser E2E was used as the CI-grade browser automation path.
- Production gate with private GPG snapshot. This requires `CONFIG_SNAPSHOT_GPG_RECIPIENT` and would run the heavier production sequence.

## Remaining Work
- Optional: free the stale Windows `wslrelay.exe` port holder and move New API back to `3100`.
- Optional: add authenticated UI tests once a dedicated browser test admin account and storage-state policy are agreed.

## Risks
- Port ownership detection varies across Linux/WSL/Windows Docker setups. `ops/check-local-ports.sh` now combines Docker metadata, Linux listeners, and Windows `netstat.exe` when available from WSL.
