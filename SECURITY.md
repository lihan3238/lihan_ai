# Security Policy

## Reporting

Do not open public issues for secrets, leaked tokens, private hostnames, backup contents, or exploitable production details.

Use a private channel with the maintainer, or GitHub private vulnerability reporting if it is enabled for the repository.

## Scope

Security-sensitive areas include:

- `.env` and `.env.production` values.
- API keys, New API tokens, upstream provider keys, and CPA config.
- PostgreSQL dumps, logs, snapshots, and restore artifacts.
- Production hostnames that are not already public service endpoints.
- Scripts that can deploy, restore, delete, or promote production releases.

## Maintainer Response

The maintainer should rotate affected credentials, remove sensitive artifacts from public history when needed, and document the fix without repeating the secret value.
