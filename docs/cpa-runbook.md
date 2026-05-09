# CPA Runbook

CPA refers to CLIProxyAPI from `router-for-me/CLIProxyAPI`. In this repository it is an optional internal adapter behind New API.

## Upstream Assets

Official upstream examples are vendored for review and upgrade comparison:

- `vendor/cli-proxy-api/docker-compose.upstream.yml`
- `vendor/cli-proxy-api/config.example.yaml`

Refresh them with:

```bash
bash ops/sync-cpa-upstream-assets.sh
```

Do not run the upstream compose file directly in production. It publishes several host ports by default. Use the repository CPA overlay instead.

## Production Config

Keep the real CPA config outside git:

```bash
sudo mkdir -p /opt/lihan_ai_runtime/.cli-proxy-api
sudo cp vendor/cli-proxy-api/config.example.yaml /opt/lihan_ai_runtime/.cli-proxy-api/config.yaml
sudo nano /opt/lihan_ai_runtime/.cli-proxy-api/config.yaml
```

Minimum production rules:

- Set `remote-management.secret-key` to a strong random value.
- Keep CPA API keys strong and separate from New API user tokens.
- Use `auth-dir: "/root/.cli-proxy-api"` inside the container.
- Do not expose `8317` publicly.
- Keep upstream provider keys only in `/opt/lihan_ai_runtime/.cli-proxy-api/config.yaml`.

Generate secrets:

```bash
openssl rand -hex 32
```

## Start CPA Internally

Start CPA on the same Docker network as New API:

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d
```

New API can then reach CPA at:

```text
http://cli-proxy-api:8317
```

In the New API admin console, create a compatible channel with the CPA API key from `api-keys`.

## Management UI

The management UI is disabled from the public internet. When you need it, start the localhost-only UI override:

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cpa.ui.yml \
  up -d cli-proxy-api
```

From your local machine:

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

Open:

```text
http://127.0.0.1:8317/management.html
```

When finished, remove the UI port by restarting without the UI override:

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d --remove-orphans cli-proxy-api
```

## Verify From New API

Run from the origin server:

```bash
docker exec relay-new-api wget -q -O - http://cli-proxy-api:8317/v1/models \
  --header="Authorization: Bearer <CPA_API_KEY>"
```

If this fails, check `docker logs relay-cpa`, the CPA config path, and whether the container is on `relay-internal`.
