# Browser E2E Runbook

Browser E2E is separate from shell E2E. Shell tests prove wrapper behavior and API probes; browser tests prove the operator-facing New API pages are reachable.

## Install

Run from WSL or Windows PowerShell:

```bash
npm install
npx playwright install chromium
```

## Local Port

New API local default:

```text
http://localhost:3100
```

Before browser E2E, check host port ownership:

```bash
bash ops/check-local-ports.sh
```

On Windows + WSL, Docker/WSL can leave `wslrelay.exe` holding an old host port after interrupted browser or API tests. If `3100` is occupied but New API is otherwise healthy, free that host port or temporarily move New API to another local port and pass the actual URL to Playwright:

```powershell
$env:NEW_API_BASE_URL="http://localhost:3102"
npm run e2e:web:new-api
Remove-Item Env:NEW_API_BASE_URL
```

## Run

```bash
npm run e2e:web:new-api
```

Default:

```bash
NEW_API_BASE_URL=http://localhost:3100
```

If `npm run e2e:web:new-api` times out but `bash ops/e2e-api-billing.sh` and WSL `curl http://localhost:<port>/api/status` succeed, treat it as a host browser networking issue first. Confirm with Windows `curl.exe http://localhost:<port>/api/status`, then rerun Playwright against the currently published Docker port.

When invoking WSL scripts from Windows PowerShell, prefer inline WSL environment variables:

```powershell
bash -lc 'NEW_API_BASE_URL=http://localhost:3102 ./ops/live-e2e-billing-from-db-token.sh test_2505081251'
```

PowerShell `$env:NEW_API_BASE_URL=...` is reliable for Windows Node/Playwright, but it is not automatically available inside WSL unless WSL environment forwarding is configured.

## Manual Web Checks After Each Feature

After a feature touching operations, billing, channels, or user-visible behavior:

1. Run `bash ops/check-local-ports.sh`.
2. Open New API at `http://localhost:3100`, or the current `NEW_API_BASE_URL` if you temporarily moved the port.
3. Confirm login still works.
4. Visit the relevant admin page for the feature.
5. Run the related wrapper command from the terminal.
6. Confirm user groups still use only `default` and `vip` for current production guidance.

Record the result in the feature `E2E Coverage Matrix` and `handoff.md`. If browser E2E is skipped, include both `Reason:` and `Rerun:` so the check can be reproduced later.

## Secrets

Do not commit Playwright auth state, screenshots, traces, or reports. `.auth/`, `test-results/`, and `playwright-report/` are ignored.
