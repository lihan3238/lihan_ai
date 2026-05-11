# Production Deployment Runbook

## First Origin Setup

Use one Linux origin server for New API, PostgreSQL, Redis, and Caddy. If Cloudflare Tunnel is enabled, `cloudflared` becomes the public ingress path and Caddy is scaled to zero.

Production deploys from `main`. The deployment wrapper refuses non-`main` production deploys unless `ALLOW_NON_MAIN_PROD_DEPLOY=1` is explicitly set for a documented emergency.

For the Cloudflare for SaaS custom-hostname path using `api.lihan3238.com` and `origin.lihan3238.top`, follow `docs/cloudflare-saas-runbook.md` after the base origin stack is healthy.

1. Clone this repository to `/opt/lihan_ai` for initial bootstrap or use the release layout in `docs/release-deployment-runbook.md`.
2. Copy `.env.production.example` to `.env.production`.
3. Replace every `CHANGE_ME` value and set `DOMAIN` plus `ACME_EMAIL`.
4. Keep `.env.production` on the server only; it is ignored by git.
5. Use URL-safe generated secrets for `SESSION_SECRET`, `POSTGRES_PASSWORD`, and `REDIS_PASSWORD`. Prefer `openssl rand -hex 32`.
6. Run:

```bash
bash ops/bootstrap-server.sh
ENV_FILE=.env.production bash ops/preflight.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

For ongoing production updates, prefer the release deployment flow in `docs/release-deployment-runbook.md`, where production runs from `/opt/lihan_ai_deploy/current` and runtime files live in `/opt/lihan_ai_deploy/shared`.

The first New API browser visit normally shows the upstream initialization screen and asks you to create the root/admin account.

## Firewall Baseline

- Allow SSH only from trusted IPs when possible.
- In direct-origin mode, allow public TCP `80` and `443` for Caddy and certificate issuance.
- In Cloudflare Tunnel mode, do not expose public TCP `80` or `443` on the origin; allow outbound `cloudflared` connections.
- Do not publish PostgreSQL `5432`, Redis `6379`, New API `3000`, or CPA `8317` to the public internet.
- Keep provider firewall and host firewall rules consistent.

Quick listener check:

```bash
sudo ss -lntp | grep -E ':80|:443|:8317|:5432|:6379'
```

Only `80` and `443` should be publicly reachable in direct-origin mode. In Tunnel mode, neither port needs to be reachable on the origin. CPA `8317` should appear only on `127.0.0.1` when the UI override is intentionally enabled.

## Remote Deploy From Local

Preferred release deployment:

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh prepare
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh smoke
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh promote
```

`prepare` records the remote `candidate`, so normal `smoke` and `promote` do not need `RELEASE_ID`.

Legacy direct checkout deployment:

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

## Verification

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh
```

On the server:

```bash
cd /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/backup-cron.sh
curl -i https://api.lihan3238.com/api/status
```

For a real billing probe, create a low-quota named test token in New API and run:

```bash
DEPLOY_HOST=root@x.x.x.x RUN_LIVE_E2E=1 NEW_API_TEST_TOKEN_NAME=test_token_name NEW_API_TEST_MODEL=glm-5.1 bash ops/verify-remote-prod.sh
```

## Troubleshooting

`docker compose logs -f new-api` follows logs forever. Press `Ctrl-C` to stop following logs; it does not stop the container.

If `new-api` is unhealthy with a PostgreSQL URL parse error, check `POSTGRES_PASSWORD` first. URL-style DSNs break when the password contains characters such as `/`, `+`, `=`, `@`, or `:`.

If direct-origin HTTPS fails, check DNS, provider firewall, host firewall, Caddy logs, and then New API logs. If Tunnel mode fails, check `relay-cloudflared` logs and the Cloudflare tunnel config files first.
