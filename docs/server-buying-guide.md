# Server Buying Guide

## Recommended Starting Spec

Buy one overseas Linux VPS first. Recommended baseline:

- 2 vCPU.
- 4 GB RAM.
- 60-80 GB SSD/NVMe disk.
- 2 TB or more monthly transfer.
- Ubuntu 24.04 LTS.
- Public IPv4.
- Provider firewall support.
- Snapshot or backup option.

This is enough for New API, PostgreSQL, Redis, Caddy, Uptime Kuma, and light traffic. Avoid 1 GB RAM instances unless this is only a short smoke test; PostgreSQL plus Docker plus image upgrades leave too little headroom.

## Production Topology

Use two roles when serving mainland China users:

- **Origin server**: runs New API, PostgreSQL, Redis, Caddy, Uptime Kuma, backups, and all secrets. Your current Hostinger 2 vCPU / 8 GB / 100 GB server is acceptable as an initial origin if outbound API connectivity remains stable.
- **Edge VPS**: optional China-optimized reverse proxy that runs only Caddy using `docker-compose.edge.yml`. It should not contain PostgreSQL, Redis, New API tokens, upstream provider keys, or `.env.production`.

This lets you migrate the origin later without changing the public edge IP every time. For the first small trial, you can start with one origin only, then add the edge when domestic latency is the main blocker.

## Region

Preferred early regions:

- Hong Kong, Singapore, Japan, or US West if available and stable.
- Singapore is a practical default when Hong Kong is too expensive.
- Avoid mainland China for V1 unless you are ready for ICP filing, local compliance, and more complicated overseas API connectivity.

## Minimum Acceptable Spec

Only use this for a temporary test:

- 1 vCPU.
- 2 GB RAM.
- 40 GB disk.
- 1 TB transfer.

Do not run public paid traffic on this size for long. Memory pressure during image pulls, backups, or traffic spikes can make the service unstable.

## Upgrade Trigger

Upgrade to 4 vCPU / 8 GB RAM when any of these are true:

- More than 50 active paying users.
- PostgreSQL memory or CPU stays high.
- New API response latency is normal upstream-side but slow locally.
- Backups or log processing interfere with API traffic.
- You add automatic payment, richer analytics, or local custom development services.

For an edge-only VPS, CPU and RAM are less important than route quality. A 1-2 vCPU / 1-2 GB RAM CN2 GIA, CMI, or otherwise China-optimized node is enough for reverse proxying light API traffic; buy more bandwidth before buying more CPU.

## Purchase Checklist

- Can open ports 80 and 443.
- Can run Docker Compose.
- Has Ubuntu 24.04 LTS image.
- Has snapshots or backup products.
- Has firewall rules for SSH, HTTP, and HTTPS.
- Allows API relay/proxy style services under its terms.
- Supports outbound HTTPS reliably to OpenAI, Anthropic, DeepSeek, Zhipu, and aggregators you choose.
- Has predictable bandwidth overage pricing.

## Provider Notes

- Hetzner Cloud is strong value in Europe, USA, and Singapore. Hetzner describes shared plans as appropriate for development, small databases, and low to medium traffic, and dedicated vCPU plans for sustained high workloads.
- Akamai/Linode lists 2 GB and 4 GB shared CPU plans with clear transfer quotas, which makes cost planning straightforward.
- DigitalOcean emphasizes predictable monthly pricing, Droplets starting at low monthly cost, free cloud firewalls, and included outbound transfer starting at 500 GiB/month.
- Vultr is worth checking for Hong Kong/Singapore/Japan availability, but verify current pricing and region stock before purchase.

For this project, buy the cheapest reputable 2 vCPU / 4 GB machine in Hong Kong or Singapore first. Keep one-click snapshots enabled before upgrades and before New API version changes.

## Origin And Edge Layout

For mainland China users, keep the production origin simple and add a stateless edge if direct access is poor:

- Origin: New API, PostgreSQL, Redis, Caddy, Uptime Kuma, backups.
- Edge: Caddy reverse proxy only, no database, no upstream API keys.

The current Hostinger server is strong enough as an origin for early private traffic if upstream API connectivity is stable. If domestic latency is bad, buy a China-optimized edge VPS first and point `api.example.com` to the edge. Keep the origin behind `origin.example.com` or a private tunnel later.

Minimum edge spec:

- 1 vCPU.
- 1 GB RAM.
- 20 GB disk.
- 500 GB or more monthly transfer.
- Good China Telecom/Unicom/Mobile routing.

Use `docs/edge-proxy-runbook.md` for deployment and `docs/migration-runbook.md` if the edge later becomes the new origin.

Sources checked on 2026-05-08:

- Hetzner Cloud: https://www.hetzner.com/cloud/
- Akamai Cloud pricing: https://www.linode.com/pricing/
- DigitalOcean pricing: https://www.digitalocean.com/pricing
- Vultr pricing: https://www.vultr.com/pricing/
