# Spec: Production Deploy Lessons Hardening

## User Goal

Make the production deployment repeatable and less fragile after the first successful VPS launch, while keeping the running New API service stable.

## Success Criteria

- Production preflight rejects known-bad DB and Redis secret formats before containers start.
- Backup, backup verification, and restore commands all respect `ENV_FILE=.env.production` without Compose missing-variable warnings.
- Operators have one command to diagnose Caddy, host ports, New API status, and external HTTPS status.
- CPA can be run inside the same Compose network as New API without exposing CPA publicly.
- CPA management UI remains available through SSH tunneling when explicitly enabled.

## Boundaries

- Do not modify `vendor/new-api`.
- Do not commit real `.env.production`, CPA config, API keys, auth files, backups, or logs.
- Do not publish CPA `8317` to the public network by default.
- Do not automate destructive production restore.

## Interfaces

```bash
ENV_FILE=.env.production bash ops/preflight.sh
ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh backups/postgres/<backup>.dump
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<backup>.dump
bash ops/sync-cpa-upstream-assets.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml up -d
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.cpa.yml -f docker-compose.cpa.ui.yml up -d cli-proxy-api
```
