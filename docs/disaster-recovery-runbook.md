# Disaster Recovery Runbook

## Protected Data

Protect these items:

- PostgreSQL dumps under `backups/postgres/`.
- `.env.production`.
- Redacted and private configuration snapshots under `snapshots/config/`.
- `RESTIC_PASSWORD`, stored outside the production server.

Redis is runtime state and is not the primary recovery source.

## Off-Server Backup

Configure restic:

```bash
export RESTIC_REPOSITORY=sftp:user@backup-host:/srv/restic/lihan-ai
export RESTIC_PASSWORD='<store outside the server>'
export CONFIG_SNAPSHOT_GPG_RECIPIENT='<optional-gpg-recipient>'
ENV_FILE=.env.production bash ops/offsite-backup.sh
```

Use cron on the origin:

```cron
20 3 * * * cd /opt/lihan_ai && ENV_FILE=.env.production bash ops/offsite-backup.sh >> logs/offsite-backup.log 2>&1
```

With release deployment, use:

```cron
20 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/offsite-backup.sh >> /opt/lihan_ai_deploy/shared/logs/offsite-backup.log 2>&1
```

## Restore To Fresh Server

1. Provision a new server and install Docker with the Compose plugin.
2. Clone the repository to `/opt/lihan_ai` for emergency legacy recovery, or run `ops/deploy-release.sh bootstrap` to recreate `/opt/lihan_ai_deploy`.
3. Restore `.env.production` into `/opt/lihan_ai_deploy/shared/.env.production` for release deployment, or into `/opt/lihan_ai/.env.production` for legacy recovery.
4. Restore the latest dump from restic.
5. Start PostgreSQL and Redis.
6. Run `ENV_FILE=.env.production bash ops/restore-postgres.sh <backup.dump>` from the active deploy directory.
7. Start the full production stack.
8. Run `ENV_FILE=.env.production bash ops/check-production-runtime.sh` after the stack starts.
9. Run `DEPLOY_HOST=<new-server> bash ops/verify-remote-prod.sh`.

## Drill Schedule

Run an isolated restore drill monthly and before major New API upgrades:

```bash
ENV_FILE=.env.production bash ops/backup-postgres.sh
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<backup>.dump
```
