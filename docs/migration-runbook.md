# Migration Runbook

Use this when moving `lihan_ai` to a new host. The wrapper remains upstream-only:
do not fork or alter New API/CLIProxyAPI internals during migration.

## Source host

```bash
ENV_FILE=.env.production ops/backup-postgres.sh
ENV_FILE=.env.production ops/backup-secrets.sh
```

Record the `.dump`, encrypted `.tar.age`, both SHA256 sidecars, source commit,
and current image digests. Transfer artifacts only through the private channel.

## Secret handoff

Do not copy the operator SSH private key to the target. Generate a one-time
`age` identity on the target and return only its recipient. On the operator
workstation, stream-decrypt the source secret artifact and re-encrypt it to the
one-time target recipient, then create a new SHA256 sidecar. No plaintext tar
needs to be written. Delete the one-time identity after verified restoration.

After decrypting into a private `0700` staging directory on the target, restore
the labeled paths to `.env.production`, CPA config/auth, and Cloudflare
config/credentials with `0600` files and `0700` directories. Never print their
contents.

## Target host

```bash
docker network create lihan_ai_relay-internal || true
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d postgres redis
CONFIRM_RESTORE=yes ENV_FILE=.env.production \
  ops/restore-postgres.sh /path/to/newapi-YYYYmmddTHHMMSSZ.dump
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
ENV_FILE=.env.production ops/check-runtime.sh
```

Cut public traffic by moving the Cloudflare Tunnel credentials and starting the
`hostinger-cloudflared` stack on the target host. Hostinger public outbound
traffic remains direct through the Hostinger public IP; do not add a global
proxy to New API or CLIProxyAPI.
