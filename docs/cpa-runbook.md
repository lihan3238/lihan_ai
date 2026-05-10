# CPA Runbook

CPA refers to CLIProxyAPI from `router-for-me/CLIProxyAPI`. In this repository it is an optional internal adapter behind New API.

## Upstream Assets

Official upstream examples are vendored for review and upgrade comparison:

- `vendor/cli-proxy-api/docker-compose.upstream.yml`
- `vendor/cli-proxy-api/config.example.yaml`

Refresh them with:

```bash
bash ops/sync-cpa-upstream-assets.sh
git diff vendor/cli-proxy-api
bash tests/cpa-compose.test.sh
```

Do not run the upstream compose file directly in production. It publishes several host ports by default. Use the repository CPA overlay instead.

If the official example changes, review the diff and update `docker-compose.cpa.yml` only when the repository overlay needs a matching runtime change. Do not copy upstream public port publishing into production.

The repository overlay exists for two reasons:

- New API must be able to resolve CPA through the shared `relay-internal` Docker network.
- CPA management and provider credentials must not be exposed as a public service.

## Production Config

Keep the real CPA config outside git:

```bash
mkdir -p /opt/lihan_ai/data/cpa /opt/lihan_ai/logs/cpa
cp vendor/cli-proxy-api/config.example.yaml /opt/lihan_ai/data/cpa/config.yaml
chmod 700 /opt/lihan_ai/data/cpa
chmod 600 /opt/lihan_ai/data/cpa/config.yaml
nano /opt/lihan_ai/data/cpa/config.yaml
```

`data/` and `logs/` are ignored by git. This keeps CPA runtime files inside the deploy directory for migration, without committing provider keys, auth files, or logs.

Minimum production rules:

- Set `remote-management.secret-key` to a strong random value.
- Keep `remote-management.allow-remote: false` unless you have a specific reason to expose management beyond loopback inside the container. The preferred UI path is still SSH tunneling.
- Keep CPA API keys strong and separate from New API user tokens.
- Use `auth-dir: "/root/.cli-proxy-api"` inside the container.
- Do not expose `8317` publicly.
- Keep upstream provider keys only in `/opt/lihan_ai/data/cpa/config.yaml`.

Generate secrets:

```bash
openssl rand -hex 32
```

If you already created CPA config under the older runtime path, migrate it into the repository runtime directory:

```bash
mkdir -p /opt/lihan_ai/data/cpa /opt/lihan_ai/logs/cpa
cp -a /opt/lihan_ai_runtime/.cli-proxy-api/. /opt/lihan_ai/data/cpa/
chmod 700 /opt/lihan_ai/data/cpa
chmod 600 /opt/lihan_ai/data/cpa/config.yaml
```

Then set these values in `.env.production`:

```env
CPA_CONFIG_PATH=/opt/lihan_ai/data/cpa/config.yaml
CPA_AUTH_PATH=/opt/lihan_ai/data/cpa
CPA_LOG_PATH=/opt/lihan_ai/logs/cpa
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

Recommended New API channel settings:

- Base URL: `http://cli-proxy-api:8317`
- API key: one value from CPA `api-keys`
- Model names: match the CPA provider/model aliases you configured

Do not use the public origin domain for New API-to-CPA traffic. That would leave Docker, go out through Caddy or public networking, and make debugging harder.

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

The base CPA compose file mounts `config.yaml` read-only. The UI override intentionally remounts `/CLIProxyAPI/config.yaml` writable so the management UI can save changes. Use this override only while you are actively managing CPA config.

From your local machine:

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

Open:

```text
http://127.0.0.1:8317/management.html
```

Security model:

- Provider firewall should not allow inbound `8317`.
- The Compose UI override binds `8317` to host `127.0.0.1` only.
- SSH forwards your local browser to the server loopback listener.
- `remote-management.secret-key` is still required by CPA management routes.

When finished, remove the UI port by restarting without the UI override:

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d --remove-orphans cli-proxy-api
```

This returns CPA to the read-only config mount used for normal runtime.

## Verify From New API

Run from the origin server:

```bash
docker exec relay-new-api wget -q -O - http://cli-proxy-api:8317/v1/models \
  --header="Authorization: Bearer <CPA_API_KEY>"
```

If this fails, check `docker logs relay-cpa`, the CPA config path, and whether the container is on `relay-internal`.

If you previously started CPA with ad hoc `docker run -p 8317:8317`, stop that container before enabling Compose:

```bash
docker ps --format '{{.Names}} {{.Ports}}' | grep 8317
docker rm -f <old-cpa-container>
```

Then start CPA through `docker-compose.cpa.yml` so New API and CPA share service discovery.
