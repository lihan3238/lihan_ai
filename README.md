# Lihan AI Relay

This repository is currently a clean New API deployment and study workspace. The first milestone is to run upstream New API as-is, understand its built-in features, and only then decide whether any local customization is needed.

## Boundaries

- Runtime uses the official `calciumion/new-api:latest` image.
- Upstream source is tracked as a submodule at `vendor/new-api`.
- Local development is WSL-first.
- Production deployment stays Docker-based.
- Custom business features are intentionally deferred until New API's existing capabilities are reviewed.

## Quick Start

1. Use WSL Ubuntu 24.04 or a Linux VPS shell.
2. Install Docker and Docker Compose on the VPS.
3. Initialize the New API source submodule if it is not already present:

```bash
git submodule update --init --recursive
```

4. Copy `.env.example` to `.env`.
5. Replace every `CHANGE_ME` value and set `DOMAIN` to the production hostname.
6. Point the domain A/AAAA record to the VPS.
7. Run the preflight check from WSL or Linux:

```bash
bash ops/preflight.sh
```

8. Start the stack:

```bash
docker compose up -d
```

9. Open `https://$DOMAIN`, create the first admin user, then configure New API using its original admin console.

## Repository Layout

- `docker-compose.yml`: New API, PostgreSQL, Redis, Caddy, and Uptime Kuma.
- `.env.example`: deployment variables and required secrets.
- `docs/new-api-code-map.md`: current upstream New API feature and source map.
- `docs/local-development-state.md`: local initialization and persistent state rules.
- `docs/backup-strategy.md`: database backup, verification, and restore rules.
- `docs/server-buying-guide.md`: VPS sizing and purchase checklist.
- `ops/`: preflight, backup, and restore scripts.
- `scripts/verify-repo.ps1`: local repository verification.
- `vendor/new-api`: upstream New API source as a git submodule for audit and future customization.

## Useful Commands

```bash
docker compose ps
docker compose logs -f new-api
bash ops/backup-postgres.sh
```

## Local Development

Development runs the original New API Docker image, but exposes it directly on localhost so you can inspect it without a public domain:

```bash
cp .env.example .env
# replace CHANGE_ME values first
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

Open `http://localhost:$NEW_API_DEV_PORT`. If 3000 is occupied locally, set `NEW_API_DEV_PORT=3100` in `.env`. For production, use the base `docker-compose.yml` and access through Caddy on `https://$DOMAIN`.

On first login, New API will ask you to initialize the system and create the root/admin account. It is safe to follow that prompt in local development. The account, settings, channels, tokens, and payment configuration are stored in PostgreSQL and will survive container restarts and container deletion. Do not run `docker compose down -v` unless you intentionally want to erase local state.

On Windows, run repository verification from PowerShell:

```powershell
./scripts/verify-repo.ps1
```

If WSL needs outbound network proxying during setup, use the Windows host proxy on port `10808` temporarily:

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

Do not commit local proxy variables into `.env`.
