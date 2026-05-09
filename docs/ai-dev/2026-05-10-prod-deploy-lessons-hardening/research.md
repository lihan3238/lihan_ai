# Research: Production Deploy Lessons Hardening

## External References

- Docker Compose supports production-specific override files and multiple compose files for environment separation.
- PostgreSQL custom-format dumps with `pg_dump -Fc` and `pg_restore` remain the right backup primitive for this single-node origin.
- Caddy is a good origin HTTPS reverse proxy, but ACME depends on working container DNS and public `80/443`.
- CLIProxyAPI official Docker Compose publishes multiple ports by default and is suitable as an upstream reference, not as our production origin shape.
- CLIProxyAPI official config keeps management disabled when `remote-management.secret-key` is empty and supports a bundled management panel.

## Local Findings

- The production failure with `POSTGRES_PASSWORD` came from URL-style `SQL_DSN` interpolation; URL-special characters break parsing.
- `verify-postgres-backup.sh` produced Compose variable warnings because it did not pass `--env-file`.
- Caddy can be running but not useful if host port publishing, DNS, or ACME fails; the current preflight does not detect that.
- CPA deployed with ad hoc `docker run` is outside the `relay-internal` Docker network, so New API cannot resolve it by service name.

## Adopted Approach

Keep New API unchanged and harden only wrapper scripts, docs, and compose overlays. Vendor the official CPA files as upstream baselines, then provide a secure production overlay that keeps CPA internal by default and exposes the UI only through `127.0.0.1` plus SSH tunneling.
