# Cloudflare SaaS Tunnel Runbook

This runbook switches the public API entrypoint to `https://api.lihan3238.com` through Cloudflare for SaaS and Cloudflare Tunnel.

Traffic shape:

```text
user -> api.lihan3238.com preferred Cloudflare IP -> Cloudflare Custom Hostname
  -> fallback origin origin.lihan3238.top -> Cloudflare Tunnel
  -> cloudflared on Hostinger -> new-api:3000
```

In Tunnel mode, public `80/443` are served by Cloudflare edge, not by the Hostinger origin. The origin only runs outbound `cloudflared` connections to Cloudflare. Caddy stays in the repository as the legacy direct-origin fallback, but normal Tunnel promotion scales it to zero.

## Cloudflare Zone

Add `lihan3238.top` to Cloudflare and move its nameservers at Spaceship to the two Cloudflare nameservers. Wait until Cloudflare reports the zone is active.

Create a named Tunnel, for example `lihan-ai-prod`, in Cloudflare Zero Trust or with `cloudflared`. Route the fallback origin to the tunnel:

```bash
cloudflared tunnel login
cloudflared tunnel create lihan-ai-prod
cloudflared tunnel route dns lihan-ai-prod origin.lihan3238.top
```

The route should create a proxied DNS record for:

```text
origin.lihan3238.top -> <tunnel-uuid>.cfargotunnel.com
```

Remove any old `origin.lihan3238.top A <origin-ip>` record after the tunnel route is active. The fallback origin should resolve to Cloudflare, not directly to the origin server IP.

In `SSL/TLS -> Custom Hostnames`, keep Cloudflare for SaaS enabled and keep the fallback origin as:

```text
origin.lihan3238.top
```

## Custom Hostname

Add or keep this custom hostname:

```text
api.lihan3238.com
```

Use the default TLS settings and Let's Encrypt as the certificate authority. Cloudflare will provide DNS validation records. Add both TXT records in Spaceship DNS for `lihan3238.com`, then wait until both hostname and certificate status are `Active`.

After validation, keep `lihan3238.com` DNS at Spaceship and keep the public entrypoint pointed at your preferred Cloudflare IP:

```text
Type: A
Host: api
Value: 172.64.155.231
```

Do not point `api.lihan3238.com` at the origin server IP for the Tunnel path.

To optimize another `lihan3238.com` subdomain through the same path, repeat this
per hostname instead of creating a wildcard rule:

1. Add a Spaceship DNS `A` record for the host, reusing the current preferred
   Cloudflare IP from `api.lihan3238.com`:
   ```text
   Type: A
   Host: <host>
   Value: 172.64.155.231
   ```
   Remove any CNAME for the same host first.
2. Add `<host>.lihan3238.com` as a Cloudflare Custom Hostname in the
   `lihan3238.top` zone. Keep fallback origin as `origin.lihan3238.top`.
3. Add Cloudflare-provided TXT validation records in Spaceship DNS for
   `lihan3238.com`, then wait until the hostname and certificate are active.
4. If the hostname should serve New API, add an explicit `cloudflared` ingress
   rule for that hostname. If it is a Worker or blog hostname, keep it on the
   Worker route and do not add it to New API ingress.

`origin.lihan3238.top` does not capture all `*.lihan3238.com` traffic by
itself. It is only the Cloudflare for SaaS fallback origin. A hostname reaches
New API only when Cloudflare routes that custom hostname to the fallback origin
and `cloudflared` has an explicit matching ingress rule for that hostname.

## Origin Files

On the Hostinger origin, store Tunnel files in shared runtime storage:

```bash
sudo mkdir -p /opt/lihan_ai_deploy/shared/cloudflared
sudo chown -R lihan:lihan /opt/lihan_ai_deploy/shared/cloudflared
chmod 700 /opt/lihan_ai_deploy/shared/cloudflared
```

Copy the tunnel credentials JSON created by `cloudflared tunnel create` into:

```text
/opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
```

Create:

```text
/opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

Example:

```yaml
tunnel: <tunnel-uuid>
credentials-file: /etc/cloudflared/tunnel.json

ingress:
  - hostname: api.lihan3238.com
    service: http://new-api:3000
  - hostname: origin.lihan3238.top
    service: http://new-api:3000
  - service: http_status:404
```

The final catch-all ingress is intentionally `http_status:404`, not New API.
This keeps unrelated custom hostnames such as Worker-backed blog hostnames from
silently falling into the API service if a DNS, Worker route, or Custom Hostname
setting is wrong. Add New API hostnames explicitly above the fallback rule.

Lock permissions:

```bash
chmod 644 /opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
chmod 644 /opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

The running `cloudflare/cloudflared` container is non-root, so the bind-mounted `config.yml` and `tunnel.json` must be readable by that container user. Keep the source `<tunnel-uuid>.json` and `cert.pem` out of git; they can be stored more strictly when they are not used as the runtime bind mount.

Validate that both bind-mount sources are regular files before starting the stack. If either path is missing, Docker can create a directory at that path and `cloudflared` will restart with `read /etc/cloudflared/config.yml: is a directory`.

