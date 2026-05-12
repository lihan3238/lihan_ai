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

For the standard local completion gate, run the wrapper instead of typing credentials manually:

```bash
bash ops/local-new-api-e2e.sh
```

The wrapper only accepts `localhost` / `127.0.0.1` targets. It resets a local test admin account
(`codex_e2e_admin` / `CodexLocal123!`) in the restored local PostgreSQL container, then runs the
browser smoke and admin user-management E2E paths. It defaults to `ENV_FILE=.env.local-restore`
and refuses production env files. Do not use it against production.

## Restored Stack Acceptance

Use this when validating a backup restore or an upstream New API image change locally:

```bash
docker pull calciumion/new-api:latest
docker compose --env-file .env.local-restore -f docker-compose.yml -f docker-compose.dev.yml up -d postgres redis
ENV_FILE=.env.local-restore bash ops/restore-postgres.sh backups/postgres/<dump>.dump
docker compose --env-file .env.local-restore -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
bash ops/local-new-api-e2e.sh
```

Keep `.env.local-restore` on `NEW_API_IMAGE=calciumion/new-api:latest` and
`DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0` for the official-image acceptance path.

Admin user-management E2E for package operations:

```bash
NEW_API_BASE_URL=https://api.lihan3238.com \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
npm run e2e:web:new-api-admin
```

This verifies the Users page row menu can open `Manage Bindings` and `Manage Subscriptions`, which are required for
manual subscription activation in the small circle launch flow.

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
