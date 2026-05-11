# Operations Runbook

## First Deployment

1. Work from WSL Ubuntu 24.04 or the Linux VPS shell.
2. Run `git submodule update --init --recursive` to fetch the pinned New API source.
3. Copy `.env.production.example` to `.env.production`.
4. Replace all `CHANGE_ME` values with generated secrets.
5. Set `DOMAIN` and `ACME_EMAIL`.
6. Run `ENV_FILE=.env.production bash ops/preflight.sh`.
7. Run `docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d`.
8. Open the site, create the admin user, and configure New API from its original admin console.

Production tracks `main`. Do not deploy long-lived feature branches to the production origin; follow `docs/git-branching-runbook.md`.

## New API Source Management

The deployment uses the official New API Docker image by default, while `vendor/new-api` keeps the upstream source available for audit, diffs, and future customization. Do not add local business logic until the relevant upstream implementation has been checked first. To update the pinned upstream source:

```bash
git -C vendor/new-api fetch origin
git -C vendor/new-api checkout origin/main
git add vendor/new-api
git commit -m "chore: update new-api upstream"
```

Only switch `docker-compose.yml` from the official image to a locally built image after custom changes have a separate test and rollback plan.

For wrapper-level local image builds, configuration snapshots, restore drills, and production gates, follow `docs/wrapper-infra-runbook.md`.

For production deployment, edge proxying, off-server backup, server migration, and disaster recovery, follow:

- `docs/production-deployment-runbook.md`
- `docs/edge-proxy-runbook.md`
- `docs/cpa-runbook.md`
- `docs/migration-runbook.md`
- `docs/disaster-recovery-runbook.md`
- `docs/git-branching-runbook.md`

## Local Development

Use WSL for development commands. Use Docker for the runtime and the repository for source/config work:

```bash
cp .env.example .env
# replace CHANGE_ME values first
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

This starts PostgreSQL, Redis, and New API, then exposes New API at `http://localhost:$NEW_API_DEV_PORT`. The local default is `3100`; container-internal New API still listens on `3000`. Caddy and Uptime Kuma are not required for the local smoke test.

The local development bind host defaults to `127.0.0.1`. To test from another device on the LAN, set `NEW_API_DEV_HOST=0.0.0.0` in `.env` and recreate the `new-api` container. Only do this on a trusted network because the development port exposes the New API admin console and relay API directly.

For local initialization and persistence rules, read `docs/local-development-state.md` before deleting containers or volumes.

If you need Uptime Kuma locally, use host port `3011` unless you know `3001` is free:

```powershell
$env:KUMA_PORT="3011"
docker compose --env-file .env -f docker-compose.yml up -d uptime-kuma
```

Before restarting local services or browser E2E, check host port ownership:

```bash
bash ops/check-local-ports.sh
```

If Windows + WSL reports `wslrelay.exe` holding `3100`, do not assume New API is down. Check the actual Docker-published port with `docker port relay-new-api 3000`, then either free the Windows host port or temporarily run browser checks with `NEW_API_BASE_URL=http://localhost:<published-port>`.

## WSL Network Proxy

If package downloads or image pulls require the local Windows proxy, set it only in the current WSL shell:

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

If the WSL gateway address does not work, use the known working Windows host proxy fallback:

```bash
export HTTP_PROXY=http://10.88.0.6:10808
export HTTPS_PROXY=http://10.88.0.6:10808
export http_proxy=http://10.88.0.6:10808
export https_proxy=http://10.88.0.6:10808
```

Do not put local proxy values into `.env`, `docker-compose.yml`, or committed config files.

## Initial Admin Exploration

Before each new feature or operations change, follow the Research Gate in `docs/development-workflow.md`.

Before designing local extensions, inspect the original admin console areas for users, tokens, groups, channels, pricing, payment, subscriptions, logs, settings, and model ratios. Record gaps in `docs/new-api-code-map.md` before adding any local code.

For the first paid API relay validation, follow `docs/phase1-new-api-validation-runbook.md`. That runbook keeps Phase 1 on upstream New API, with GPT first, manual admin crediting, local WSL validation, and no automatic payment.

## Daily Checks

- New API health endpoint is up.
- PostgreSQL and Redis containers are healthy.
- `bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json` confirms the expected GLM standard-pool configuration before live tests.
- `bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json` reports no failed health checks before channel changes or public status updates.
- `bash ops/relay-diagnostics.sh` passes for the primary paid-test model after setting `NEW_API_TEST_TOKEN`.
- `bash ops/e2e-api-billing.sh` passes before and after channel changes, model additions, or New API image upgrades. Use a low-quota test token because it calls the real upstream.
- `bash ops/export-config-snapshot.sh` creates a current redacted configuration snapshot before risky changes.
- Upstream provider balances are above alert thresholds.
- Error rate and failed relay count are not increasing.
- Last database backup exists and is restorable.
- Last off-server restic backup exists and can be listed with `restic snapshots`.
- Uptime Kuma public status page is updated with coarse service state only; do not expose provider names, channel IDs, balances, or internal error details.

