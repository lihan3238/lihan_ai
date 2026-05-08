# Browser E2E Runbook

Browser E2E is separate from shell E2E. Shell E2E proves API routing, streaming, logs, and billing accounting. Browser E2E proves the operator-facing pages and public status surfaces are reachable.

## Install

Run from WSL or Windows PowerShell:

```bash
npm install
npx playwright install chromium
```

## Ports

New API local default:

```text
http://localhost:3100
```

Before browser E2E, check host port ownership:

```bash
bash ops/check-local-ports.sh
```

On Windows + WSL, Docker/WSL can leave `wslrelay.exe` holding an old host port after interrupted browser or API tests. If `3100` is occupied on the Windows host but New API is otherwise healthy, either free that host port from Windows or temporarily move New API to another local port such as `3102` and pass the actual URL to Playwright:

```powershell
$env:NEW_API_BASE_URL="http://localhost:3102"
npm run e2e:web:new-api
Remove-Item Env:NEW_API_BASE_URL
```

Uptime Kuma should not use `3001` on this machine because another Docker project already owns that host port. Use:

```env
KUMA_PORT=3011
```

```powershell
$env:KUMA_PORT="3011"
docker compose --env-file .env -f docker-compose.yml up -d uptime-kuma
```

Then open:

```text
http://localhost:3011
```

## Run

```bash
npm run e2e:web:new-api
KUMA_BASE_URL=http://localhost:3011 npm run e2e:web:kuma
```

Use these defaults unless the local ports change:

```bash
NEW_API_BASE_URL=http://localhost:3100
KUMA_BASE_URL=http://localhost:3011
```

If `npm run e2e:web:new-api` times out but `bash ops/e2e-api-billing.sh` and WSL `curl http://localhost:<port>/api/status` succeed, treat it as a host browser networking issue first. Confirm with Windows `curl.exe http://localhost:<port>/api/status`, then rerun Playwright against the currently published Docker port.

When invoking WSL scripts from Windows PowerShell, prefer inline WSL environment variables:

```powershell
bash -lc 'NEW_API_BASE_URL=http://localhost:3102 ./ops/live-e2e-billing-from-db-token.sh test_2505081251'
```

PowerShell `$env:NEW_API_BASE_URL=...` is reliable for Windows Node/Playwright, but it is not automatically available inside WSL unless WSL environment forwarding is configured.

## Manual Web Checks After Each Feature

After every feature touching operations, billing, health, or user-visible behavior:

1. Run `bash ops/check-local-ports.sh`.
2. Open New API at `http://localhost:3100`, or the current `NEW_API_BASE_URL` if you temporarily moved the port.
3. Confirm login still works.
4. Visit the relevant admin page for the feature.
5. Run the related wrapper command from the terminal.
6. If the feature affects public status, open Uptime Kuma at `http://localhost:3011`.
7. Confirm the public status page uses coarse component names only and does not expose provider names, channel IDs, balances, or internal errors.

## Secrets

Do not commit Playwright auth state, screenshots, traces, or reports. `.auth/`, `test-results/`, and `playwright-report/` are ignored.