```bash
test -f /opt/lihan_ai_deploy/shared/cloudflared/config.yml && echo "config.yml is file"
test -f /opt/lihan_ai_deploy/shared/cloudflared/tunnel.json && echo "tunnel.json is file"
```

If `config.yml` was accidentally created as a directory, remove only that bad directory and recreate the file from the tunnel UUID and credentials JSON:

```bash
sudo find /opt/lihan_ai_deploy/shared/cloudflared -maxdepth 3 -ls
sudo rm -rf /opt/lihan_ai_deploy/shared/cloudflared/config.yml
sudoedit /opt/lihan_ai_deploy/shared/cloudflared/config.yml
chmod 644 /opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

If `tunnel.json` is missing, recreate or recover the Cloudflare-generated tunnel credentials. The file contains Cloudflare Tunnel credentials and cannot be hand-written.

## Production Env

Edit the shared env:

```bash
cd /opt/lihan_ai_deploy/current

cp /opt/lihan_ai_deploy/shared/.env.production \
  /opt/lihan_ai_deploy/shared/.env.production.bak.$(date -u +%Y%m%dT%H%M%SZ)

nano /opt/lihan_ai_deploy/shared/.env.production
```

Set:

```env
DOMAIN=api.lihan3238.com
ACME_EMAIL=<your-email>
DEPLOY_INCLUDE_CPA=1
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
CLOUDFLARE_SAAS_FALLBACK_ORIGIN=origin.lihan3238.top
CLOUDFLARED_CONFIG_PATH=/opt/lihan_ai_deploy/shared/cloudflared/config.yml
CLOUDFLARED_CREDENTIALS_PATH=/opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
```

Never set:

```env
DOMAIN=origin.lihan3238.top
```

`CLOUDFLARE_SAAS_ORIGIN_IP` is only for the old direct-origin SNI check. Leave it empty in Tunnel mode.

## Deploy

Prepare, smoke, and promote the next release from your local repository:

The normal release path now reads `DEPLOY_INCLUDE_CPA=1` and `DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1` from the remote `.env.production`. The explicit variables below are kept as an emergency override example; daily deploys can use the shorter README commands.

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_REF=main \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh prepare

DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh smoke

DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh promote
```

`prepare` records the prepared release as `candidate`, so normal `smoke` and `promote` do not need a manual `RELEASE_ID`. Pass `RELEASE_ID=<release-id>` only when intentionally operating on a specific older release.

Manual restart equivalent on the origin:

```bash
cd /opt/lihan_ai_deploy/current

docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cloudflare-tunnel.yml \
  up -d --remove-orphans --scale caddy=0
```

When changing only `/opt/lihan_ai_deploy/shared/cloudflared/config.yml`, recreate
only the tunnel container so the single-file bind mount is remounted:

```bash
cd /opt/lihan_ai_deploy/current

docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cloudflare-tunnel.yml \
  up -d --no-deps --force-recreate cloudflared
```

In New API admin, update the public site URL, base URL, or equivalent setting to:

```text
https://api.lihan3238.com
```

## Cloudflare Rules

For `api.lihan3238.com/*`, bypass cache. Do not apply JS Challenge, Bot Fight Mode, or interactive challenge rules to `/api/*` or `/v1/*`. Streaming API clients should be monitored for timeout or disconnect behavior after the switch.

## Verification

Public check through Cloudflare:

```bash
curl -i https://api.lihan3238.com/api/status
curl -i https://origin.lihan3238.top/api/status
docker exec relay-cloudflared cloudflared tunnel --config /etc/cloudflared/config.yml ingress rule https://api.lihan3238.com/
docker exec relay-cloudflared cloudflared tunnel --config /etc/cloudflared/config.yml ingress rule https://origin.lihan3238.top/
docker exec relay-cloudflared cloudflared tunnel --config /etc/cloudflared/config.yml ingress rule https://blog.lihan3238.com/
```

Repository runtime check:

```bash
cd /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

Docker status:

```bash
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cloudflare-tunnel.yml \
  ps
```

Acceptance checks:

- `relay-cloudflared` is running.
- `relay-caddy` is absent or has no published `80/443`.
- `https://api.lihan3238.com` opens the New API UI.
- `origin.lihan3238.top` matches a New API ingress rule only because it is the
  fallback-origin health/debug hostname.
- Worker/blog hostnames do not match a New API ingress rule; they should hit the
  final `http_status:404` rule if tested through `cloudflared ingress rule`.
- Login and admin pages work.
- `/api/status` returns `success: true`.
- A test token can call `/v1/models`.
- New API channels that use CPA still target the Docker-internal CPA service, not the public domain.

## Rollback

If the Tunnel path fails, keep the Hostinger stack running and temporarily switch the SaaS fallback origin back to a known-good direct-origin path, or restore the previous env backup and promote/rollback the previous release:

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_INCLUDE_CPA=1 \
bash ops/deploy-release.sh rollback
```

For a manual fallback to the old Caddy path, set `DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0`, restore `CLOUDFLARE_SAAS_ORIGIN_IP=<origin-ip>`, and recreate Caddy with the base production compose files. Use this only as a temporary recovery path because it reintroduces origin certificate handling.
