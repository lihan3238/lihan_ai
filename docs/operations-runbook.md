# Operations Runbook

This repository is a thin production wrapper around upstream images. The host's
Docker Compose CLI is the deployment and update authority; no remote container
management control plane is required.

## Compose projects

- `lihan_ai`: `docker-compose.yml`, `docker-compose.prod.yml`, and
  `docker-compose.cpa.yml`.
- `hostinger-cloudflared`: `docker-compose.cloudflare-tunnel.yml`, run as a
  separate Compose project on the shared external network.

Keep PostgreSQL, Redis, and cloudflared on separate manual update paths. Limit
routine application updates to `new-api` and `cli-proxy-api`.

## Core commands

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
ENV_FILE=.env.production ops/check-runtime.sh
ENV_FILE=.env.production ops/backup-postgres.sh
ENV_FILE=.env.production ops/backup-secrets.sh
```

Update only the stateless application services:

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh pull new-api cli-proxy-api
ENV_FILE=.env.production WITH_CPA=1 \
  ops/compose.sh up -d --no-deps new-api cli-proxy-api
ENV_FILE=.env.production ops/check-runtime.sh
```

Start or reconcile the tunnel independently:

```bash
docker compose --env-file .env.production -p hostinger-cloudflared \
  -f docker-compose.cloudflare-tunnel.yml up -d
```

## CPA management

The Compose file fixes the CPA management listener to `127.0.0.1`.
`ops/check-runtime.sh` verifies that Docker publishes `8317/tcp` only on that
loopback address.

From a workstation with the canonical SSH alias, start the local forward:

```bash
ssh hostinger-cpa
```

The alias leaves the forwarding session in the background. Open
`http://127.0.0.1:18317/management.html`; the forwarding and proxy options
belong in `~/.ssh/config`, not this repository.

## CPA request audit

The host-local CPA config is intentionally writable so upstream management can
persist changes without committing credentials. Keep this production policy in
the real `config.yaml`:

```yaml
debug: false
commercial-mode: false
request-log: true
logging-to-file: false
logs-max-total-size-mb: 10240
error-logs-max-files: 10
```

`request-log` is the setting that records request and response bodies. `debug`
is not required for content auditing, and `logging-to-file` only moves ordinary
application logs from stdout into `main.log`.

The 10240 MiB limit is a size cap, not a seven-day guarantee. CLIProxyAPI scans
the log directory once per minute and removes the oldest `.log` files after the
cap is exceeded. At current traffic this is a short hot-retention window; move
older audit logs to lifecycle-managed storage if a full week is required.

The runtime check validates these non-secret settings without printing the rest
of the CPA config:

```bash
ENV_FILE=.env.production ops/check-runtime.sh
```
