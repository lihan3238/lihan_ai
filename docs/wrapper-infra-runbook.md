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

In this WSL setup, the known working Windows host proxy fallback is:

```bash
export HTTP_PROXY=http://10.88.0.6:10808
export HTTPS_PROXY=http://10.88.0.6:10808
export http_proxy=http://10.88.0.6:10808
export https_proxy=http://10.88.0.6:10808
```

Use the shell proxy first for `uv`, `git`, and Docker build attempts. If Docker base image pulls still fail, configure the Docker Desktop daemon proxy and retry the build.

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

## Operations Profile Validation

Validate the expected GLM standard pool without changing New API data:

```bash
bash ops/export-config-snapshot.sh
bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json
```

The validator checks PostgreSQL channels and abilities for `standard` + `glm-5.1`, reports safe counts for users, tokens, subscriptions, and payment-looking options, and does not print secrets. Set `NEW_API_TEST_TOKEN` only if you also want a read-only `/v1/models` visibility check. Run `ops/e2e-api-billing.sh` separately for real upstream and quota-accounting validation.

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
export OPS_PROFILE_FILE="config/ops-profiles/glm-standard.example.json"
bash ops/production-gate.sh
```

The gate calls real upstream APIs and can consume a small amount of quota.

When validating a specific AI development feature directory, include it in the gate:

```bash
export AI_DEV_FEATURE_DIR="docs/ai-dev/<YYYY-MM-DD>-<topic>"
bash ops/production-gate.sh
```

`AI_DEV_FEATURE_DIR` must point to a directory that passes `ops/ai-dev-check.sh`, including `Approved for implementation: yes` in `tasks.md`.
