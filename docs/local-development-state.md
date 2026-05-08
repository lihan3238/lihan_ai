# Local Development State

## First Initialization

When `http://localhost:$NEW_API_DEV_PORT` shows the New API initialization screen, follow the prompt and create the root/admin account. This is the normal upstream New API first-run flow.

The local development instance is meant to be reusable while you inspect and customize the repository. You do not need to reinitialize after normal restarts.

## What Persists

- New API user accounts, admin setup, channels, tokens, settings, billing records, and most business configuration are stored in PostgreSQL.
- PostgreSQL persists in the Docker named volume `lihan_ai_postgres_data`.
- Redis persists in the Docker named volume `lihan_ai_redis_data`.
- New API `/data` is bind-mounted to `./data/new-api`.
- New API logs are bind-mounted to `./logs/new-api`.
- The local `.env` file is ignored by git and must keep the same `SESSION_SECRET` across restarts.

This means container restart, image update, and container deletion are safe as long as Docker volumes and `.env` are preserved.

## Safe Commands

Use these during normal development:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml restart new-api
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

`down` removes containers and the project network, but keeps named volumes by default.

## Dangerous Commands

Do not run these unless you intentionally want to reset local data:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down -v
docker volume rm lihan_ai_postgres_data
docker volume rm lihan_ai_redis_data
```

`docker compose down -v` deletes the named volumes. That erases the local New API database and forces first-run initialization again.

Changing or regenerating `SESSION_SECRET` can invalidate existing login sessions. Keep `.env` stable after initialization.

## Backups

Before risky experiments, export PostgreSQL:

```bash
bash ops/backup-postgres.sh
```

Restore only when you understand that it overwrites the current database:

```bash
bash ops/restore-postgres.sh backups/postgres/<backup>.dump
```

## Why Not Bind-Mount PostgreSQL To The Repository

PostgreSQL data directories are better kept in Docker named volumes. Bind-mounting a database directory into the repository, especially through Windows paths under WSL/Docker Desktop, can introduce filesystem performance, locking, and permission issues. Named volumes still survive container deletion and are the safer default for a development database.
