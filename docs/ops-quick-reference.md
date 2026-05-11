# Ops Quick Reference

## Daily Quick Check

```bash
cd /opt/lihan_ai_deploy/current
readlink -f /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml ps
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
curl -i https://api.lihan3238.com/api/status
```

Add `-f docker-compose.cpa.yml` and `-f docker-compose.cloudflare-tunnel.yml` when those features are enabled.

## Release Deploy

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/verify-remote-prod.sh
```

`prepare` syncs missing production env keys with `ops/sync-env-template.sh`, writes a backup, and records the remote `candidate`. Leave `RELEASE_ID` empty unless you are intentionally testing an older candidate.

## Backup

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
tail -n 120 logs/backup-cron.log
```

Crontab:

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

Manual dump and verify:

```bash
backup="$(ENV_FILE=.env.production bash ops/backup-postgres.sh)"
echo "$backup"
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh "$backup"
```

## Manual Download

Run from your local machine:

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

## Restore Drill

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-postgres.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

## Restore

Use only during a maintenance window:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

## CPA UI

On the server:

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh open
ops/cpa-ui.sh ps
```

On your local machine:

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

Close after use:

```bash
ops/cpa-ui.sh close
```

## Env Alignment

```bash
cd /opt/lihan_ai_deploy/current
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
ENV_FILE=.env.production bash ops/preflight.sh
```

The sync appends missing keys only. It does not overwrite secrets and does not delete deprecated keys.

## New API Groups

Keep only `default` and `vip`. Move any old `standard` users, tokens, channel abilities, and pricing to `default` manually in the New API admin console.

```bash
bash ops/validate-ops-profile.sh config/ops-profiles/glm-default.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-default-health.example.json
```

## Host Pressure Checks

```bash
df -h
df -Pi
docker system df
docker ps -a
```

Do not delete `/opt/containerd`. Do not run `docker compose down -v` unless you intentionally want to delete state.
