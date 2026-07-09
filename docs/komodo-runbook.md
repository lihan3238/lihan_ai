# Komodo Runbook

## Stack configuration

`lihan_ai`:

- Server: `hostinger-lihan`
- Project name: `lihan_ai`
- Run directory: production checkout path
- Files on host: enabled
- Compose files:
  - `docker-compose.yml`
  - `docker-compose.prod.yml`
  - `docker-compose.cpa.yml`
  - `docker-compose.cpa.ui.yml` only while CPA UI should be writable
- Additional env files:
  - `.env.production`, `track = false`
- Auto update: disabled

`hostinger-cloudflared`:

- Server: `hostinger-lihan`
- Project name: `hostinger-cloudflared`
- Compose file: `docker-compose.cloudflare-tunnel.yml`
- Additional env files:
  - `.env.production`, `track = false`
- Auto update: disabled

## Manual New API / CPA update

Use a Procedure or Action with:

```text
PullStack stack=lihan_ai services=[new-api, cli-proxy-api]
DeployStack stack=lihan_ai services=[new-api, cli-proxy-api]
RunAction action=lihan-ai-status-readonly
```

Do not include PostgreSQL, Redis, or cloudflared in this update action.
