# CPA Runbook

CPA refers to CLIProxyAPI from `router-for-me/CLIProxyAPI`. In this repository it is an optional internal adapter behind New API.

CPA is not the backup, host-health, or operations dashboard. Keep it focused on upstream adapter traffic and its own management UI. Use `ops/check-production-runtime.sh`, `ops/backup-cron.sh`, and restore drills for runtime, backup, disk, container, and recovery checks.

## Upstream Assets

The upstream project is tracked as a submodule for review and upgrade comparison:

- `vendor/cli-proxy-api/docker-compose.yml`
- `vendor/cli-proxy-api/config.example.yaml`

Update the pinned submodule with:

```bash
bash ops/sync-cpa-upstream-assets.sh
git diff --submodule vendor/cli-proxy-api
bash tests/cpa-compose.test.sh
```

Do not run the upstream compose file directly in production. It publishes several host ports by default. Use the repository CPA overlay instead.

If the official example changes, review the submodule diff and update `docker-compose.cpa.yml` only when the repository overlay needs a matching runtime change. Do not copy upstream public port publishing into production.

The repository overlay exists for two reasons:

- New API must be able to resolve CPA through the shared `relay-internal` Docker network.
- CPA management and provider credentials must not be exposed as a public service.

## Production Config

Keep the real CPA config outside git:

```bash
mkdir -p /opt/lihan_ai_deploy/shared/data/cpa /opt/lihan_ai_deploy/shared/logs/cpa
cp vendor/cli-proxy-api/config.example.yaml /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
chmod 700 /opt/lihan_ai_deploy/shared/data/cpa
chmod 600 /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
nano /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
```

`shared/data/` and `shared/logs/` stay outside release checkouts. This keeps CPA runtime files available across release promotion and rollback, without committing provider keys, auth files, or logs.

Minimum production rules:

- Set `remote-management.secret-key` to a strong random value.
- Keep `remote-management.allow-remote: false` unless you have a specific reason to expose management beyond loopback inside the container. The preferred UI path is still SSH tunneling.
- Keep CPA API keys strong and separate from New API user tokens.
- Use `auth-dir: "/root/.cli-proxy-api"` inside the container.
- Do not expose `8317` publicly.
- Keep upstream provider keys only in `/opt/lihan_ai_deploy/shared/data/cpa/config.yaml`.
- If `logging-to-file: true`, set `logs-max-total-size-mb` to a positive value such as `200`.
- Keep `error-logs-max-files` bounded, for example `10`.

Recommended CPA file log cap:

```yaml
logging-to-file: true
logs-max-total-size-mb: 200
error-logs-max-files: 10
```

`ops/preflight.sh` fails production deploys with `DEPLOY_INCLUDE_CPA=1` when CPA file logging is enabled without a positive `logs-max-total-size-mb`. The container also has Docker `json-file` rotation in `docker-compose.cpa.yml` with `max-size=20m` and `max-file=5`.

Generate secrets:

```bash
openssl rand -hex 32
```

If you already created CPA config under the older runtime path, migrate it into the repository runtime directory:

```bash
mkdir -p /opt/lihan_ai_deploy/shared/data/cpa /opt/lihan_ai_deploy/shared/logs/cpa
cp -a /opt/lihan_ai_runtime/.cli-proxy-api/. /opt/lihan_ai_deploy/shared/data/cpa/
chmod 700 /opt/lihan_ai_deploy/shared/data/cpa
chmod 600 /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
```

Then set these values in `.env.production`:

```env
CPA_CONFIG_PATH=/opt/lihan_ai_deploy/shared/data/cpa/config.yaml
CPA_AUTH_PATH=/opt/lihan_ai_deploy/shared/data/cpa
CPA_LOG_PATH=/opt/lihan_ai_deploy/shared/logs/cpa
```

For the legacy direct-checkout deployment, the older `/opt/lihan_ai/data/cpa` path still works, but release deployment should use `/opt/lihan_ai_deploy/shared/data/cpa`.

## Start CPA Internally

Start CPA on the same Docker network as New API:

```bash
cd /opt/lihan_ai_deploy/current

ops/cpa-ui.sh close
```

