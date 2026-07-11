# lihan_ai

Small production wrapper for upstream New API and CLIProxyAPI.

The repository now avoids local forks and heavy automation. It keeps only the
Compose files, env templates, backup scripts, and runbooks needed to operate the
service under Komodo.

## Runtime

- `new-api`: upstream `calciumion/new-api`, pinned by tag and digest in the env examples
- `cli-proxy-api`: upstream `eceasy/cli-proxy-api`, pinned by tag and digest in the env examples
- `postgres`: `postgres:15-alpine`
- `redis`: `redis:7-alpine`
- `cloudflared`: upstream `cloudflare/cloudflared`, pinned by tag and digest and imported as a separate
  ingress stack when needed

No Caddy, vendored upstream source, local New API build, Playwright test
surface, or Spec Kit workflow is part of the normal path.

## Files

```text
docker-compose.yml                    # New API + PostgreSQL + Redis
docker-compose.prod.yml               # production logging overrides
docker-compose.cpa.yml                # CLIProxyAPI
docker-compose.cpa.ui.yml             # temporary writable CPA config override
docker-compose.cloudflare-tunnel.yml  # separate cloudflared ingress stack
.env.production.example               # production env template
ops/                                  # small host-side maintenance commands
docs/                                 # concise operations runbooks
```

## Deploy

Prepare host-local secrets:

```bash
cp .env.production.example .env.production
```

Start the core stack plus CPA:

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
```

Import cloudflared separately in Komodo with:

```bash
ENV_FILE=.env.production docker compose -p hostinger-cloudflared \
  -f docker-compose.cloudflare-tunnel.yml up -d
```

## Update

Use Komodo for normal operations. The intended manual update path is:

```text
PullStack lihan_ai services=[new-api, cli-proxy-api]
DeployStack lihan_ai services=[new-api, cli-proxy-api]
Run lihan-ai-status-readonly
```

Do not auto-update PostgreSQL, Redis, or cloudflared together with app
containers.
