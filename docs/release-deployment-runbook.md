# Release Deployment Runbook

This is the preferred production deployment model for the origin server. It keeps Git checkout work separate from the running production directory by using a Capistrano-style layout plus Git worktrees.

## Directory Model

Default root:

```text
/opt/lihan_ai_deploy/
  repo.git/
  releases/
  current -> releases/<release-id>
  previous -> releases/<previous-release-id>
  shared/
    .env.production
    data/cpa/
    logs/
    backups/
    snapshots/
```

Rules:

- `main` remains the production branch. Production release deploys refuse non-`main` refs unless `ALLOW_NON_MAIN_PROD_DEPLOY=1` is set for a documented emergency.
- `git fetch`, candidate release creation, and candidate smoke tests do not modify `current`.
- Docker Compose is always run from `current` with `docker compose -p "$DEPLOY_COMPOSE_PROJECT"`.
- Runtime files live under `shared/`, not inside a release checkout.
- Releases are not zero-downtime. `promote` switches `current` and restarts the Compose stack.
- PM2 and Paru were evaluated for deploy/revert ergonomics, but they are not core dependencies. The repository uses shell scripts so the production control plane stays Docker/Git based.

## Environment

Production defaults:

```env
DEPLOY_ROOT=/opt/lihan_ai_deploy
DEPLOY_REF=main
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=0
RELEASE_KEEP=5
```

If CPA is enabled, store CPA runtime files in shared storage:

```env
DEPLOY_INCLUDE_CPA=1
CPA_CONFIG_PATH=/opt/lihan_ai_deploy/shared/data/cpa/config.yaml
CPA_AUTH_PATH=/opt/lihan_ai_deploy/shared/data/cpa
CPA_LOG_PATH=/opt/lihan_ai_deploy/shared/logs/cpa
```

`docker-compose.cpa.ui.yml` is not part of normal release promotion. Use it only for a short SSH-tunneled management session as documented in `docs/cpa-runbook.md`.

## Bootstrap

Run once from your local machine:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh bootstrap
```

`bootstrap` creates `DEPLOY_ROOT`, initializes `repo.git`, creates `shared/`, and copies missing runtime files from `LEGACY_DEPLOY_PATH` which defaults to `/opt/lihan_ai`.

After bootstrap, verify or edit:

```bash
sudo ls -la /opt/lihan_ai_deploy/shared
sudo nano /opt/lihan_ai_deploy/shared/.env.production
```

If the copied env still points CPA at `/opt/lihan_ai`, update it to `/opt/lihan_ai_deploy/shared/...` before enabling `DEPLOY_INCLUDE_CPA=1`.

Keep the old `/opt/lihan_ai` directory until release deploys, backups, and rollback have been tested.

## Prepare

Create a candidate release without touching production:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
```

`prepare` fetches the requested ref, creates a detached worktree under `releases/<timestamp>-<sha>`, initializes submodules, links shared runtime paths, runs `ops/preflight.sh`, and renders Compose config.

Save the printed `RELEASE_ID`:

```text
RELEASE_ID=20260510T120000Z-abcdef0
```

## Smoke

Run the candidate against an isolated restore stack:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh smoke
```

`smoke` uses the newest `shared/backups/postgres/*.dump` unless `SMOKE_BACKUP_PATH` is set. It runs `ops/drill-restore-stack.sh`, which starts temporary PostgreSQL, Redis, and New API containers on an isolated Docker network. It does not connect to the production database and does not bind public ports.

## Promote

Promote a tested release:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh promote
```

`promote` backs up the current production PostgreSQL database when a current stack exists, points `previous` at the old release, atomically switches `current`, runs:

```bash
docker compose -p lihan_ai --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
```

and verifies New API `/api/status`. With `DEPLOY_INCLUDE_CPA=1`, `docker-compose.cpa.yml` is appended. If promotion fails, the script switches `current` back to the previous release and attempts to restart the previous stack.

## Rollback

Rollback to the previous release:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh rollback
```

Rollback changes code and Compose definitions only. It does not restore database state. If data was changed by the failed release, export the current database for audit before restoring a known-good PostgreSQL dump.

## Inspect And Clean Up

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh list
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh current
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_KEEP=5 bash ops/deploy-release.sh cleanup
```

`cleanup` keeps the newest releases plus `current` and `previous`, removes older worktrees, and prunes `repo.git` worktree metadata.

## Operational Notes

Backups and recovery commands should run from `current`:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

For cron, write logs into shared storage:

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-postgres.sh >> /opt/lihan_ai_deploy/shared/logs/backup.log 2>&1
```

Do not run `docker compose down -v` during deploy or rollback. PostgreSQL and Redis continue to use Docker named volumes.
