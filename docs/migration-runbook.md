# Migration Runbook

Use this when moving `lihan_ai` to a new host.

## Source host

```bash
ENV_FILE=.env.production ops/backup-postgres.sh
ENV_FILE=.env.production ops/backup-config.sh
```

Copy the database dump, config snapshot, and CPA auth/config directory to the
new host through your private channel.

## Target host

```bash
cp .env.production.example .env.production
docker network create lihan_ai_relay-internal || true
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d postgres redis
CONFIRM_RESTORE=yes ENV_FILE=.env.production \
  ops/restore-postgres.sh /path/to/newapi.sql
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
ENV_FILE=.env.production ops/check-runtime.sh
```

Cut public traffic by moving the Cloudflare Tunnel credentials and starting the
`hostinger-cloudflared` stack on the target host.
