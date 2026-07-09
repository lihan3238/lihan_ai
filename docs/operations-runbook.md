# Operations Runbook

This repo is a thin production wrapper around upstream images.

## Core commands

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
ENV_FILE=.env.production ops/check-runtime.sh
ENV_FILE=.env.production ops/backup-postgres.sh
ENV_FILE=.env.production ops/backup-config.sh
```

## Komodo stacks

- `lihan_ai`: `docker-compose.yml`, `docker-compose.prod.yml`,
  `docker-compose.cpa.yml`, and optionally `docker-compose.cpa.ui.yml`.
- `hostinger-cloudflared`: `docker-compose.cloudflare-tunnel.yml`.

Keep PostgreSQL and Redis on manual updates. Use service-scoped updates for
`new-api` and `cli-proxy-api`.

## CPA UI

Open writable CPA config only when editing:

```bash
ENV_FILE=.env.production ops/cpa-ui.sh open
```

Close it after editing to restore read-only config mount:

```bash
ENV_FILE=.env.production ops/cpa-ui.sh close
```
