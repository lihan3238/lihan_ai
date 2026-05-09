# Edge Proxy Runbook

## Purpose

Use an edge VPS with China-optimized routing as a stateless HTTPS reverse proxy. The edge improves user access but does not store PostgreSQL, Redis, New API config, upstream API keys, or billing state.

## Setup

On the edge server:

```bash
git clone <repo-url> /opt/lihan_ai
cd /opt/lihan_ai
cat > .env.edge <<'ENV'
EDGE_DOMAIN=api.example.com
ORIGIN_UPSTREAM=https://origin.example.com
ACME_EMAIL=ops@example.com
ENV
docker compose --env-file .env.edge -f docker-compose.edge.yml up -d
```

Point `EDGE_DOMAIN` DNS to the edge IP. Keep the origin domain separate so the edge can reverse proxy to it.

## Checks

```bash
docker compose --env-file .env.edge -f docker-compose.edge.yml config
docker compose --env-file .env.edge -f docker-compose.edge.yml ps
curl -I https://api.example.com/api/status
```

If streaming responses feel delayed, compare direct origin and edge timings before changing New API or CPA configuration.

## Security Rules

- Do not copy `.env.production` to the edge.
- Do not run PostgreSQL, Redis, or New API on the edge unless you intentionally promote it to origin.
- Keep Uptime Kuma public status coarse; do not expose channel names, balances, or upstream details.
