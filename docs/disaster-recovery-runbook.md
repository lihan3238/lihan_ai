# Disaster Recovery Runbook

## Recovery Source

This repository no longer manages automated remote backup. Disaster recovery starts from one of these operator-controlled inputs:

- A dump that still exists on the production server under `/opt/lihan_ai_deploy/shared/backups/postgres/`.
- A manually downloaded dump on your local machine.
- A dump copied from another trusted storage location that you manage outside this repository.

Keep `.env.production`, CPA config/auth files, and Cloudflare Tunnel credentials outside git. Without those runtime files, a database dump alone is not a complete production recovery.

## Before A Disaster

On the origin server:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

From your local machine, periodically download an important dump:

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

Also keep a private copy of:

- `/opt/lihan_ai_deploy/shared/.env.production`
- `/opt/lihan_ai_deploy/shared/data/cpa/`, if CPA is enabled
- `/opt/lihan_ai_deploy/shared/cloudflared/`, if Cloudflare Tunnel is enabled

## Fresh Server Recovery

1. Provision a Linux server with Docker and SSH access.
2. Clone or fetch this repository locally.
3. Bootstrap the release layout:

```bash
DEPLOY_HOST=<deploy-user>@<new-origin-host> bash ops/deploy-release.sh bootstrap
```

4. Copy runtime files to the new server:

```bash
scp .env.production <deploy-user>@<new-origin-host>:/opt/lihan_ai_deploy/shared/.env.production
scp <dump>.dump <deploy-user>@<new-origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/
scp <dump>.dump.sha256 <deploy-user>@<new-origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/
```

5. Prepare and smoke the release:

```bash
DEPLOY_HOST=<deploy-user>@<new-origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<new-origin-host> SMOKE_BACKUP_PATH=/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<new-origin-host> bash ops/deploy-release.sh promote
```

6. Restore the selected dump on the new server:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/restore-postgres.sh /opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

7. Verify New API login, `/api/status`, `/v1/models` with a test token, CPA channel routing if enabled, and Cloudflare Tunnel if enabled.

## Final Cutover

Only switch DNS or tunnel routing after:

- `ops/check-production-runtime.sh` passes.
- `ops/drill-restore-stack.sh` passes against the selected dump.
- New API admin login works.
- Important users/tokens/channels exist.
- CPA config paths are files, not directories.

Do not run `docker compose down -v` during recovery. It deletes named volume data.