After deployment, DNS changes, Caddy changes, or Cloudflare Tunnel changes, run:

```bash
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

## Production Cron Monitoring

Use `ops/production-monitor.sh` for scheduled production checks. It wraps the existing runtime, local backup, and offsite backup scripts without changing the active Docker topology. Logs go to `logs/production-monitor-<mode>.log`; the latest result is written to `logs/production-monitor-<mode>.status`. For example, runtime checks append to `logs/production-monitor-runtime.log`.

Manual checks on the origin:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/production-monitor.sh runtime
ENV_FILE=.env.production bash ops/production-monitor.sh backup
ENV_FILE=.env.production bash ops/production-monitor.sh offsite
```

Suggested crontab:

```cron
*/5 * * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh runtime
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh backup
35 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh offsite
```

Set `MONITOR_ALERT_WEBHOOK_URL` in `.env.production` only if you want webhook alerts. `MONITOR_ALERT_REPEAT_SECONDS` defaults to `3600`, so repeated failures for the same mode do not spam every cron run. The repository does not install cron automatically.

## Incident Response

For suspected billing, payment, or provider failure incidents: disable the affected channel or payment path first, export the relevant logs, then reconcile user balances. Do not delete failed orders or usage logs; mark them with an administrative note.

## Operations Profiles

Use an operations profile before channel changes, model additions, image upgrades, or handoff to another operator:

```bash
bash ops/export-config-snapshot.sh
bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json
```

The profile validator is read-only. It checks channels and abilities in PostgreSQL, gives warnings for missing support data such as test tokens or subscription plans, and only calls `/v1/models` when `NEW_API_TEST_TOKEN` is set. For full quota accounting, run `NEW_API_TEST_MODEL=glm-5.1 bash ops/e2e-api-billing.sh` separately with a low-quota test token.

The health advisor is also read-only. It summarizes enabled channel capacity, disabled channels, recent request/error samples, error rate, p95 use time, New API channel-test age, and recommendations for operator action.

During local setup and channel experiments, keep the profile in `mode: development`. In this mode, absolute error count and latency threshold breaches are warnings so failed probes, wrong model names, and stream-testing noise do not block the workflow. Before public paid traffic, copy the health profile, switch to `mode: production`, and tighten thresholds for standard-pool reliability.

## Public Status Page

Use Uptime Kuma for the user-facing status page. Keep monitors and any low-quota test token inside the Kuma UI/volume, not in git. Follow `docs/kuma-status-runbook.md`.

To publish the status page, set `STATUS_DOMAIN` on the server and merge the example status-domain block from `Caddyfile.status.example` into the active production Caddyfile. The active base `Caddyfile` does not expose Kuma by default.

## CPA Adapter

CPA is optional and must stay behind New API. Use `docker-compose.cpa.yml` to place it on the same Docker network as New API, and use `docker-compose.cpa.ui.yml` only when you need the management UI through an SSH tunnel. Do not expose `8317` publicly. Follow `docs/cpa-runbook.md`.

When production is running with Cloudflare Tunnel, use `ops/cpa-ui.sh open|close|ps` for the temporary CPA management UI. The helper keeps the active Tunnel overlay and uses `--no-deps` so a local CPA UI session does not recreate `new-api`, `cloudflared`, or `caddy`.

## Live E2E

For real API billing validation without printing token secrets, use a named low-quota test token:

```bash
NEW_API_TEST_TOKEN_NAME=test_2505081251 NEW_API_TEST_MODEL=glm-5.1 bash ops/live-e2e-billing-from-db-token.sh
```

The wrapper reads the token key from PostgreSQL and passes it only as a child-process environment variable to `ops/e2e-api-billing.sh`.

For browser-level validation, run:

```bash
npm run e2e:web:new-api
KUMA_BASE_URL=http://localhost:3011 npm run e2e:web:kuma
```

If New API was temporarily moved away from `3100`, pass the actual published port:

```bash
NEW_API_BASE_URL=http://localhost:3102 npm run e2e:web:new-api
```

For shell E2E from Windows PowerShell into WSL, set runtime variables inside the `bash` command so WSL receives them:

```powershell
bash -lc 'NEW_API_BASE_URL=http://localhost:3102 ./ops/live-e2e-billing-from-db-token.sh test_2505081251'
```

## Production Migration

Before moving to another origin server:

```bash
SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migration-preflight.sh
```

During the final maintenance window:

```bash
CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migrate-prod.sh
```

Do not update DNS or edge upstream until the target passes `ops/verify-remote-prod.sh`.
