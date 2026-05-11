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

This is enough for New API, PostgreSQL, Redis, Caddy or Cloudflare Tunnel, optional CPA, and light private traffic. Avoid 1 GB RAM instances unless this is only a short smoke test; PostgreSQL, Docker, and image upgrades leave too little headroom.

## Production Topology

Use two roles when serving mainland China users:

- **Origin server**: runs New API, PostgreSQL, Redis, Caddy or Cloudflare Tunnel, optional CPA, local backups, and all secrets. Your current Hostinger 2 vCPU / 8 GB / 100 GB server is acceptable as an initial origin if outbound API connectivity remains stable.
- **Edge VPS**: optional China-optimized reverse proxy that runs only Caddy using `docker-compose.edge.yml`. It should not contain PostgreSQL, Redis, New API tokens, upstream provider keys, or `.env.production`.

For the first small trial, start with one origin only. Add the edge only when domestic latency is the main blocker.

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
- Backups interfere with API traffic.
- You add automatic payment, richer analytics, or local custom development services.

For an edge-only VPS, CPU and RAM are less important than route quality. A 1-2 vCPU / 1-2 GB RAM China-optimized node is enough for light reverse proxy traffic; buy better bandwidth before more CPU.

## Purchase Checklist

- Can open ports 80 and 443 when using direct-origin Caddy.
- Allows outbound Cloudflare Tunnel connections if using Tunnel mode.
- Can run Docker Compose.
- Has Ubuntu 24.04 LTS image.
- Has snapshots or backup products.
- Has firewall rules for SSH, HTTP, and HTTPS.
- Allows API relay/proxy style services under its terms.
- Supports outbound HTTPS reliably to the upstream model providers you choose.
- Has predictable bandwidth overage pricing.

## Origin And Edge Layout

For mainland China users:

- Origin: New API, PostgreSQL, Redis, Caddy or Cloudflare Tunnel, optional CPA, local backups.
- Edge: Caddy reverse proxy only, no database and no upstream API keys.

The current Hostinger server is strong enough as an origin for early private traffic if upstream API connectivity is stable. If domestic latency is bad, buy a China-optimized edge VPS first and point the public API hostname to the edge.

Use `docs/edge-proxy-runbook.md` for deployment and `docs/migration-runbook.md` if the edge later becomes the new origin.
