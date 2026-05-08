# Operations Runbook

## First Deployment

1. Work from WSL Ubuntu 24.04 or the Linux VPS shell.
2. Run `git submodule update --init --recursive` to fetch the pinned New API source.
3. Copy `.env.example` to `.env`.
4. Replace all `CHANGE_ME` values with generated secrets.
5. Set `DOMAIN` and `ACME_EMAIL`.
6. Run `bash ops/preflight.sh`.
7. Run `docker compose up -d`.
8. Open the site, create the admin user, and disable public self-serve access until invite rules are configured.

## New API Source Management

The deployment uses the official New API Docker image by default, while `vendor/new-api` keeps the upstream source available for audit, diffs, and future customization. To update the pinned upstream source:

```bash
git -C vendor/new-api fetch origin
git -C vendor/new-api checkout origin/main
git add vendor/new-api
git commit -m "chore: update new-api upstream"
```

Only switch `docker-compose.yml` from the official image to a locally built image after custom changes have a separate test and rollback plan.

## Local Development

Use Docker for the runtime and the repository for source/config work:

```bash
cp .env.example .env
# replace CHANGE_ME values first
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

This starts PostgreSQL, Redis, and New API, then exposes New API at `http://localhost:3000`. Caddy and Uptime Kuma are not required for the local smoke test.

## WSL Network Proxy

If package downloads or image pulls require the local Windows proxy, set it only in the current WSL shell:

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

Do not put local proxy values into `.env`, `docker-compose.yml`, or committed config files.

## New User Flow

1. Issue an invite code to a known user.
2. User registers with email.
3. Admin confirms payment manually.
4. Admin grants the selected monthly quota package.
5. User creates an API key and selects standard or economy models.

## Channel Setup

Configure GLM, DeepSeek, GPT, and Claude channels in New API. Use `config/model-catalog.example.json` as the operating policy source. Keep standard and economy channels in separate groups. Never place unproven low-cost channels in the default group.

## Daily Checks

- New API health endpoint is up.
- PostgreSQL and Redis containers are healthy.
- Upstream provider balances are above alert thresholds.
- Error rate and failed relay count are not increasing.
- Economy channels are not leaking traffic into standard routes.
- Last database backup exists and is restorable.

## Incident Response

For suspected billing, payment, or provider failure incidents: disable the affected channel or payment path first, export the relevant logs, then reconcile user balances. Do not delete failed orders or usage logs; mark them with an administrative note.
