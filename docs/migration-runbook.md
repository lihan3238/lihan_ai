# Migration Runbook

## Definition

This project's V1 migration target is no data loss with a short maintenance window. It is not zero downtime.

## Preflight

Prepare the target server with the same repository path and `.env.production`, then run:

```bash
SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migration-preflight.sh
```

The preflight checks both servers, creates a source backup, copies it through the local machine, and runs an isolated restore drill on the target.

## Final Cutover

Run this only during the maintenance window:

```bash
CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migrate-prod.sh
```

The script stops `caddy` and `new-api` on the source, creates the final PostgreSQL dump, copies it to the target, restores the target database, starts the target stack, and verifies `/api/status`.

## DNS Or Edge Switch

After the target passes verification, update one of:

- DNS A record for `api.example.com`.
- Edge `ORIGIN_UPSTREAM` if you already use the edge proxy.

Keep the old server unchanged until user traffic and billing logs are verified on the new server.

## Rollback

Before DNS or edge switch, restart source services:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d caddy new-api
```

After DNS or edge switch, rollback by repointing traffic to the old origin if it has not accepted divergent writes. If both origins accepted writes, stop and reconcile manually from logs before restoring anything.
