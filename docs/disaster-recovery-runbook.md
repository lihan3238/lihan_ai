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

## Restore To Fresh Server

1. Provision a new server and install Docker with the Compose plugin.
2. Clone the repository to `/opt/lihan_ai`.
3. Restore `.env.production` from the restic backup or a separate secret store.
4. Restore the latest dump from restic.
5. Start PostgreSQL and Redis.
6. Run `ENV_FILE=.env.production bash ops/restore-postgres.sh <backup.dump>`.
7. Start the full production stack.
8. Run `DEPLOY_HOST=<new-server> bash ops/verify-remote-prod.sh`.

## Drill Schedule

Run an isolated restore drill monthly and before major New API upgrades:

```bash
ENV_FILE=.env.production bash ops/backup-postgres.sh
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
```
