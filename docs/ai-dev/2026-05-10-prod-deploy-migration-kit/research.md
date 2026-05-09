# Research

## Sources
- Official documentation: Docker Compose production and multiple compose files, PostgreSQL dump/restore, Caddy reverse proxy, restic backups.
- Mature adjacent projects: Coolify, Dokploy, Portainer, and Kamal deployment models.
- GitHub issues or release notes: not used for V1 because the plan avoids adopting a new deployment control plane.
- Community discussions: not used as primary evidence.

## Common Practice
Small paid self-hosted services commonly keep the first production version on Docker Compose, use an extra production override file, and deploy through Git plus SSH. Data safety is handled by database-native dumps, off-server encrypted backups, and rehearsed restores. A public edge proxy is usually stateless and forwards to an origin instead of storing databases or long-lived application secrets.

## Risks
- Docker Compose deployment is simple but has no built-in zero-downtime database migration.
- `pg_dump` and `pg_restore` are reliable for this project size, but final migration still needs a write freeze to avoid losing late writes.
- Edge reverse proxy improves China access but adds one more network hop and can hide origin failures unless monitored.
- Off-server backup protects against VPS loss only if restore drills are run and the restic password is kept separately.
- Coolify, Dokploy, and Portainer add UI convenience but also add control-plane state and upgrade risk.

## Decision
Use Docker Compose, SSH, Caddy, PostgreSQL dump/restore, and restic. Avoid Coolify/Dokploy/Portainer as required infrastructure for V1. Treat zero downtime as out of scope; define no-loss migration as a final cutover with New API writes stopped before the final dump.
