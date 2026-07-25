# Operations Runbook

This repo is a thin production wrapper around upstream images.

## Core commands

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
ENV_FILE=.env.production ops/check-runtime.sh
ENV_FILE=.env.production ops/backup-postgres.sh
ENV_FILE=.env.production ops/backup-secrets.sh
```

## Komodo stacks

- `lihan_ai`: `docker-compose.yml`, `docker-compose.prod.yml`,
  `docker-compose.cpa.yml`, and optionally `docker-compose.cpa.ui.yml`.
- `hostinger-cloudflared`: `docker-compose.cloudflare-tunnel.yml`.

Keep PostgreSQL and Redis on manual updates. Use service-scoped updates for
`new-api` and `cli-proxy-api`.

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

`request-log` is the setting that records request and response bodies.
`debug` is not required for content auditing, and `logging-to-file` only moves
ordinary application logs from stdout into `main.log`.

The 10240 MiB limit is a size cap, not a seven-day guarantee. CLIProxyAPI scans
the log directory once per minute and removes the oldest `.log` files after the
cap is exceeded. At current traffic this is a short hot-retention window; move
older audit logs to lifecycle-managed storage if a full week is required.

The runtime check validates these non-secret settings without printing the
rest of the CPA config:

```bash
ENV_FILE=.env.production ops/check-runtime.sh
```

`ops/cpa-ui.sh` remains available as a compatibility recreate helper, but the
base CPA Compose mount is already writable.
