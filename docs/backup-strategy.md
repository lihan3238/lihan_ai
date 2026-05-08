# Backup Strategy

## Current Mechanism

The project stores New API state in PostgreSQL. The primary backup mechanism is:

```bash
bash ops/backup-postgres.sh
```

The script creates a custom-format PostgreSQL dump under `backups/postgres/`, verifies that `pg_restore` can read the dump, and writes a `.sha256` checksum when `sha256sum` is available. The backup directory is ignored by git.

Verify a backup without restoring it:

```bash
bash ops/verify-postgres-backup.sh backups/postgres/<backup>.dump
```

Restore is intentionally explicit and destructive:

```bash
bash ops/restore-postgres.sh backups/postgres/<backup>.dump
```

Run an isolated restore drill without touching the active database:

```bash
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
```

The drill restores into a temporary PostgreSQL container with `--no-owner`, checks key New API tables, and removes the container afterwards.

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
- One off-server copy, for example another VPS, object storage, or a private backup machine.
- Monthly restore drill on a separate machine or temporary Docker project.

Local backups alone are not enough. If the VPS disk is lost, local dumps are lost with it.

## Suggested Cron

Run this on the VPS from the repository directory:

```cron
15 3 * * * cd /opt/lihan_ai && bash ops/backup-postgres.sh >> logs/backup.log 2>&1
```

Then sync `backups/postgres/` and `.env` to an off-server location using your preferred encrypted backup tool. Do not commit either to git.

## Recovery Order

1. Provision a fresh server.
2. Clone the repository and initialize submodules.
3. Restore the saved `.env`.
4. Start PostgreSQL and Redis.
5. Run `bash ops/restore-postgres.sh <backup.dump>`.
6. Start New API.
7. Verify login, admin settings, token list, channel list, and `/api/status`.
