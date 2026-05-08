# Operations Runbook

## First Deployment

1. Work from WSL Ubuntu 24.04 or the Linux VPS shell.
2. Run `git submodule update --init --recursive` to fetch the pinned New API source.
3. Copy `.env.example` to `.env`.
4. Replace all `CHANGE_ME` values with generated secrets.
5. Set `DOMAIN` and `ACME_EMAIL`.
6. Run `bash ops/preflight.sh`.
7. Run `docker compose up -d`.
8. Open the site, create the admin user, and configure New API from its original admin console.

## New API Source Management

The deployment uses the official New API Docker image by default, while `vendor/new-api` keeps the upstream source available for audit, diffs, and future customization. Do not add local business logic until the relevant upstream implementation has been checked first. To update the pinned upstream source:

```bash
git -C vendor/new-api fetch origin
git -C vendor/new-api checkout origin/main
git add vendor/new-api
git commit -m "chore: update new-api upstream"
```

Only switch `docker-compose.yml` from the official image to a locally built image after custom changes have a separate test and rollback plan.

## Local Development

Use WSL for development commands. Use Docker for the runtime and the repository for source/config work:

```bash
cp .env.example .env
# replace CHANGE_ME values first
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

This starts PostgreSQL, Redis, and New API, then exposes New API at `http://localhost:$NEW_API_DEV_PORT`. Caddy and Uptime Kuma are not required for the local smoke test.

The local development bind host defaults to `127.0.0.1`. To test from another device on the LAN, set `NEW_API_DEV_HOST=0.0.0.0` in `.env` and recreate the `new-api` container. Only do this on a trusted network because the development port exposes the New API admin console and relay API directly.

For local initialization and persistence rules, read `docs/local-development-state.md` before deleting containers or volumes.

## WSL Network Proxy

If package downloads or image pulls require the local Windows proxy, set it only in the current WSL shell:

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

Do not put local proxy values into `.env`, `docker-compose.yml`, or committed config files.

## Initial Admin Exploration

Before designing local extensions, inspect the original admin console areas for users, tokens, groups, channels, pricing, payment, subscriptions, logs, settings, and model ratios. Record gaps in `docs/new-api-code-map.md` before adding any local code.

For the first paid API relay validation, follow `docs/phase1-new-api-validation-runbook.md`. That runbook keeps Phase 1 on upstream New API, with GPT first, manual admin crediting, local WSL validation, and no automatic payment.

## Daily Checks

- New API health endpoint is up.
- PostgreSQL and Redis containers are healthy.
- Upstream provider balances are above alert thresholds.
- Error rate and failed relay count are not increasing.
- Last database backup exists and is restorable.

## Incident Response

For suspected billing, payment, or provider failure incidents: disable the affected channel or payment path first, export the relevant logs, then reconcile user balances. Do not delete failed orders or usage logs; mark them with an administrative note.
