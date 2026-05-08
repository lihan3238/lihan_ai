# Wrapper Infrastructure Runbook

This runbook covers the first wrapper-level customization layer around upstream New API. It does not change `vendor/new-api` source.

## Official Image

Default development and production use the official image configured in `.env`:

```bash
NEW_API_IMAGE=calciumion/new-api:latest
```

Start the local development stack:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

## Local Build Image

Build a local image from the pinned submodule:

```bash
bash ops/build-local-new-api.sh
```

If the build fails while fetching `https://auth.docker.io/token`, configure the Docker daemon or Docker Desktop proxy. Shell-level `HTTP_PROXY` may not affect base image pulls because those requests are made by the Docker builder.

Start the local build image:

```bash
bash ops/start-local-new-api.sh
```

Rollback to the official image by starting without `docker-compose.local-build.yml`:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

## Configuration Snapshots

Create a redacted configuration snapshot:

```bash
bash ops/export-config-snapshot.sh
```

Create a private encrypted snapshot:

```bash
export CONFIG_SNAPSHOT_GPG_RECIPIENT="<gpg-key-id-or-email>"
bash ops/export-config-snapshot.sh --private
```

Snapshots are written under `snapshots/config/` by default and are ignored by git. The redacted snapshot is for review and comparison. The private snapshot may contain API keys, token keys, user data, and payment configuration; keep the GPG private key and passphrase separate from the server.

## Restore Drill

Create a normal PostgreSQL backup first:

```bash
bash ops/backup-postgres.sh
```

Run an isolated restore drill against a backup:

```bash
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
```

The drill restores into a temporary Postgres container, checks key tables, and removes the temporary container. It must not touch the active `relay-postgres` container.

## Production Gate

Run the full gate before New API upgrades, channel changes, production deployment, or source customization:

```bash
export NEW_API_TEST_TOKEN="sk-..."
export NEW_API_TEST_MODEL="glm-5.1"
export CONFIG_SNAPSHOT_GPG_RECIPIENT="<gpg-key-id-or-email>"
bash ops/production-gate.sh
```

The gate calls real upstream APIs and can consume a small amount of quota.
