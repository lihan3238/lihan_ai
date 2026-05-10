# Cloudflare SaaS Domain Runbook

This runbook switches the public API entrypoint to `https://api.lihan3238.com` through Cloudflare for SaaS while keeping the Hostinger server as the production origin.

Traffic shape:

```text
user -> api.lihan3238.com preferred Cloudflare IP -> Cloudflare Custom Hostname
  -> fallback origin origin.lihan3238.top -> Hostinger Caddy -> new-api:3000
```

The production origin Caddy site must serve the public custom hostname, `api.lihan3238.com`. Do not set production `DOMAIN` to `origin.lihan3238.top`; that hostname is only Cloudflare's route to the origin.

## Cloudflare Zone

Add `lihan3238.top` to Cloudflare and move the domain nameservers at Spaceship to the two Cloudflare nameservers. Wait until Cloudflare reports the zone is active.

In the Cloudflare DNS page for `lihan3238.top`, create:

```text
Type: A
Name: origin
IPv4: 72.60.124.21
Proxy status: Proxied
```

In `SSL/TLS -> Custom Hostnames`, enable Cloudflare for SaaS and set the fallback origin to:

```text
origin.lihan3238.top
```

Keep the Cloudflare SSL mode as `Full` while the origin certificate is being proven. After the direct-origin SNI check passes, move the zone to `Full (strict)`.

## Custom Hostname

Add a custom hostname:

```text
api.lihan3238.com
```

Use the default TLS settings and Let's Encrypt as the certificate authority. Cloudflare will provide DNS validation records. Add both TXT records in the Spaceship DNS page for `lihan3238.com`, then wait until both hostname and certificate status are `Active`.

After validation, keep `lihan3238.com` DNS at Spaceship and create the public entrypoint there:

```text
Type: A
Host: api
Value: <preferred Cloudflare IP from CloudflareSpeedTest>
```

Multiple A records can be used for the fastest measured Cloudflare IPs. If validation gets stuck with preferred IPs, temporarily use Cloudflare's documented CNAME validation path, wait for `Active`, then switch back to preferred A records.

## Origin Configuration

Run on the Hostinger origin:

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
CLOUDFLARE_SAAS_FALLBACK_ORIGIN=origin.lihan3238.top
CLOUDFLARE_SAAS_ORIGIN_IP=72.60.124.21
```

Never set:

```env
DOMAIN=origin.lihan3238.top
```

Render and reload Caddy:

```bash
cd /opt/lihan_ai_deploy/current

ENV_FILE=.env.production bash ops/preflight.sh

compose_files="-f docker-compose.yml -f docker-compose.prod.yml"
if grep -q '^DEPLOY_INCLUDE_CPA=1' .env.production; then
  compose_files="$compose_files -f docker-compose.cpa.yml"
fi

docker compose -p lihan_ai --env-file .env.production $compose_files config >/dev/null
docker compose -p lihan_ai --env-file .env.production $compose_files up -d --force-recreate caddy
docker logs --tail=120 relay-caddy
```

In the New API admin console, update the public site URL, base URL, or equivalent setting to:

```text
https://api.lihan3238.com
```

## Cloudflare Rules

For `api.lihan3238.com/*`, bypass cache. Do not apply JS Challenge, Bot Fight Mode, or interactive challenge rules to `/api/*` or `/v1/*`. Streaming API clients should be monitored for timeout or disconnect behavior after the switch.

## Verification

Direct origin SNI and Host check:

```bash
curl -vk --resolve api.lihan3238.com:443:72.60.124.21 \
  https://api.lihan3238.com/api/status
```

Cloudflare public check:

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
  ps
```

Acceptance checks:

- `https://api.lihan3238.com` opens the New API UI.
- Login and admin pages work.
- `/api/status` returns `success: true`.
- A test token can call `/v1/models`.
- New API channels that use CPA still target the Docker-internal CPA service, not the public domain.

## Rollback

If the custom hostname path fails, keep the Hostinger stack running and point `api.lihan3238.com` back to the previous known-good DNS target. If the `.env.production` change caused the issue, restore the timestamped backup and recreate Caddy:

```bash
cp /opt/lihan_ai_deploy/shared/.env.production.bak.<timestamp> \
  /opt/lihan_ai_deploy/shared/.env.production

cd /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d --force-recreate caddy
```
