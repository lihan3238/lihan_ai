# Release Deployment Runbook

This is the preferred production deployment model. It keeps Git updates, candidate validation, runtime files, and the running production directory separate.

## Directory Model

```text
/opt/lihan_ai_deploy/
  repo.git/
  releases/
  candidate -> releases/<prepared-release-id>
  current -> releases/<release-id>
  previous -> releases/<previous-release-id>
  state/
    promote.state
    promote.log
    promote.pid
    last_healthy -> releases/<last-healthy-release-id>
  shared/
    .env.production
    data/cpa/
    cloudflared/
    logs/
    backups/
    snapshots/
```

Rules:

- Production deploys use `main` unless `ALLOW_NON_MAIN_PROD_DEPLOY=1` is set for a documented emergency.
- `prepare` creates a detached Git worktree and updates `candidate`; it does not touch `current`.
- Normal `smoke` and `promote` use `candidate` automatically when `RELEASE_ID` is omitted.
- Compose always uses `docker compose -p "$DEPLOY_COMPOSE_PROJECT"`.
- Runtime files live under `shared/`, not inside a release checkout.
- Promotion restarts the Docker Compose stack; this is not a zero-downtime deploy.
- `promote` runs as a remote managed worker. If the local SSH session drops, the worker keeps running on the server and either finishes the release or rolls back.
- `state/promote.state` records the current deploy phase; `state/last_healthy` points to the last release that completed runtime checks.
- PM2 and Paru were considered, but the production control plane remains shell, Git, and Docker based.

## Env Sync During Prepare

`prepare` runs env alignment before preflight:

```bash
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
```

The sync creates a `.bak.<UTC>` backup, appends missing keys from `.env.production.example`, preserves existing values, and reports deprecated keys without deleting them. `ops/preflight.sh` still blocks `CHANGE_ME` placeholders.

## Required Env

```env
DEPLOY_ROOT=/opt/lihan_ai_deploy
DEPLOY_REF=main
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=0
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0
RELEASE_KEEP=5
```

Temporary patched New API frontend builds are opt-in:

```env
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
LOCAL_NEW_API_IMAGE=lihan-ai/new-api:local
```

This appends `docker-compose.local-build.yml`, builds `new-api` from the release's pinned `vendor/new-api`, and keeps other services on pulled images. Set it back to `0` after the official `calciumion/new-api:latest` image ships the equivalent frontend fix and passes the admin E2E.
During the temporary patch window, `.gitmodules` points `vendor/new-api` at `lihan3238/new-api` so the pinned fix commit is fetchable by CI and the production release worker.

CPA runtime files should be shared:

```env
DEPLOY_INCLUDE_CPA=1
CPA_CONFIG_PATH=/opt/lihan_ai_deploy/shared/data/cpa/config.yaml
CPA_AUTH_PATH=/opt/lihan_ai_deploy/shared/data/cpa
CPA_LOG_PATH=/opt/lihan_ai_deploy/shared/logs/cpa
```

Cloudflare Tunnel runtime files should also be shared:

```env
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
CLOUDFLARED_CONFIG_PATH=/opt/lihan_ai_deploy/shared/cloudflared/config.yml
CLOUDFLARED_CREDENTIALS_PATH=/opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
```

Both tunnel paths must be regular files:

```bash
test -f /opt/lihan_ai_deploy/shared/cloudflared/config.yml && echo "config.yml is file"
test -f /opt/lihan_ai_deploy/shared/cloudflared/tunnel.json && echo "tunnel.json is file"
```

Tunnel mode appends `docker-compose.cloudflare-tunnel.yml` and scales Caddy to zero, so the origin no longer needs public `80/443`.

## Development To Production Flow

1. Develop locally on a short-lived branch such as `codex/<topic>`.
2. Open a PR and merge to `main` after checks pass.
3. Run `prepare` for `DEPLOY_REF=main`.
4. Run `smoke`; pass `SMOKE_BACKUP_PATH` when you want a known dump.
5. Run `promote` only after smoke passes.
6. Verify runtime, backup, New API admin, test token, CPA routing if enabled, and tunnel routing if enabled.

