# Backup Strategy

## Current Mechanism

The project stores New API state in PostgreSQL. The primary backup mechanism is:

```bash
ENV_FILE=.env.production bash ops/backup-postgres.sh
```

The script creates a custom-format PostgreSQL dump under `backups/postgres/`, verifies that `pg_restore` can read the dump, and writes a `.sha256` checksum when `sha256sum` is available. The backup directory is ignored by git. Production commands should pass `ENV_FILE=.env.production` so Compose expands the same variables as the running stack.

Verify a backup without restoring it:

```bash
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh backups/postgres/<backup>.dump
```

Restore is intentionally explicit and destructive:

```bash
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<backup>.dump
```

Run an isolated restore drill without touching the active database:

```bash
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
```

The drill restores into a temporary PostgreSQL container with `--no-owner`, checks key New API tables, and removes the container afterwards.

Run a fuller isolated stack drill when you need higher confidence:

```bash
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<backup>.dump
```

The stack drill starts temporary PostgreSQL, Redis, and New API containers on a private Docker network, restores the dump, checks `/api/status`, and then removes the temporary resources.

Use the three verification levels deliberately:

- `verify-postgres-backup.sh` proves the dump file is readable and checksum-valid.
- `drill-restore-postgres.sh` proves PostgreSQL can restore the dump and key tables exist.
- `drill-restore-stack.sh` proves a restored database can boot New API with Redis and answer `/api/status`.

The stack drill is the closest local confidence check before a migration or destructive restore. It still does not replace a manual browser check of admin login, channels, tokens, and one low-quota token call.

## What Must Be Preserved

- PostgreSQL database: users, root account, tokens, channels, settings, logs, billing data, OAuth/payment configuration.
- `.env`: keep `POSTGRES_*`, `REDIS_PASSWORD`, and especially `SESSION_SECRET`.
- Optional local files under `data/new-api/` if New API stores generated files or local assets there.

Redis is useful for cache/session-like runtime state, but PostgreSQL plus `.env` are the critical recovery items.

## Local Development Rule

Normal container deletion is safe:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down
```

This keeps Docker named volumes.

Do not run this unless you intentionally want to erase local state:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down -v
```

`down -v` deletes `lihan_ai_postgres_data`, which contains the local New API database.

## Production Baseline

For a small paid service, use at least:

- Daily PostgreSQL backup.
- Backup after every New API upgrade and before payment/channel configuration changes.
- 14-30 days local retention.
- One encrypted off-server copy, for example restic over SFTP, S3-compatible object storage, or a private backup machine.
- Monthly restore drill on a separate machine or temporary Docker project.

Local backups alone are not enough. If the VPS disk is lost, local dumps are lost with it.

## Off-Server Restic Backup

After `.env.production` is prepared on the production origin, configure restic credentials outside git:

```bash
export RESTIC_REPOSITORY=sftp:user@backup-host:/srv/restic/lihan-ai
export RESTIC_PASSWORD='<store outside the server>'
export CONFIG_SNAPSHOT_GPG_RECIPIENT='<optional-gpg-recipient>'
ENV_FILE=.env.production bash ops/offsite-backup.sh
```

The wrapper creates a PostgreSQL dump, exports a redacted config snapshot, optionally exports a GPG-encrypted private snapshot, backs those files up with restic, applies retention, and runs `restic check`.

Keep `RESTIC_PASSWORD` somewhere other than the production server. Without it, the off-server repository is not recoverable.

## Off-Server Encrypted Backup

Use restic for encrypted off-server copies:

```bash
export RESTIC_REPOSITORY=sftp:user@backup-host:/srv/restic/lihan-ai
export RESTIC_PASSWORD="<store outside the server>"
ENV_FILE=.env.production bash ops/offsite-backup.sh
```

`ops/offsite-backup.sh` creates a PostgreSQL dump, exports a redacted configuration snapshot, includes the selected env file, and backs them up to `RESTIC_REPOSITORY`. If `CONFIG_SNAPSHOT_GPG_RECIPIENT` is set, it also includes a GPG-encrypted private configuration snapshot.

## Suggested Cron

Run this on the VPS from the repository directory:

```cron
15 3 * * * cd /opt/lihan_ai && ENV_FILE=.env.production bash ops/backup-postgres.sh >> logs/backup.log 2>&1
```

Then run `ops/offsite-backup.sh` or sync `backups/postgres/` and `.env.production` to an off-server location using your preferred encrypted backup tool. Do not commit either to git.

For restic-based off-server backup:

```cron
20 3 * * * cd /opt/lihan_ai && ENV_FILE=.env.production bash ops/offsite-backup.sh >> logs/offsite-backup.log 2>&1
```

## Recovery Order

1. Provision a fresh server.
2. Clone the repository and initialize submodules.
3. Restore the saved `.env.production`.
4. Start PostgreSQL and Redis.
5. Run `ENV_FILE=.env.production bash ops/restore-postgres.sh <backup.dump>`.
6. Start New API.
7. Run `ENV_FILE=.env.production bash ops/check-production-runtime.sh`.
8. Verify login, admin settings, token list, channel list, and `/api/status`.

For a full fresh-server disaster recovery flow, follow `docs/disaster-recovery-runbook.md`.
