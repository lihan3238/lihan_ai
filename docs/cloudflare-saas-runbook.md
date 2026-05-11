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

Remove any old `origin.lihan3238.top A 72.60.124.21` record after the tunnel route is active. The fallback origin should resolve to Cloudflare, not directly to the Hostinger IP.

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

Do not point `api.lihan3238.com` at `72.60.124.21` for the Tunnel path.

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
  - hostname: origin.lihan3238.top
    service: http://new-api:3000
  - service: http://new-api:3000
```

The final catch-all ingress is intentional. Cloudflare for SaaS may preserve `Host: api.lihan3238.com` while using `origin.lihan3238.top` as the fallback route, so unmatched hostnames should still reach New API.

Lock permissions:

```bash
chmod 600 /opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
chmod 600 /opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

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
chmod 600 /opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

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

```bash
DEPLOY_HOST=lihan@srv998135.hstgr.cloud \
DEPLOY_REF=main \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh prepare

DEPLOY_HOST=lihan@srv998135.hstgr.cloud \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh smoke

DEPLOY_HOST=lihan@srv998135.hstgr.cloud \
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
- Login and admin pages work.
- `/api/status` returns `success: true`.
- A test token can call `/v1/models`.
- New API channels that use CPA still target the Docker-internal CPA service, not the public domain.

## Rollback

If the Tunnel path fails, keep the Hostinger stack running and temporarily switch the SaaS fallback origin back to a known-good direct-origin path, or restore the previous env backup and promote/rollback the previous release:

```bash
DEPLOY_HOST=lihan@srv998135.hstgr.cloud \
DEPLOY_INCLUDE_CPA=1 \
bash ops/deploy-release.sh rollback
```

For a manual fallback to the old Caddy path, set `DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0`, restore `CLOUDFLARE_SAAS_ORIGIN_IP=72.60.124.21`, and recreate Caddy with the base production compose files. Use this only as a temporary recovery path because it reintroduces origin certificate handling.
