# Lihan AI Relay

Chinese: [README.zh-CN.md](README.zh-CN.md)

This repository is a thin production wrapper around upstream New API. The runtime stays on the official `calciumion/new-api:latest` image; local code owns deployment, backup, recovery, validation, and operational documentation.

## Boundaries

- Upstream source is tracked as a submodule at `vendor/new-api`.
- Production remains Docker Compose based.
- Public traffic enters through Caddy in direct-origin mode or through Cloudflare Tunnel in tunnel mode.
- CPA / CLIProxyAPI is optional and internal to the Docker network.
- The current operations surface intentionally excludes the legacy monitoring/dashboard and remote-backup tooling.
- Local product customization is deferred until New API's built-in behavior has been verified.

## Quick Start

1. Use WSL Ubuntu 24.04 or a Linux VPS shell.
2. Install Docker and Docker Compose.
3. Initialize submodules:

```bash
git submodule update --init --recursive
```

4. Copy `.env.production.example` to `.env.production`.
5. Replace every `CHANGE_ME` value and set `DOMAIN` to the public production hostname.
6. Run preflight:

```bash
ENV_FILE=.env.production bash ops/preflight.sh
```

7. Start the base stack:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
```

8. Open `https://$DOMAIN`, create the first New API admin account, then finish configuration in the upstream admin console.

## Repository Layout

- `docker-compose.yml`: New API, PostgreSQL, Redis, and Caddy.
- `docker-compose.prod.yml`: production logging and port overrides.
- `docker-compose.cpa.yml`: optional internal CPA service.
- `docker-compose.cpa.ui.yml`: short-lived CPA management UI override for SSH tunnel use.
- `docker-compose.cloudflare-tunnel.yml`: optional Cloudflare Tunnel path that runs `cloudflared` and skips public origin `80/443`.
- `.env.example`: local development variables.
- `.env.production.example`: production env template.
- `ops/`: preflight, deploy, backup, restore, migration, CPA, and env sync scripts.
- `tests/`: shell tests for the wrapper.
- `docs/`: English runbooks; `docs/zh-CN/` contains synchronized Chinese runbooks.
- `config/ops-profiles/`: read-only validation profiles for expected New API configuration.
- `vendor/new-api`: upstream New API source.

## Common Production Commands

### Initial Production Deployment

Run from your local repository after the origin server has Docker, SSH access, and `/opt/lihan_ai_deploy/shared/.env.production`:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh bootstrap
DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/verify-remote-prod.sh
```

`prepare` records a remote `candidate`, so normal `smoke` and `promote` do not need `RELEASE_ID`. Release commands read CPA and Cloudflare Tunnel topology from the remote `.env.production` by default; pass `DEPLOY_INCLUDE_*` only for a temporary override.

Before `prepare` runs preflight, it calls:

```bash
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
```

The sync only appends keys that are present in the release template but missing from production. It creates a `.bak.<UTC>` backup, never overwrites existing values, and only reports deprecated keys.

### Update Production To Latest Main

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh status
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/verify-remote-prod.sh
```

Use `RELEASE_ID=<release-id>` only when intentionally operating on an older prepared release.
If SSH disconnects during promote, run `ops/deploy-release.sh status`; if no worker is running and `promote.state` is stale, run `ops/deploy-release.sh recover`.

### Open And Close CPA UI

CPA UI stays private and should be reached through SSH tunneling only.

On the production server:

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh open
ops/cpa-ui.sh ps
```

From your local machine:

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

Open `http://127.0.0.1:8317/management.html`. When finished:

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh close
ops/cpa-ui.sh ps
```

### Local Backup Cron

The only scheduled production job in this repository is local PostgreSQL backup plus immediate verification:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
```

Suggested crontab:

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

Backups are written under `backups/postgres/` by default. To download a dump manually:

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

Restore and drill commands remain manual:

```bash
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<dump>.dump
```

## New API Groups

Production should keep only two New API groups:

- `default`: normal friend/user group.
- `vip`: manually granted higher-priority or discounted group.

This repository no longer treats `standard` as an active group. Existing production data is not auto-migrated by code. In the New API admin console, manually move old users, tokens, channel abilities, pricing, and model access from `standard` to `default`, then keep `vip` only for accounts you explicitly grant.

Read-only checks:

```bash
bash ops/validate-ops-profile.sh config/ops-profiles/glm-default.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-default-health.example.json
```

## Useful Commands

```bash
docker compose ps
docker compose logs -f new-api
ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/backup-cron.sh
ENV_FILE=.env.production bash ops/prune-runtime-storage.sh all
bash ops/phase1-smoke-test.sh
bash ops/relay-diagnostics.sh
NEW_API_TEST_TOKEN=... NEW_API_TEST_MODEL=glm-5.1 bash ops/e2e-api-billing.sh
bash ops/export-config-snapshot.sh
SOURCE_SSH=root@old TARGET_SSH=root@new bash ops/migration-preflight.sh
CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new bash ops/migrate-prod.sh
bash ops/sync-cpa-upstream-assets.sh
```

## Local Development

```bash
cp .env.example .env
# replace CHANGE_ME values first
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

Open `http://localhost:$NEW_API_DEV_PORT`. The default local port is `3100`; container-internal New API still listens on `3000`. Do not run `docker compose down -v` unless you intentionally want to erase local database state.

For browser-level E2E, read `docs/browser-e2e-runbook.md`. Before rerunning local browser or API flows, run:

```bash
bash ops/check-local-ports.sh
```

## CI And Verification

`.github/workflows/ci.yml` is the GitHub Actions PR CI. It runs no-secret PR checks: shell syntax, shell tests, compose rendering, docs checks, and `scripts/verify-repo.ps1 -SkipDocker`.

Local verification:

```bash
bash -n ops/*.sh tests/*.test.sh
for test in tests/*.test.sh; do bash "$test"; done
bash ops/dev-gate.sh docs/ai-dev/<YYYY-MM-DD>-<topic>
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts\verify-repo.ps1 -SkipDocker
git diff --check
```

For new features, update the feature `plan.md` with `E2E Coverage Matrix`, `Documentation Impact`, and `Usage/Test Guide`; update `handoff.md` with `How To Use And Test`, `E2E Results`, and `Documentation Updated`. Skipped E2E entries must include `Reason:` and `Rerun:`.