The production host should not be the development workspace. It may keep a legacy `/opt/lihan_ai` clone during migration, but production should run from `/opt/lihan_ai_deploy/current`.

## Bootstrap

Run once from your local machine:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh bootstrap
```

`bootstrap` creates `DEPLOY_ROOT`, initializes `repo.git`, creates `shared/`, and copies missing runtime files from `LEGACY_DEPLOY_PATH` which defaults to `/opt/lihan_ai`.

After bootstrap:

```bash
sudo ls -la /opt/lihan_ai_deploy/shared
sudo nano /opt/lihan_ai_deploy/shared/.env.production
```

If CPA config was migrated from `/opt/lihan_ai_runtime`, make sure `.env.production` now points to `/opt/lihan_ai_deploy/shared/data/cpa`.

## Prepare, Smoke, Promote

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
```

Check deploy state at any time:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh status
```

If your terminal disconnects during promote, run `status` first. If no worker is running and `promote.state` is stale, run:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh recover
```

`recover` accepts the current release when runtime checks pass. If current is unhealthy, it rolls back to `previous`; if `previous` is unavailable, it falls back to `last_healthy`. This only rolls code and Compose definitions; it does not restore database contents.

Operate on a specific older prepared release only when needed:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh promote
```

Smoke with a known backup:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> \
SMOKE_BACKUP_PATH=/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump \
bash ops/deploy-release.sh smoke
```

## Post-Promote Acceptance

On the server:

```bash
cd /opt/lihan_ai_deploy/current
readlink -f /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/backup-cron.sh
curl -i https://api.lihan3238.com/api/status
```

In New API:

- Admin login works.
- `/api/status` returns success.
- A test token can call `/v1/models`.
- Only `default` and `vip` remain as active business groups.
- CPA channels point to the Docker internal CPA address if CPA is enabled.

## Legacy Directory Cleanup

During migration these directories may coexist:

```text
/opt/containerd           container runtime data; do not touch
/opt/lihan_ai             legacy direct Git checkout; archive later
/opt/lihan_ai_deploy      active release deployment root
/opt/lihan_ai_runtime     old ad hoc CPA runtime; archive after CPA migration
```

Before archiving legacy directories:

- `readlink -f /opt/lihan_ai_deploy/current` points at the intended release.
- Runtime check passes.
- `ENV_FILE=.env.production bash ops/backup-cron.sh` passes.
- `ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump` passes.
- CPA files live under `/opt/lihan_ai_deploy/shared/data/cpa`.
- `docker inspect relay-cpa` shows no mount source under `/opt/lihan_ai_runtime`.
- No crontab references old paths.

Check CPA mounts:

```bash
docker inspect relay-cpa --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

Archive first:

```bash
sudo mv /opt/lihan_ai /opt/lihan_ai.legacy-$(date +%Y%m%d)
sudo mv /opt/lihan_ai_runtime /opt/lihan_ai_runtime.legacy-$(date +%Y%m%d)
```

Delete only after several stable days. Never remove `/opt/containerd`, and never run `docker compose down -v` as cleanup.

## Fresh Server Or Disaster Recovery

Use `docs/disaster-recovery-runbook.md` first. Release-specific outline:

1. Provision Docker and the deploy user.
2. Bootstrap `/opt/lihan_ai_deploy`.
3. Restore `/opt/lihan_ai_deploy/shared/.env.production`.
4. Restore CPA and Cloudflare Tunnel runtime files if used.
5. Copy the selected PostgreSQL dump into `/opt/lihan_ai_deploy/shared/backups/postgres/`.
6. Run `prepare`, `smoke` with `SMOKE_BACKUP_PATH`, then `promote`.
7. Run `ops/restore-postgres.sh` with the selected dump.
8. Run runtime checks before DNS or tunnel cutover.

Do not run `docker compose down -v` during deploy, rollback, cleanup, or recovery.
