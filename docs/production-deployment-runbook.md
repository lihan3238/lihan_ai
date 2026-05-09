# Production Deployment Runbook

## First Origin Setup

Use one Linux origin server for New API, PostgreSQL, Redis, Caddy, and Uptime Kuma.

Production deploys from `main`. The deployment wrapper refuses non-`main` production deploys unless `ALLOW_NON_MAIN_PROD_DEPLOY=1` is explicitly set for a documented emergency.

1. Clone this repository to `/opt/lihan_ai`.
2. Copy `.env.production.example` to `.env.production`.
3. Replace every `CHANGE_ME` value and set `DOMAIN` plus `ACME_EMAIL`.
4. Keep `.env.production` on the server only; it is ignored by git.
5. Run:

```bash
bash ops/bootstrap-server.sh
ENV_FILE=.env.production bash ops/preflight.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
```

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

## Rollback

Redeploy a previous Git ref:

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_REF=<known-good-ref> bash ops/deploy-prod.sh
```

If data was changed, restore a known-good PostgreSQL dump only after exporting the current database for audit.
