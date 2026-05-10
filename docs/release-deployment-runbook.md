# Release Deployment Runbook

This is the preferred production deployment model for the origin server. It keeps Git checkout work separate from the running production directory by using a Capistrano-style layout plus Git worktrees.

## Directory Model

Default root:

```text
/opt/lihan_ai_deploy/
  repo.git/
  releases/
  candidate -> releases/<prepared-release-id>
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
- Successful `prepare` updates `candidate`; normal `smoke` and `promote` use that candidate when `RELEASE_ID` is omitted.
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
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0
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

If Cloudflare Tunnel is enabled, store tunnel runtime files in shared storage:

```env
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
CLOUDFLARED_CONFIG_PATH=/opt/lihan_ai_deploy/shared/cloudflared/config.yml
CLOUDFLARED_CREDENTIALS_PATH=/opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
```

Tunnel promotion appends `docker-compose.cloudflare-tunnel.yml` and runs Caddy at scale `0`, so the origin no longer publishes public `80/443`.

## Development To Production Flow

Normal change flow:

1. Develop locally in WSL or another Linux-like environment.
2. Commit on a short-lived branch such as `codex/<topic>` or `feature/<topic>`.
3. Open a PR and merge it to `main` after review and checks.
4. From the local repository, run `prepare` against `DEPLOY_REF=main`.
5. Run `smoke` against the prepared `candidate`; use `SMOKE_BACKUP_PATH` when you want a known backup.
6. Run `promote` only after smoke passes.
7. Verify `current`, Docker services, backups, New API admin, CPA channels, and Kuma.

The production host should not be used as the development workspace. It may keep a legacy `/opt/lihan_ai` clone for a short migration window, but production should run from `/opt/lihan_ai_deploy/current`.

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

If `/opt/lihan_ai_deploy/shared/data/cpa/config.yaml` was accidentally created as a directory by Docker bind mounting, stop and remove `relay-cpa`, replace that path with the real CPA `config.yaml` file, then start CPA again. The path must be a file, not a directory.

## Prepare

Create a candidate release without touching production:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
```

`prepare` fetches the requested ref, creates a detached worktree under `releases/<timestamp>-<sha>`, initializes submodules, links shared runtime paths, runs `ops/preflight.sh`, renders Compose config, and points `/opt/lihan_ai_deploy/candidate` at the prepared release.

The script still prints `RELEASE_ID` for audit and emergency use:

```text
RELEASE_ID=20260510T120000Z-abcdef0
candidate -> releases/20260510T120000Z-abcdef0
```

## Smoke

Run the candidate against an isolated restore stack:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
```

`smoke` uses `/opt/lihan_ai_deploy/candidate` by default. It uses the newest `shared/backups/postgres/*.dump` unless `SMOKE_BACKUP_PATH` is set. It runs `ops/drill-restore-stack.sh`, which starts temporary PostgreSQL, Redis, and New API containers on an isolated Docker network. It does not connect to the production database and does not bind public ports.

## Promote

Promote a tested release:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
```

`promote` uses `/opt/lihan_ai_deploy/candidate` by default. It backs up the current production PostgreSQL database when a current stack exists, points `previous` at the old release, atomically switches `current`, runs:

```bash
docker compose -p lihan_ai --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
```

and verifies New API `/api/status`. With `DEPLOY_INCLUDE_CPA=1`, `docker-compose.cpa.yml` is appended. With `DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1`, `docker-compose.cloudflare-tunnel.yml` is appended and `--scale caddy=0` is applied. If promotion succeeds, the candidate pointer is cleared. If promotion fails, the script switches `current` back to the previous release and attempts to restart the previous stack.

To operate on a specific release instead of the current candidate, pass either `RELEASE_ID=<release-id>` or a positional release id:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh promote
```

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

`cleanup` keeps the newest releases plus `current`, `previous`, and `candidate`, removes older worktrees, and prunes `repo.git` worktree metadata.

## Post-Promote Acceptance

Run these checks after every production promote:

```bash
readlink -f /opt/lihan_ai_deploy/current

cd /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cloudflare-tunnel.yml \
  ps

ENV_FILE=.env.production bash ops/check-production-runtime.sh

backup="$(ENV_FILE=.env.production bash ops/backup-postgres.sh)"
echo "$backup"
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh "$backup"

docker logs --tail=80 relay-cpa
```

For CPA routing, verify New API can reach CPA on the internal Docker network:

```bash
docker exec relay-new-api wget -q -O - http://cli-proxy-api:8317/v1/models \
  --header="Authorization: Bearer <CPA_API_KEY>"
```

Use one value from CPA `api-keys` for `<CPA_API_KEY>`.

## Legacy Directory Cleanup

Do not delete legacy directories immediately after the first successful promote.

Expected production directories during migration:

```text
/opt/containerd           container runtime data; do not touch
/opt/lihan_ai             legacy direct Git checkout; archive later
/opt/lihan_ai_deploy      active release deployment root
/opt/lihan_ai_runtime     old ad hoc CPA runtime; archive after CPA migration
```

Before archiving legacy directories, all of these must be true:

- `readlink -f /opt/lihan_ai_deploy/current` points at the release you intend to run.
- `docker compose -p lihan_ai ... ps` shows New API, PostgreSQL, Redis, Uptime Kuma, and optional CPA healthy or running as expected.
- In direct-origin mode, `relay-caddy` is running with published `80/443`; in Cloudflare Tunnel mode, `relay-cloudflared` is running and `relay-caddy` has no published `80/443`.
- `ENV_FILE=.env.production bash ops/backup-postgres.sh` works from `/opt/lihan_ai_deploy/current`.
- CPA config and auth files live under `/opt/lihan_ai_deploy/shared/data/cpa`.
- `docker inspect relay-cpa` shows no mount source under `/opt/lihan_ai_runtime`.
- At least one release deploy, smoke, promote, and backup cycle has passed after the migration.

Check CPA mounts:

```bash
docker inspect relay-cpa --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

Archive first, delete later:

```bash
sudo mv /opt/lihan_ai /opt/lihan_ai.legacy-$(date +%Y%m%d)
sudo mv /opt/lihan_ai_runtime /opt/lihan_ai_runtime.legacy-$(date +%Y%m%d)
```

After several stable days, remove the archived directories only if no mount, cron job, or operator workflow still references them. Never remove `/opt/containerd`, and never run `docker compose down -v` during cleanup.

## Fresh Server Or Disaster Recovery

For a new server, follow the disaster recovery runbook first: `docs/disaster-recovery-runbook.md`.

Release-specific recovery outline:

1. Provision Docker and the deploy user.
2. Create and chown `/opt/lihan_ai_deploy`.
3. Run `ops/deploy-release.sh bootstrap`.
4. Restore `/opt/lihan_ai_deploy/shared/.env.production`, CPA runtime files, and PostgreSQL dumps.
5. Restore `/opt/lihan_ai_deploy/shared/cloudflared/` if Cloudflare Tunnel is enabled.
6. Run `prepare` for `main`.
7. Run `smoke` with a known dump through `SMOKE_BACKUP_PATH`.
8. Promote the release to start the stack.
9. Restore the selected PostgreSQL dump if this is a full disaster recovery.
10. Run the post-promote acceptance checks before DNS cutover or paid traffic.

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
