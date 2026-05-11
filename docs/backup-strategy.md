# Backup Strategy

## Scope

The current production backup model is deliberately small:

- Create PostgreSQL custom-format dumps.
- Verify every dump immediately.
- Keep dumps on the production server under the shared deployment directory.
- Download selected dumps manually with `scp` when you want an outside copy.
- Keep restore and migration drills as explicit operator actions.

There is no remote-backup automation, webhook alerting, status dashboard, or monitoring service in this repository.

## Backup Location

Release deployments run from:

```text
/opt/lihan_ai_deploy/current
```

Runtime state lives under:

```text
/opt/lihan_ai_deploy/shared
```

By default, PostgreSQL dumps are written to:

```text
/opt/lihan_ai_deploy/shared/backups/postgres/
```

Do not commit `.env.production`, `backups/`, `snapshots/`, CPA runtime files, or downloaded dumps.

## Manual Backup

From the production server:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
```

The command prints the created dump path. Verify it:

```bash
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh backups/postgres/<dump>.dump
```

## Local Backup Cron

Use `ops/backup-cron.sh` for scheduled backup. It creates a dump, verifies it immediately, and appends plain text logs to `BACKUP_CRON_LOG_DIR`:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
```

Suggested crontab:

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

The repository does not install cron automatically. Add the entry deliberately on the origin server.

## Manual Download

From your local machine:

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

Verify after downloading:

```bash
sha256sum -c <dump>.dump.sha256
```

If the `.sha256` file contains an absolute server path, run:

```bash
sha256sum <dump>.dump
```

and compare the digest manually.

## Restore Drills

PostgreSQL-only drill:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-postgres.sh backups/postgres/<dump>.dump
```

Full stack drill:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

Run a full stack drill before major deploys, server migration, or any cleanup that touches old runtime directories.

## Restore

Restoring replaces the selected database. Stop application writes first and make a fresh backup before restoring:

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

Do not run `docker compose down -v` during backup or restore. Named volumes hold PostgreSQL and Redis state.

## Retention

`BACKUP_RETENTION_DAYS` controls local dump retention for `ops/backup-postgres.sh`. Keep enough recent dumps for rollback and migration work, then download important dumps manually before removing server-side copies.