For direct-origin deployments, this is equivalent to the local-service compose command below. Tunnel deployments append `docker-compose.cloudflare-tunnel.yml`, but local CPA commands must not pass `--scale caddy=0`; that option is only for full-stack release promote or full-stack compose up.

```bash
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d --force-recreate --no-deps cli-proxy-api
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

## CPA Upstream Egress Proxy

When New API uses CPA as its upstream adapter, CPA is the component that opens outbound connections to model providers:

```text
client -> New API -> cli-proxy-api -> upstream provider
```

In this topology, configure residential or ISP egress proxies in CPA, not in the New API channel. The New API channel should keep:

- Base URL: `http://cli-proxy-api:8317`
- Proxy Address: empty

Set a global CPA proxy in `/opt/lihan_ai_deploy/shared/data/cpa/config.yaml` when all CPA upstream traffic should leave through the same egress host:

```yaml
proxy-url: "socks5://newapi:<password>@38.125.120.23:1080/"
```

Alternatively, leave the top-level `proxy-url: ""` empty and set `proxy-url` only on a specific provider or credential entry. CPA also supports `proxy-url: "direct"` or `proxy-url: "none"` on an entry to bypass the global proxy and environment proxies.

For a small GOST SOCKS5 egress VPS, keep the proxy private:

- Bind GOST to `0.0.0.0:1080`, but allow inbound `1080/tcp` only from the origin public IP.
- Keep SSH explicitly allowed before enabling a default-deny firewall.
- Run GOST under a dedicated `gost` system user with `systemctl enable --now gost`.
- If the service logs `open /etc/gost/gost.yml: permission denied`, use `chown root:gost /etc/gost /etc/gost/gost.yml`, `chmod 750 /etc/gost`, and `chmod 640 /etc/gost/gost.yml`.
- Rotate the proxy password after it has been pasted into a shell, chat, ticket, or temporary note.

Verify the egress VPS:

```bash
systemctl is-enabled gost
systemctl is-active gost
ss -lntp | grep ':1080'
ufw status verbose
curl -sS --connect-timeout 5 --max-time 20 \
  -x "socks5h://newapi:<password>@127.0.0.1:1080" \
  https://ifconfig.me
```

Verify from the origin:

```bash
curl -4 -sS --max-time 10 https://ifconfig.me
curl -sS --connect-timeout 5 --max-time 20 \
  -x "socks5h://newapi:<password>@38.125.120.23:1080" \
  https://ifconfig.me

grep -nE 'proxy-url:' /opt/lihan_ai_deploy/shared/data/cpa/config.yaml \
  | sed -E 's#(socks5h?://)[^@]+@#\1<redacted>@#g'

docker inspect -f '{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
  relay-cpa relay-new-api relay-postgres relay-redis relay-cloudflared 2>/dev/null
```

After changing CPA proxy settings, restart only CPA:

```bash
cd /opt/lihan_ai_deploy/current
docker restart relay-cpa
docker logs --tail=80 relay-cpa
```

## Management UI

The management UI is disabled from the public internet. When you need it, start the localhost-only UI override:

```bash
cd /opt/lihan_ai_deploy/current

ops/cpa-ui.sh open
```

`ops/cpa-ui.sh open` appends `docker-compose.cpa.ui.yml`, keeps the active Cloudflare Tunnel overlay when enabled, and uses `--force-recreate --no-deps` so the local CPA UI operation refreshes only CPA and does not recreate `new-api`, `cloudflared`, or `caddy`. The base CPA compose file mounts `config.yaml` read-only. The UI override intentionally remounts `/CLIProxyAPI/config.yaml` writable so the management UI can save changes. Use this override only while you are actively managing CPA config.

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
cd /opt/lihan_ai_deploy/current

ops/cpa-ui.sh close
```

This returns CPA to the read-only config mount used for normal runtime.

Use `ops/cpa-ui.sh ps` to confirm the container state and local port binding. Do not use ad hoc CPA UI commands with `--remove-orphans` or `--scale caddy=0`; those flags belong to full-stack operations, not a single-service CPA UI session.

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
