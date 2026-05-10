# Production Deployment Runbook

## First Origin Setup

Use one Linux origin server for New API, PostgreSQL, Redis, Caddy, and Uptime Kuma.

Production deploys from `main`. The deployment wrapper refuses non-`main` production deploys unless `ALLOW_NON_MAIN_PROD_DEPLOY=1` is explicitly set for a documented emergency.

Caddy is not part of New API. It is the reverse proxy container in this repository: it owns public `80/443`, obtains HTTPS certificates, and forwards application traffic to the internal `new-api:3000` service.

1. Clone this repository to `/opt/lihan_ai`.
2. Copy `.env.production.example` to `.env.production`.
3. Replace every `CHANGE_ME` value and set `DOMAIN` plus `ACME_EMAIL`.
4. Keep `.env.production` on the server only; it is ignored by git.
5. Use URL-safe generated secrets for `SESSION_SECRET`, `POSTGRES_PASSWORD`, and `REDIS_PASSWORD`. Prefer `openssl rand -hex 32`. Do not use base64 values containing `/`, `+`, or `=` for PostgreSQL or Redis passwords unless the DSN construction is changed to URL-encode them.
6. Run:

```bash
bash ops/bootstrap-server.sh
ENV_FILE=.env.production bash ops/preflight.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

The first New API browser visit normally shows the upstream initialization screen and asks you to create the root/admin account. `SESSION_SECRET`, `POSTGRES_PASSWORD`, and `REDIS_PASSWORD` are application/database/runtime secrets; they do not create a New API admin login.

## Firewall Baseline

For the origin server:

- Allow SSH only from your own trusted IPs when the provider firewall supports it. If you cannot restrict by IP yet, keep key-based SSH and disable password login after bootstrap.
- Allow public TCP `80` and `443` for Caddy and ACME certificate issuance.
- Do not publish PostgreSQL `5432`, Redis `6379`, New API `3000`, Uptime Kuma `3001`, or CPA `8317` to the public internet.
- Keep the provider firewall and host firewall consistent. If Caddy is healthy but public HTTPS fails, check DNS, provider firewall, host firewall, and Caddy logs in that order.

On the server, a quick listener check is:

```bash
sudo ss -lntp | grep -E ':80|:443|:8317|:5432|:6379'
```

Only `80` and `443` should be publicly reachable for the base production stack. CPA `8317` should appear only on `127.0.0.1` when the UI override is intentionally enabled.

## Remote Deploy From Local

Deploy a clean Git ref through SSH:

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

The deploy script refuses to continue if the remote repository has local changes. Before replacing containers, it creates a PostgreSQL backup when an existing database is running.

## Verification

Run:

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh
```

For a real billing probe, create a low-quota named test token in New API and run:

```bash
DEPLOY_HOST=root@x.x.x.x RUN_LIVE_E2E=1 NEW_API_TEST_TOKEN_NAME=test_token_name NEW_API_TEST_MODEL=glm-5.1 bash ops/verify-remote-prod.sh
```

## Troubleshooting

`docker compose logs -f new-api` follows logs forever. Seeing repeated task polling, channel syncing, dashboard refresh, and `GET /api/status` lines is normal for a running New API process. Press `Ctrl-C` to stop following logs; it does not stop the container.

If `new-api` is unhealthy with a PostgreSQL URL parse error, check `POSTGRES_PASSWORD` first. URL-style DSNs break when the password contains characters such as `/`, `+`, `=`, `@`, or `:`. Generate a new URL-safe value with `openssl rand -hex 32`, update `.env.production`, and recreate the stack.

If `curl -i http://127.0.0.1/api/status` fails on port `80`, that means Caddy is not listening on host port `80`, or you are curling the wrong layer. New API listens inside Docker on `3000`; production host access should normally go through Caddy:

```bash
docker exec relay-new-api wget -q -O - http://localhost:3000/api/status
curl -i https://$DOMAIN/api/status
```

If Caddy fails with `address already in use` for `:443`, find the process already holding the port:

```bash
sudo ss -lntp | grep -E ':80|:443'
```

Stop or reconfigure the conflicting web server, then restart the Compose stack.

If Caddy logs show ACME or DNS errors such as failed lookups through `127.0.0.53`, fix host DNS resolution before retrying certificate issuance. Caddy needs outbound DNS and HTTPS access to Let's Encrypt or ZeroSSL, and public inbound `80/443` must reach the origin.

If the New API UI shows `localhost:3000` after production is live, update the public site/base URL inside the New API admin settings to `https://$DOMAIN`. Caddy only proxies traffic; it does not rewrite application-level public URL settings.

External login providers such as GitHub or LinuxDo require provider-side OAuth apps, callback URLs pointing at the production domain, and corresponding New API admin settings. Enable them only after HTTPS works and the admin account is secured.

## Rollback

Redeploy a previous Git ref:

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_REF=<known-good-ref> bash ops/deploy-prod.sh
```

If data was changed, restore a known-good PostgreSQL dump only after exporting the current database for audit.
