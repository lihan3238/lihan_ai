# Backup Strategy

Back up two portable artifacts without modifying New API or CLIProxyAPI:

- PostgreSQL custom-format dump from `relay-postgres`:
  `newapi-YYYYmmddTHHMMSSZ.dump` plus a SHA256 sidecar.
- Opaque `age`-encrypted secret artifact containing `.env.production`, CPA
  config/auth, and Cloudflare config/credentials when those configured paths
  exist. The script copies those paths without parsing or printing contents.

Install only the public recipient at the path configured by
`BACKUP_AGE_RECIPIENT_FILE`. The matching private identity must remain on the
operator workstation.

Run:

```bash
ENV_FILE=.env.production ops/backup-postgres.sh
ENV_FILE=.env.production ops/backup-secrets.sh
```

`ops/backup-config.sh` is a compatibility wrapper for `backup-secrets.sh`; it
no longer creates a plaintext config tarball. Backup directories are `0700`,
artifacts and checksum sidecars are `0600`, and permissive or symlinked secret
sources are rejected.

Database restores are explicit and guarded. The restore script reads only the
first five bytes: `PGDMP` dispatches to `pg_restore`; existing plain SQL dumps
remain compatible through `psql`.

```bash
CONFIRM_RESTORE=yes ENV_FILE=.env.production \
  ops/restore-postgres.sh /path/to/newapi-YYYYmmddTHHMMSSZ.dump
```

Do not delete Docker volumes during normal backup or restore drills. Never use
these backups to probe provider accounts or change CPA OAuth/token refresh.
