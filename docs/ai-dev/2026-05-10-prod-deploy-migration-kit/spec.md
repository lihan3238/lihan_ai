# Spec

## Goal
Make the New API relay easy to deploy, update, back up off-server, and migrate to a new production server without losing PostgreSQL data.

## Success Criteria
- A production origin can be deployed with one SSH command after `.env.production` is prepared on the server.
- An optional edge node can be deployed without PostgreSQL, Redis, New API, or upstream API keys.
- Off-server encrypted backup captures PostgreSQL dump, configuration snapshot, and the production env file.
- Migration scripts refuse destructive cutover unless explicitly confirmed.
- The runbooks describe normal deployment, edge setup, migration, and disaster recovery.

## Scope
In scope: Docker Compose production override, edge reverse proxy compose, SSH deployment scripts, restic backup wrapper, migration preflight and final cutover scripts, tests, and runbooks.

Out of scope: automatic DNS changes, zero-downtime Postgres replication, payment changes, New API source modification, and introducing Coolify/Dokploy/Portainer.

## Interfaces
- `bash ops/bootstrap-server.sh`
- `DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai bash ops/deploy-prod.sh`
- `DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh`
- `bash ops/offsite-backup.sh`
- `SOURCE_SSH=root@old TARGET_SSH=root@new bash ops/migration-preflight.sh`
- `CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new bash ops/migrate-prod.sh`
- `docker-compose.prod.yml`, `docker-compose.edge.yml`, `Caddyfile.edge.example`, `.env.production.example`

## Data
PostgreSQL remains the source of truth. Redis remains runtime state. `.env.production` and restic credentials stay outside git. Backups are written to `backups/postgres/`, snapshots to `snapshots/config/`, and off-server copies to `RESTIC_REPOSITORY`.

## Failure Modes
Scripts fail fast when required variables are missing. Deployment refuses to continue if the remote repo has local changes. Migration refuses to stop source services or restore over target data unless `CONFIRM_FINAL_CUTOVER=yes`. If target verification fails after final migration, keep DNS or edge upstream pointed at the old origin until the operator deliberately restarts or redirects.
