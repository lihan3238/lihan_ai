# lihan_ai

Small production wrapper for upstream New API and CLIProxyAPI.

The repository avoids local forks and heavy automation. It keeps only the
host-native Docker Compose files, environment templates, backup scripts, and
concise runbooks needed to operate the services.

## Runtime

- `new-api`: upstream `calciumion/new-api`
- `cli-proxy-api`: upstream `eceasy/cli-proxy-api`
- `postgres`: `postgres:15-alpine`
- `redis`: `redis:7-alpine`
- `cloudflared`: upstream `cloudflare/cloudflared`, run as a separate Compose
  project

No Caddy, vendored upstream source, local New API build, Playwright test
surface, or Spec Kit workflow is part of the normal path.

## Files

```text
docker-compose.yml                    # New API + PostgreSQL + Redis
docker-compose.prod.yml               # production logging overrides
docker-compose.cpa.yml                # CLIProxyAPI
docker-compose.cloudflare-tunnel.yml  # separate cloudflared Compose project
.env.production.example               # production env template
ops/                                  # small host-native maintenance commands
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

Host administration uses the public SSH endpoint through `ssh hostinger-arch`.
CPA management is loopback-only at `127.0.0.1:8317`; open its dedicated local
forward with:

```bash
ssh hostinger-cpa
```

Then open `http://127.0.0.1:18317/management.html`. The SSH alias owns the
background local forward; this repository stores no host address, key, proxy,
or credential.

CPA request-body auditing is a host-local policy and never stores the real
config in Git. See `docs/operations-runbook.md` for the required settings and
the 10 GiB hot-retention limit.

Start cloudflared separately from the core project:

```bash
docker compose --env-file .env.production -p hostinger-cloudflared \
  -f docker-compose.cloudflare-tunnel.yml up -d
```

## Update

Use service-scoped host-native Compose commands for the stateless applications:

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh pull new-api cli-proxy-api
ENV_FILE=.env.production WITH_CPA=1 \
  ops/compose.sh up -d --no-deps new-api cli-proxy-api
ENV_FILE=.env.production ops/check-runtime.sh
```

Do not update PostgreSQL, Redis, cloudflared, and the application containers in
one automatic operation.
